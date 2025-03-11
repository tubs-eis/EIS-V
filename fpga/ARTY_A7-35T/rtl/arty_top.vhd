-- Top File for Arty Board

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

library fpga;

entity arty_top is
    port (
        -- Clock and reset
        clk_i : in std_ulogic;
        reset_ni : in std_ulogic;
        -- LEDs
        led_o : out std_ulogic_vector(3 downto 0);
        -- UART
        uart_rx_i : in std_ulogic;
        uart_tx_o : out std_ulogic
    );
end entity;

architecture rtl of arty_top is

    signal core_clk : std_ulogic;

    -- Memory Bus
    signal instr_addr : std_ulogic_vector(31 downto 0);
    signal instr_ren : std_ulogic;
    signal instr_rdata : std_ulogic_vector(31 downto 0);
    signal instr_active : std_ulogic;

    signal data_wen : std_ulogic;
    signal data_ren : std_ulogic;
    signal data_be : std_ulogic_vector(3 downto 0);
    signal data_addr : std_ulogic_vector(31 downto 0);
    signal data_wdata : std_ulogic_vector(31 downto 0);
    signal data_rdata : std_ulogic_vector(31 downto 0);
    signal data_active : std_ulogic;

    -- (ROM)
    constant ROM_BASE_ADDR : std_ulogic_vector(31 downto 0) := x"00000000";
    constant ROM_ADDR_BITS : natural := 10;
    
    signal data_rom_select : std_ulogic;
    signal data_rom_select_reg : std_ulogic;
    signal data_rom_addr : std_ulogic_vector(ROM_ADDR_BITS-1 downto 0);
    signal data_rom_rdata : std_ulogic_vector(31 downto 0);

    signal instr_rom_select : std_ulogic;
    signal instr_rom_select_reg : std_ulogic;
    signal instr_rom_addr : std_ulogic_vector(ROM_ADDR_BITS-1 downto 0);
    signal instr_rom_rdata : std_ulogic_vector(31 downto 0);

    -- (RAM)
    constant RAM_BASE_ADDR : std_ulogic_vector(31 downto 0) := x"10000000";
    constant RAM_ADDR_BITS : natural := 16;
    -- TODO: Extract peripheral connections into record
    --       Then use function for easier extendability
    signal data_ram_select : std_ulogic;
    signal data_ram_select_reg : std_ulogic;
    signal data_ram_addr : std_ulogic_vector(RAM_ADDR_BITS-1 downto 0);
    signal data_ram_wdata : std_ulogic_vector(31 downto 0);
    signal data_ram_rdata : std_ulogic_vector(31 downto 0);

    signal instr_ram_select : std_ulogic;
    signal instr_ram_select_reg : std_ulogic;
    signal instr_ram_addr : std_ulogic_vector(RAM_ADDR_BITS-1 downto 0);
    signal instr_ram_rdata : std_ulogic_vector(31 downto 0);

    -- Peripherals
    -- LEDs 
    signal led_ff, led_nxt : std_ulogic_vector(3 downto 0);

    -- UART
    constant UART_BASE_ADDR : std_ulogic_vector(31 downto 0) := x"90000000";
    constant UART_ADDR_BITS : natural := 4;

    constant UART_REGISTER_WIDTH : natural := 8;
    signal data_uart_select : std_ulogic;
    signal data_uart_select_reg : std_ulogic;
    signal data_uart_addr : std_ulogic_vector(UART_ADDR_BITS-1 downto 0);
    signal data_uart_wdata : std_ulogic_vector(UART_REGISTER_WIDTH-1 downto 0);
    signal data_uart_rdata : std_ulogic_vector(UART_REGISTER_WIDTH-1 downto 0);
    signal data_uart_rdata_reg : std_ulogic_vector(UART_REGISTER_WIDTH-1 downto 0);

    -- Vivado IPs
    component clk_wiz_core_clk
        port (
            clk_out1 : out std_ulogic;
            clk_in1 : in std_ulogic
        );
    end component;

