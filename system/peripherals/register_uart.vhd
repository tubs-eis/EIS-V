--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library fpga;

entity uart is
    generic(
        IOBUS_DATA_WIDTH : natural := 8;
        CLOCK_FREQ       : natural := 100000000; -- 100 MHz default
        BAUDRATE         : natural := 115200 -- Baudrate for initialization
    );
    port(
        clock          : in  std_ulogic;
        reset_n        : in  std_ulogic;
        -- io bus 
        iobus_cs       : in  std_ulogic;
        iobus_wr       : in  std_ulogic;
        iobus_addr     : in  std_ulogic_vector(1 downto 0);
        iobus_din      : in  std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
        iobus_dout     : out std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
        -- interrupt
        iobus_irq_rxc  : out std_ulogic; -- receive register full
        iobus_irq_udre : out std_ulogic; -- send register empty (rdy for next word)
        iobus_irq_txc  : out std_ulogic; -- transfer completed (send + receive empty) 
        -- interrupt acks
        iobus_ack_rxc  : in  std_ulogic;
        iobus_ack_udre : in  std_ulogic;
        iobus_ack_txc  : in  std_ulogic;
        -- uart signals
        rx             : in  std_ulogic; -- receive channel
        tx             : out std_ulogic -- transmit channel
    );
end entity uart;

