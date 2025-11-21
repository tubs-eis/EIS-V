--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: XXXX
--  SPDX-FileCopyrightText: 2024, XXXX
--  Description: Special CSR registers and read/write logic
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_csrs is
    generic (
        HART_ID : integer
    );
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        -- Datapath Interface
        read_sel_i : in special_csr_t;
        read_data_o : out word_t;
        write_enable_i : in std_ulogic;
        write_sel_i : in special_csr_t;
        write_data_i : in word_t;
        -- External Interface
        external_interrupt_pending_i : in std_ulogic;
        timer_interrupt_pending_i : in std_ulogic;
        -- Pipeline Control Interface
        interrupt_stack_push_i : in std_ulogic;
        write_epc_i : in std_ulogic;
        write_epc_value_i : in mem_addr_t;
        write_mtval_i : in std_ulogic;
        write_mtval_value_i : in mem_addr_t;
        epc_o : out mem_addr_t;
        mtvec_o : out mem_addr_t;
        mstatus_mie_o : out std_ulogic;
        mie_mtie_o : out std_ulogic;
        mie_meie_o : out std_ulogic;
        -- Controller Interface
        trap_enter_i : in std_ulogic;
        trap_leave_i : in std_ulogic;
        trap_cause_i : in trap_cause_t
    );
end entity;

architecture rtl of eisv_csrs is

    signal epc_ff, epc_nxt : mem_addr_t;
    signal mtvec_ff, mtvec_nxt : mem_addr_t;
    signal mstatus_mie_ff, mstatus_mie_nxt : std_ulogic;
    signal mstatus_mpie_ff, mstatus_mpie_nxt : std_ulogic;
    signal mcause_is_interrupt_ff, mcause_is_interrupt_nxt : std_ulogic;
    signal mcause_code_ff, mcause_code_nxt : trap_code_t;
    signal mtval_ff, mtval_nxt : mem_addr_t;
    signal mie_meie_ff, mie_meie_nxt : std_ulogic;
    signal mie_mtie_ff, mie_mtie_nxt : std_ulogic;
    signal mscratch_ff, mscratch_nxt : word_t;