begin

    -- Core instantiation
    core_wrapper_inst: entity eisv.eisv_core_wrapper
     port map(
        clk_i => core_clk,
        rst_ni => reset_ni,
        imem_addr_o => instr_addr,
        imem_ren_o => instr_ren,
        imem_rdata_i => instr_rdata,
        dmem_addr_o => data_addr,
        dmem_ren_o => data_ren,
        dmem_rdata_i => data_rdata,
        dmem_wen_o => data_wen,
        dmem_wdata_o => data_wdata,
        dmem_byte_enable_o => data_be,
        external_interrupt_pending_i => '0',
        timer_interrupt_pending_i => '0'
    );

    -- Memory instantiation
    memory_inst : entity fpga.arty_memory
        generic map (
            DATA_WIDTH => 32,
            ADDR_WIDTH => RAM_ADDR_BITS-2
        )
        port map (
            clk_i => core_clk,
            port_a_we_i => '0',
            port_a_addr_i => instr_ram_addr(RAM_ADDR_BITS-1 downto 2),
            port_a_wdata_i => (others => '0'),
            port_a_rdata_o => instr_ram_rdata,
            port_b_we_i => data_wen and data_ram_select,
            port_b_be_i => data_be,
            port_b_addr_i => data_ram_addr(RAM_ADDR_BITS-1 downto 2),
            port_b_wdata_i => data_ram_wdata,
            port_b_rdata_o => data_ram_rdata
        );

    rom_inst : entity fpga.arty_rom
        port map (
            clk_i => core_clk,
            port_a_addr_i => (31 downto ROM_ADDR_BITS => '0') & instr_rom_addr,
            port_a_data_o => instr_rom_rdata,
            port_b_addr_i => (31 downto ROM_ADDR_BITS => '0') & data_rom_addr,
            port_b_data_o => data_rom_rdata
        );

    -- Peripheral instantiation
    uart_inst : entity fpga.uart
        generic map (
            IOBUS_DATA_WIDTH => 8,
            CLOCK_FREQ => 25000000,
            BAUDRATE => 115200 
        )
        port map (
            clock => core_clk,
            reset_n => reset_ni,
            iobus_cs => data_uart_select,
            iobus_wr => data_wen and data_uart_select,
            iobus_addr => data_uart_addr(3 downto 2), 
            iobus_din => data_uart_wdata,
            iobus_dout => data_uart_rdata,
            iobus_irq_rxc => open,
            iobus_irq_udre => open,
            iobus_irq_txc => open,
            iobus_ack_rxc => '0',
            iobus_ack_udre => '0',
            iobus_ack_txc => '0',
            rx => uart_rx_i,
            tx => uart_tx_o
        );

    -- BUS Logic
    data_active <= data_ren or data_wen;
    instr_active <= instr_ren;
    -- ROM
    data_rom_select <= data_active and data_addr(31 downto ROM_ADDR_BITS) ?= ROM_BASE_ADDR(31 downto ROM_ADDR_BITS);
    data_rom_addr <= data_addr(ROM_ADDR_BITS-1 downto 0) when data_rom_select else (others => '0');

    instr_rom_select <= instr_active and instr_addr(31 downto ROM_ADDR_BITS) ?= ROM_BASE_ADDR(31 downto ROM_ADDR_BITS);
    instr_rom_addr <= instr_addr(ROM_ADDR_BITS-1 downto 0) when instr_rom_select else (others => '0');

    -- DMEM
    data_ram_select <= data_active and data_addr(31 downto RAM_ADDR_BITS) ?= RAM_BASE_ADDR(31 downto RAM_ADDR_BITS);
    data_ram_addr <= data_addr(RAM_ADDR_BITS-1 downto 0) when data_ram_select else (others => '0');
    data_ram_wdata <= data_wdata when data_ram_select else (others => '0');

    instr_ram_select <= instr_active and instr_addr(31 downto RAM_ADDR_BITS) ?= RAM_BASE_ADDR(31 downto RAM_ADDR_BITS);
    instr_ram_addr <= instr_addr(RAM_ADDR_BITS-1 downto 0) when instr_ram_select else (others => '0');

    -- LED
    led_write : process (all) is
    begin
        led_nxt <= led_ff;
        if (??data_wen) and unsigned(data_addr) = x"80000000" then
            led_nxt <= data_wdata(3 downto 0);
        end if;
    end process;

    -- UART
    data_uart_select <= data_active and data_addr(31 downto UART_ADDR_BITS) ?= UART_BASE_ADDR(31 downto UART_ADDR_BITS);
    data_uart_addr <= data_addr(UART_ADDR_BITS-1 downto 0) when data_uart_select else "0000";
    data_uart_wdata <= data_wdata(UART_REGISTER_WIDTH-1 downto 0) when data_uart_select else (others => '0');

    uart_seq: process (core_clk) is
    begin
        if rising_edge(core_clk) then
            data_uart_rdata_reg <= data_uart_rdata;
        end if;
    end process;

    -- Register select signals for read
    select_seq : process (core_clk) is
    begin
        if rising_edge(core_clk) then
            data_ram_select_reg <= data_ram_select;
            data_uart_select_reg <= data_uart_select;
            data_rom_select_reg <= data_rom_select;

            instr_ram_select_reg <= instr_ram_select;
            instr_rom_select_reg <= instr_rom_select;
        end if;
    end process;
    -- MUX Read
    data_rdata <= data_rom_rdata when data_rom_select_reg else
                  data_ram_rdata when data_ram_select_reg else
                  (31 downto UART_REGISTER_WIDTH => '0') & data_uart_rdata_reg when data_uart_select_reg else
                  (others => '0');

    instr_rdata <= instr_rom_rdata when instr_rom_select_reg else
                   instr_ram_rdata when instr_ram_select_reg else
                   (others => '0');

    seq: process (core_clk) is
    begin
        if rising_edge(core_clk) then
            if reset_ni then
                led_ff <= led_nxt;
            else
                led_ff <= (others => '0');
            end if;
        end if;
    end process;

    led_o <= led_ff;

    -- Vivado IP instantiation
    clk_wiz_core_clk_inst : clk_wiz_core_clk
        port map (
            clk_out1 => core_clk,
            clk_in1 => clk_i
        );

end architecture;