architecture rtl of uart is
    -----  Data-Register -----
    signal rx_data_reg     : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
    signal rx_data_reg_nxt : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
    signal tx_data_reg     : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
    signal tx_data_reg_nxt : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
    constant DATA_REG_ADDR : std_ulogic_vector(1 downto 0) := "00";

    -----  Baudrate-Register -----
    -- taktteiler für Baudratengenerator
    -- Baudrate = Systemtakt  / (16 *  [Register-Wert + 1])
    signal baud_reg        : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
    signal baud_reg_nxt    : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
    constant BAUD_REG_ADDR : std_ulogic_vector(1 downto 0) := "01";

    -----  Control-Register -----
    signal ctrl_reg        : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
    signal ctrl_reg_nxt    : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
    constant CTRL_REG_ADDR : std_ulogic_vector(1 downto 0) := "10";

    --  Constants for setting Control-Bits in Control-Register --
    constant CONTROL_RXC_IE : natural := 7; -- empfangsregister ist voll
    constant CONTROL_TXC_IE : natural := 6; -- transferende, reset: iobus_ack_txc / write, set wenn send abschluss & leeres senderegister
    constant CONTROL_UDR_IE : natural := 5; -- sende uart_dinregister leer
    constant CONTROL_RX_EN  : natural := 4; -- framing error im empfang register
    constant CONTROL_TX_EN  : natural := 3; -- overrun im empfang register

    --  Status-Register --
    signal status_reg        : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
    signal status_reg_nxt    : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
    constant STATUS_REG_ADDR : std_ulogic_vector(1 downto 0) := "11";

    --  Control Signals for Status-Register --
    signal status_rx_finished      : std_ulogic;
    signal status_rx_framing_error : std_ulogic;
    signal status_or_bit           : std_ulogic;
    signal status_tx_full          : std_ulogic;
    signal status_tx_empty         : std_ulogic;
    signal status_tx_clear         : std_ulogic;
    signal status_tx_end           : std_ulogic;

    --  Constants for setting Status-Bits in Status-Register --
    constant STATUS_RXC  : natural := 7;
    constant STATUS_TXC  : natural := 6;
    constant STATUS_UDRE : natural := 5;
    constant STATUS_FE   : natural := 4;
    constant STATUS_OR   : natural := 3;

    -- BITDURATION = SYSTEMCLOCK / (SYSTEMCLOCK / 16* (baud_reg + 1)) = 16*(baud_reg + 1) = (baud_reg + 1) << 4
    signal bitduration     : unsigned((baud_reg'length + 5) - 1 downto 0);
    signal bitduration_nxt : unsigned((baud_reg'length + 5) - 1 downto 0);
    constant DATABITS      : natural := 8;

    -- RX State Machine --
    type RX_STATE_T is (RX_IDLE, RX_STARTBIT, RX_DATA, RX_STOPBIT);
    signal rx_state     : RX_STATE_T;
    signal rx_state_nxt : RX_STATE_T;

    -- RX Control Signals --
    signal rx_baud_count        : unsigned((baud_reg'length + 5) - 1 downto 0); -- Count Clockcycles for detecting middle of current bit
    signal rx_baud_count_nxt    : unsigned((baud_reg'length + 5) - 1 downto 0);
    signal rx_bit_count         : natural range 0 to 8; -- Count sampled bits of byte
    signal rx_bit_count_nxt     : natural range 0 to 8;
    signal rx_sample_buffer     : std_ulogic_vector(2 downto 0); -- Samplebuffer to determine input bit
    signal rx_sample_buffer_nxt : std_ulogic_vector(2 downto 0);
    signal rx_buffer            : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0); -- Input buffer for current byte
    signal rx_buffer_nxt        : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);
    signal or_bit               : std_ulogic; -- Signalize an overrun
    signal or_bit_nxt           : std_ulogic;

    -- TX State Machine --
    type TX_STATE_T is (TX_IDLE, TX_STARTBIT, TX_DATA, TX_STOPBIT);
    signal tx_state     : TX_STATE_T;
    signal tx_state_nxt : TX_STATE_T;

    -- TX Control Signals --
    signal tx_baud_count     : unsigned((baud_reg'length + 5) - 1 downto 0); -- Count Clockcycles for detecting begin of new bit
    signal tx_baud_count_nxt : unsigned((baud_reg'length + 5) - 1 downto 0);
    signal tx_bit_count      : natural range 0 to 8; -- Count sampled bits of byte
    signal tx_bit_count_nxt  : natural range 0 to 8;
    signal tx_buffer         : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0); -- Buffer to free send register and send byte idependent
    signal tx_buffer_nxt     : std_ulogic_vector(IOBUS_DATA_WIDTH - 1 downto 0);

begin
    ---- Global Registerprocess ----
    global_ff : process(clock)
    begin
        -- On rising edge, update all signals --
        if (rising_edge(clock)) then
            if (reset_n = '0') then
                ctrl_reg    <= (others => '0');
                status_reg <=(others => '0');
                status_reg  <= "00100000"; -- @suppress "Incorrect array size in assignment: expected (<IOBUS_DATA_WIDTH>) but was (<8>)"
                -- Baudrate 115200 => we have an Bitduration of 8,68 µs
                -- CLOCK_FREQ = 100 MHz
                -- Factor of 868,056 (cycles for one bit)
                baud_reg    <= (others => '0');
                baud_reg    <= std_ulogic_vector(to_unsigned(integer(CLOCK_FREQ / BAUDRATE / 16), baud_reg'length));
                bitduration <= to_unsigned(integer(CLOCK_FREQ / BAUDRATE), bitduration'length);
            else
                baud_reg    <= baud_reg_nxt;
                ctrl_reg    <= ctrl_reg_nxt;
                status_reg  <= status_reg_nxt;
                bitduration <= bitduration_nxt;
            end if;
        end if;
    end process global_ff;

    ---- Register Interface ----
    reg_if : process(status_reg, rx_data_reg, tx_data_reg, baud_reg, baud_reg_nxt, ctrl_reg, iobus_cs, iobus_addr, iobus_wr, iobus_din, bitduration)
    begin
        -- Default Assignments --
        tx_data_reg_nxt <= tx_data_reg;
        baud_reg_nxt    <= baud_reg;
        ctrl_reg_nxt    <= ctrl_reg;
        bitduration_nxt <= bitduration;
        status_tx_full  <= '0';
        status_tx_clear <= '0';
        status_or_bit   <= '0';
        iobus_dout      <= (others => '0');

        if (iobus_cs = '1') then        -- IO-BUS is activated by the CPU 
            if (iobus_addr = DATA_REG_ADDR) then -- Accessing Data Register 
                if (iobus_wr = '1') then -- Writing to TX-Data Register
                    tx_data_reg_nxt <= iobus_din; -- Mark tx send register as full 
                    status_tx_full  <= '1';
                else                    -- Reading from RX-Data Register --
                    iobus_dout    <= rx_data_reg;
                    -- Set overrun bit in status register and mark rx data register as empty --
                    status_or_bit <= '1';
                end if;
            elsif (iobus_addr = BAUD_REG_ADDR) then -- Accessing Baudrate Register --
                if (iobus_wr = '1') then -- Writing to Baudrade Register --
                    baud_reg_nxt    <= iobus_din;
                    bitduration_nxt <= shift_left(resize(unsigned(baud_reg_nxt), bitduration_nxt'length) + 1, 4);
                else                    -- Reading from Baudrate Register --
                    iobus_dout <= baud_reg;
                end if;
            elsif (iobus_addr = CTRL_REG_ADDR) then -- Accessing Control Register
                if (iobus_wr = '1') then -- Writing to Control Register
                    ctrl_reg_nxt <= iobus_din;
                else                    -- Reading from Control Register 
                    iobus_dout <= ctrl_reg;
                end if;
            elsif (iobus_addr = STATUS_REG_ADDR) then -- Accessing Status Register
                if (iobus_wr = '1') then -- Writing to Status Register 
                    if (iobus_din(STATUS_TXC) = '1') then -- Clear TX Bit
                        status_tx_clear <= '1';
                    end if;
                else                    -- Reading from Status Register 
                    iobus_dout <= status_reg;
                end if;
            end if;
        end if;
    end process reg_if;

    ---- Set status register ----
    reg_status : process(status_reg, iobus_ack_rxc, status_or_bit, or_bit, status_rx_finished, status_rx_framing_error, iobus_ack_udre, status_tx_full, status_tx_empty, status_tx_end, iobus_ack_txc, status_tx_clear)
    begin
        -- Default Assignment 
        status_reg_nxt <= status_reg;

        ---- RX Status Bits --
        -- Set framing error and mark rx-data register as full
        if (status_rx_finished = '1') then
            status_reg_nxt(STATUS_RXC) <= '1';
            status_reg_nxt(STATUS_FE)  <= '0';
            -- Mark rx-data register as full without setting framing error 
            if (status_rx_framing_error = '1') then
                status_reg_nxt(STATUS_FE) <= '1';
            end if;
        -- Set or-bit and mark rx-data register as empty 
        elsif ((iobus_ack_rxc = '1') or (status_or_bit = '1')) then
            status_reg_nxt(STATUS_RXC) <= '0';
            status_reg_nxt(STATUS_OR)  <= or_bit;
        end if;

        ---- TX Status Bits ----
        -- Mark tx-send register as full 
        if ((iobus_ack_udre = '1') or (status_tx_full = '1')) then
            status_reg_nxt(STATUS_UDRE) <= '0';
        -- Mark tx-send register as empty 
        elsif (status_tx_empty = '1') then
            status_reg_nxt(STATUS_UDRE) <= '1';
        end if;

        -- Mark end of tx transmission --
        if (status_tx_end = '1') then
            status_reg_nxt(STATUS_TXC) <= '1';
        --  Confirm end of tx transmission 
        elsif ((iobus_ack_txc = '1') or (status_tx_clear = '1')) then
            status_reg_nxt(STATUS_TXC) <= '0';
        end if;
    end process reg_status;

    ----------------------------------------------- UART RX Receiver -------------------------------------------------
    ---- RX Register ----
    rx_ff : process(clock)
    begin
        -- Update states and register on clockedge --
        if (rising_edge(clock)) then
            if (reset_n = '0') then
                rx_state         <= RX_IDLE;
                rx_sample_buffer <= (others => '0');
                rx_buffer        <= (others => '0');
                rx_data_reg      <= (others => '0');
                rx_baud_count    <= (others => '0');
                rx_bit_count     <= 0;
                or_bit           <= '0';
            else
                rx_state         <= rx_state_nxt;
                rx_sample_buffer <= rx_sample_buffer_nxt;
                rx_buffer        <= rx_buffer_nxt;
                rx_data_reg      <= rx_data_reg_nxt;
                rx_baud_count    <= rx_baud_count_nxt;
                rx_bit_count     <= rx_bit_count_nxt;
                or_bit           <= or_bit_nxt;
            end if;
        end if;
    end process rx_ff;

    ---- RX State-Machine ----
    rx_fsm : process(rx, rx_state, rx_bit_count, rx_baud_count, or_bit, rx_buffer, rx_sample_buffer, rx_data_reg, status_reg, ctrl_reg, bitduration)
        -- Temporary "store" received bit --
        variable rx_bit : std_ulogic;
    begin
        -- Default Assignments --
        rx_state_nxt            <= rx_state;
        rx_bit_count_nxt        <= rx_bit_count;
        rx_baud_count_nxt       <= rx_baud_count;
        or_bit_nxt              <= or_bit;
        rx_buffer_nxt           <= rx_buffer;
        rx_data_reg_nxt         <= rx_data_reg;
        rx_sample_buffer_nxt    <= rx & rx_sample_buffer(2 downto 1);
        status_rx_finished      <= '0';
        status_rx_framing_error <= '0';

        RX_STATE_MACHINE : case rx_state is
            -- Wait for beginning of startbit 
            when RX_IDLE =>
                -- Only activate receiver, if enable bit is set 
                if (ctrl_reg(CONTROL_RX_EN) = '1') then
                    -- If '0' on input detected, goto checking startbit correctness
                    if (rx_sample_buffer(rx_sample_buffer'length - 1) = '0') then
                        rx_state_nxt      <= RX_STARTBIT;
                        rx_baud_count_nxt <= (others => '0');
                    end if;
                end if;
            -- Checking correctness of startbit 
            when RX_STARTBIT =>
                -- Middle of startbit reached, evaluate startbit
                if (rx_baud_count = shift_right(bitduration, 1)) then
                    rx_bit := (rx_sample_buffer(0) and rx_sample_buffer(1)) or (rx_sample_buffer(1) and rx_sample_buffer(2)) or (rx_sample_buffer(0) and rx_sample_buffer(2));
                    -- Confirm Startbit 
                    if (rx_bit = '0') then
                        rx_state_nxt      <= RX_DATA;
                        rx_baud_count_nxt <= to_unsigned(1, rx_baud_count_nxt'length);
                        rx_bit_count_nxt  <= 0;
                    -- Otherwise go back to IDLE --
                    else
                        rx_state_nxt <= RX_IDLE;
                    end if;
                -- Wait until middle of startbit reached -- 
                else
                    rx_baud_count_nxt <= rx_baud_count + 1;
                end if;
            -- Receiving databits --
            when RX_DATA =>
                -- Middle of bit reached, evaluate received bit and store in rx buffer -- 
                if (rx_baud_count = (bitduration + 1)) then
                    -- Evaluate bit --
                    rx_bit            := (rx_sample_buffer(0) and rx_sample_buffer(1)) or (rx_sample_buffer(1) and rx_sample_buffer(2)) or (rx_sample_buffer(0) and rx_sample_buffer(2));
                    -- Append bit on high end of buffer --
                    rx_buffer_nxt     <= rx_bit & rx_buffer(IOBUS_DATA_WIDTH - 1 downto 1);
                    rx_bit_count_nxt  <= rx_bit_count + 1;
                    rx_baud_count_nxt <= (others => '0');
                -- All bits received, evaluate stopbit --
                elsif (rx_bit_count = DATABITS) then
                    rx_state_nxt      <= RX_STOPBIT;
                    rx_baud_count_nxt <= rx_baud_count + 1;
                    rx_bit_count_nxt  <= 0;
                -- Wait for middle of current bit --
                else
                    rx_baud_count_nxt <= rx_baud_count + 1;
                end if;
            -- Evaluate the stopbit, framing error and overrun --
            when RX_STOPBIT =>
                -- Middle of stopbit reached, beginning evaluation --
                if (rx_baud_count = (bitduration + 1)) then
                    -- Go back to IDLE state and wait for start bit --
                    rx_state_nxt <= RX_IDLE;
                    -- When outputbuffer full, set overrun bit and discard received byte --
                    if (status_reg(STATUS_RXC) = '1') then
                        or_bit_nxt <= '1';
                    -- Otherwise store received byte in output buffer, check framing error and mark rx dataregister as full --
                    else
                        rx_data_reg_nxt    <= rx_buffer;
                        or_bit_nxt         <= '0';
                        rx_bit             := (rx_sample_buffer(0) and rx_sample_buffer(1)) or (rx_sample_buffer(1) and rx_sample_buffer(2)) or (rx_sample_buffer(0) and rx_sample_buffer(2));
                        status_rx_finished <= '1';
                        -- Mark Rx Register as full & set framing error, if received bit is no stop bit -- 
                        if (rx_bit = '0') then
                            status_rx_framing_error <= '1';
                        end if;
                    end if;
                -- Wait until middle of stopbit reached -- 
                else
                    rx_baud_count_nxt <= rx_baud_count + 1;
                end if;
        end case RX_STATE_MACHINE;
    end process rx_fsm;

    ----------------------------------------------- UART TX Transmitter ----------------------------------------------
    ---- TX Register ----
    tx_ff : process(clock)
    begin
        -- Update states & register on clockedge --
        if (rising_edge(clock)) then
            if (reset_n = '0') then
                tx_state      <= TX_IDLE;
                tx_data_reg   <= (others => '0');
                tx_baud_count <= (others => '0');
                tx_buffer     <= (others => '0');
                tx_bit_count  <= 0;
            else
                tx_state      <= tx_state_nxt;
                tx_data_reg   <= tx_data_reg_nxt;
                tx_baud_count <= tx_baud_count_nxt;
                tx_buffer     <= tx_buffer_nxt;
                tx_bit_count  <= tx_bit_count_nxt;
            end if;
        end if;
    end process tx_ff;

    ---- TX State-Machine ----
    tx_fsm : process(tx_state, tx_bit_count, tx_buffer, tx_baud_count, ctrl_reg, status_reg, tx_data_reg, bitduration)
    begin
        -- Default Assignments --
        tx_state_nxt      <= tx_state;
        tx_bit_count_nxt  <= tx_bit_count;
        tx_buffer_nxt     <= tx_buffer;
        tx_baud_count_nxt <= tx_baud_count;
        status_tx_empty   <= '0';
        status_tx_end     <= '0';

        TX_STATE_MACHINE : case tx_state is
            -- Wait for tx data at tx input --
            when TX_IDLE =>
                -- Keep output on high bit --
                tx <= '1';
                -- Only activate sender, if TX_EN Bit is set --
                if (ctrl_reg(CONTROL_TX_EN) = '1') then
                    -- If send register is full, copy to tx buffer and mark send register as empty --
                    if (status_reg(STATUS_UDRE) = '0') then
                        tx_buffer_nxt     <= tx_data_reg;
                        status_tx_empty   <= '1';
                        -- Begin sendprocess by sending startbit --
                        tx_state_nxt      <= TX_STARTBIT;
                        tx_baud_count_nxt <= (others => '0');
                    end if;
                end if;
            -- Send the startbit via tx output --
            when TX_STARTBIT =>
                -- Set startbit on tx output --
                tx <= '0';
                -- When end of bitduration reached, sending databits --
                if (tx_baud_count = (bitduration - 1)) then
                    tx_state_nxt      <= TX_DATA;
                    tx_baud_count_nxt <= (others => '0');
                    tx_bit_count_nxt  <= 0;
                -- Otherwise keep startbit on tx output --
                else
                    tx_baud_count_nxt <= tx_baud_count + 1;
                end if;
            -- Send the data byte via tx output --
            when TX_DATA =>
                -- Assign lowest bit of bit buffer to tx output --
                tx <= tx_buffer(0);
                -- Update next bit, if end of bitduration is reached --
                if (tx_baud_count = (bitduration - 1)) then
                    -- All databits send, sending stopbit --
                    if (tx_bit_count = (DATABITS - 1)) then
                        tx_state_nxt      <= TX_STOPBIT;
                        tx_baud_count_nxt <= (others => '0');
                    -- Otherwise send next databit --
                    else
                        tx_buffer_nxt     <= '0' & tx_buffer(IOBUS_DATA_WIDTH - 1 downto 1);
                        tx_bit_count_nxt  <= tx_bit_count + 1;
                        tx_baud_count_nxt <= (others => '0');
                    end if;
                -- Otherwise keep databit on tx output --
                else
                    tx_baud_count_nxt <= tx_baud_count + 1;
                end if;
            when TX_STOPBIT =>
                -- Set stopbit on tx output --
                tx <= '1';
                -- If bitduration reached, go into idle state --
                if (tx_baud_count = (bitduration - 1)) then
                    tx_baud_count_nxt <= (others => '0');
                    tx_state_nxt      <= TX_IDLE;
                    -- Signalize end of transfer in status register --
                    status_tx_end     <= '1';
                -- Otherwise keep stopbit on tx output --
                else
                    tx_baud_count_nxt <= tx_baud_count + 1;
                end if;
        end case TX_STATE_MACHINE;
    end process tx_fsm;

    ----------------------------------------------- Signalassignments ------------------------------------------------                                       
    -- Output Signals from Control Register --
--    rx_en <= ctrl_reg(CONTROL_RX_EN);
--    tx_en <= ctrl_reg(CONTROL_TX_EN);

    -- Output Signals from Status Register (Interrupt Request); Disabled when Control Register is unset --
    iobus_irq_rxc  <= status_reg(STATUS_RXC) when (ctrl_reg(CONTROL_RXC_IE) = '1') else '0';
    iobus_irq_txc  <= status_reg(STATUS_TXC) when (ctrl_reg(CONTROL_TXC_IE) = '1') else '0';
    iobus_irq_udre <= status_reg(STATUS_UDRE) when (ctrl_reg(CONTROL_UDR_IE) = '1') else '0';
end architecture rtl;