begin

    csr_seq : process (clk_i) is
    begin
        if rising_edge(clk_i) then
            if rst_ni then
                epc_ff <= epc_nxt;
                mtvec_ff <= mtvec_nxt;
                mstatus_mie_ff <= mstatus_mie_nxt;
                mstatus_mpie_ff <= mstatus_mpie_nxt;
                mcause_is_interrupt_ff <= mcause_is_interrupt_nxt;
                mcause_code_ff <= mcause_code_nxt;
                mtval_ff <= mtval_nxt;
                mie_meie_ff <= mie_meie_nxt;
                mie_mtie_ff <= mie_mtie_nxt;
                mscratch_ff <= mscratch_nxt;
            else
                mtvec_ff <= (others => '0');
                mstatus_mie_ff <= '0';
                mstatus_mpie_ff <= '0';
                mie_meie_ff <= '1';
                mie_mtie_ff <= '1';
            end if;
        end if;
    end process;

    special_csr_read : process (all) is
    begin
        case (read_sel_i) is
            when MHARTID => read_data_o <= word_t(to_unsigned(HART_ID, word_t'length));
            when MEPC => read_data_o <= word_t(epc_ff);
            when MTVEC => read_data_o <= word_t(mtvec_ff);
            when MSTATUS =>
                read_data_o <= (
                    1 => '0', -- SIE
                    3 => mstatus_mie_ff, -- MIE
                    5 => '0', -- SPIE
                    6 => '0', -- UBE
                    7 => mstatus_mpie_ff, -- MPIE
                    8 => '1', -- SPP
                    10 downto 9 => '0', -- VS
                    12 downto 11 => '1', -- MPP
                    14 downto 13 => '0', -- FS
                    16 downto 15 => '0', -- XS,
                    17 => '0', -- MPRV
                    18 => '0', -- SUM
                    19 => '0', -- MXR
                    20 => '0', -- TVM
                    21 => '0', -- TW
                    22 => '0', -- TSR
                    31 => '0', -- SD
                    others => '0' -- WPRI
                );
            when MCAUSE =>
                read_data_o(31) <= mcause_is_interrupt_ff;
                read_data_o(30 downto 6) <= (others => '0');
                for i in 5 downto 0 loop
                    read_data_o(i) <= mcause_code_ff(i);
                end loop;
            when MISA =>
                read_data_o <= (
                    0 => '0', -- A
                    1 => '0', -- B
                    2 => '0', -- C
                    3 => '0', -- D
                    4 => '0', -- E
                    5 => '0', -- F
                    7 => '0', -- H
                    8 => '1', -- I
                    12 => eisv_cfg.isa_enable_M_c, -- M
                    16 => '0', -- Q
                    18 => '0', -- S
                    20 => '0', -- U
                    21 => '0', -- V
                    23 => '0', -- X
                    -- MXLEN = 32
                    30 => '1',
                    31 => '0',
                    others => '0'
                );
            when MTVAL => read_data_o <= word_t(mtval_ff);
            when MIE => read_data_o <= (
                    7 => mie_mtie_ff,
                    11 => mie_meie_ff,
                    others => '0'
                );
            when MIP => read_data_o <= (
                    7 => external_interrupt_pending_i,
                    11 => timer_interrupt_pending_i,
                    others => '0'
                );
            when MSCRATCH => read_data_o <= mscratch_ff;
        end case;
    end process;

    special_csr_write : process (all) is
    begin
        epc_nxt <= epc_ff;
        mtvec_nxt <= mtvec_ff;
        mstatus_mie_nxt <= mstatus_mie_ff;
        mstatus_mpie_nxt <= mstatus_mpie_ff;
        mcause_is_interrupt_nxt <= mcause_is_interrupt_ff;
        mcause_code_nxt <= mcause_code_ff;
        mtval_nxt <= mtval_ff;
        mie_meie_nxt <= mie_meie_ff;
        mie_mtie_nxt <= mie_mtie_ff;
        mscratch_nxt <= mscratch_ff;

        if write_enable_i then
            case write_sel_i is
                when MHARTID => null;
                when MEPC => epc_nxt <= mem_addr_t(write_data_i);
                when MTVEC => mtvec_nxt <= mem_addr_t(write_data_i);
                when MSTATUS =>
                    mstatus_mie_nxt <= write_data_i(3);
                    mstatus_mpie_nxt <= write_data_i(7);
                when MCAUSE =>
                    mcause_is_interrupt_nxt <= write_data_i(31);
                    mcause_code_nxt <= trap_code_t(write_data_i(5 downto 0));
                when MISA => null;
                when MTVAL => mtval_nxt <= mem_addr_t(write_data_i);
                when MIE =>
                    mie_mtie_nxt <= write_data_i(7);
                    mie_meie_nxt <= write_data_i(11);
                when MIP => null;
                when MSCRATCH => mscratch_nxt <= write_data_i;
            end case;
        end if;

        if write_epc_i then
            epc_nxt <= write_epc_value_i;
        end if;

        if write_mtval_i then
            mtval_nxt <= write_mtval_value_i;
        end if;

        if trap_enter_i then
            case trap_cause_i is
                when TIMER_INTERRUPT =>
                    mcause_is_interrupt_nxt <= '1';
                    mcause_code_nxt <= trap_code_t(to_unsigned(7, trap_code_t'length));
                when EXTERNAL_INTERRUPT =>
                    mcause_is_interrupt_nxt <= '1';
                    mcause_code_nxt <= trap_code_t(to_unsigned(11, trap_code_t'length));
                when INSTRUCTION_ADDRESS_MISALIGNED =>
                    mcause_is_interrupt_nxt <= '0';
                    mcause_code_nxt <= trap_code_t(to_unsigned(0, trap_code_t'length));
                when ILLEGAL_INSTRUCTION =>
                    mcause_is_interrupt_nxt <= '0';
                    mcause_code_nxt <= trap_code_t(to_unsigned(2, trap_code_t'length));
                when BREAKPOINT =>
                    mcause_is_interrupt_nxt <= '0';
                    mcause_code_nxt <= trap_code_t(to_unsigned(3, trap_code_t'length));
                when LOAD_ADDRESS_MISALIGNED =>
                    mcause_is_interrupt_nxt <= '0';
                    mcause_code_nxt <= trap_code_t(to_unsigned(4, trap_code_t'length));
                when STORE_ADDRESS_MISALIGNED =>
                    mcause_is_interrupt_nxt <= '0';
                    mcause_code_nxt <= trap_code_t(to_unsigned(6, trap_code_t'length));
                when ENVIRONMNENT_CALL =>
                    mcause_is_interrupt_nxt <= '0';
                    mcause_code_nxt <= trap_code_t(to_unsigned(11, trap_code_t'length));
            end case;
        end if;

        if interrupt_stack_push_i then
            mstatus_mie_nxt <= '0';
            mstatus_mpie_nxt <= mstatus_mie_ff;
        end if;

        if trap_leave_i then
            mstatus_mie_nxt <= mstatus_mpie_ff;
            mstatus_mpie_nxt <= '1';
        end if;
    end process;

    epc_o <= epc_ff;
    mtvec_o <= mtvec_ff;
    mstatus_mie_o <= mstatus_mie_ff;
    mie_mtie_o <= mie_mtie_ff;
    mie_meie_o <= mie_meie_ff;

end architecture;