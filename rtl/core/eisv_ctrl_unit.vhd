--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: XXXX
--  SPDX-FileCopyrightText: 2024, XXXX
--  Description: EISV Core control signal generation
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;
use eisv.eisv_config_pkg.all;

entity eisv_ctrl_unit is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        instruction_i : in decoded_instruction_t;
        enable_i : in std_ulogic;
        ctrl_o : out control_word_t
    );
end entity;

architecture rtl of eisv_ctrl_unit is
    -- Generated ctrl output
    signal gen_ctrl_out : control_word_t;

    -- CSR Decoder Signals
    signal csr_decoder_implementation : csr_implementation_t;
    signal csr_decoder_special_csr : special_csr_t;
begin

    ctrl_table : entity eisv.eisv_ctrl
        port map (
            instruction_i => instruction_i,
            ctrl_o => gen_ctrl_out
        );

    ctrl : process (all) is
        variable system_opcode : bit_vector(11 downto 0);
    begin
        ctrl_o <= CTRL_NOP;

        if enable_i then
            ctrl_o <= gen_ctrl_out;

            if gen_ctrl_out.is_csr then
                if csr_decoder_implementation /= UNIMPLEMENTED then
                    ctrl_o.valid <= '1';
                    ctrl_o.csr_access <= '1';
                    ctrl_o.rf_wp1_enable <= '1';
                    ctrl_o.rf_write_sel <= OPB;
                    ctrl_o.eu_result_is_result <= '0';
                end if;

                if csr_decoder_implementation = SPECIAL then
                    ctrl_o.special_csr_write <= '1';
                    ctrl_o.operand_b_sel <= CSR;
                    ctrl_o.special_csr <= csr_decoder_special_csr;
                end if;
            end if;

            if gen_ctrl_out.is_system then
                if nor (std_ulogic_vector(instruction_i.rs1) & std_ulogic_vector(instruction_i.rd)) then
                    system_opcode := to_bitvector(instruction_i.funct7) & to_bitvector(std_ulogic_vector(instruction_i.rs2));
                    case system_opcode is
                        when "0011000" & "00010" => -- MRET
                            ctrl_o.valid <= '1';
                            ctrl_o.trap_return <= '1';
                        when "0000000" & "00000" => -- ECALL
                            ctrl_o.valid <= '1';
                            ctrl_o.ecall <= '1';
                        when "0000000" & "00001" => -- EBREAK
                            ctrl_o.valid <= '0'; -- TODO: Check if this should really be invalid
                            ctrl_o.ebreak <= '1';
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process;

    csr_decode : process (all) is
        variable csr_address : bit_vector(11 downto 0);
    begin
        csr_decoder_implementation <= READ_ONLY_ZERO;
        csr_decoder_special_csr <= MISA;

        -- RISV Priviledged Spec, Tables 3. - 8.
        csr_address := to_bitvector(instruction_i.funct7) & to_bitvector(std_ulogic_vector(instruction_i.rs2));
        case csr_address is
            -- Table 7
            -- Machine Information Registers
            when x"F11" => csr_decoder_implementation <= READ_ONLY_ZERO; -- mvendorid
            when x"F12" => csr_decoder_implementation <= READ_ONLY_ZERO; -- marchid
            when x"F13" => csr_decoder_implementation <= READ_ONLY_ZERO; -- mimpid
            when x"F14" => -- mhartid
                csr_decoder_implementation <= SPECIAL;
                csr_decoder_special_csr <= MHARTID;
            when x"F15" => csr_decoder_implementation <= READ_ONLY_ZERO; -- mconfigptr
            -- Machine Trap Setup
            when x"300" => -- mstatus
                csr_decoder_implementation <= SPECIAL;
                csr_decoder_special_csr <= MSTATUS;
            when x"301" => -- misa
                csr_decoder_implementation <= SPECIAL;
                csr_decoder_special_csr <= MISA;
            when x"302" => csr_decoder_implementation <= UNIMPLEMENTED; -- medeleg
            when x"303" => csr_decoder_implementation <= UNIMPLEMENTED; -- mideleg
            when x"304" => -- mie
                csr_decoder_implementation <= SPECIAL;
                csr_decoder_special_csr <= MIE;
            when x"305" => -- mtvec
                csr_decoder_implementation <= SPECIAL;
                csr_decoder_special_csr <= MTVEC;
            when x"306" => csr_decoder_implementation <= UNIMPLEMENTED; -- mcounteren
            when x"310" => csr_decoder_implementation <= READ_ONLY_ZERO; -- mstatush
            when x"312" => csr_decoder_implementation <= UNIMPLEMENTED; -- medelegh
            -- Machine Trap Handling
            when x"340" => -- mscratch
                csr_decoder_implementation <= SPECIAL;
                csr_decoder_special_csr <= MSCRATCH;
            when x"341" => -- mepc
                csr_decoder_implementation <= SPECIAL;
                csr_decoder_special_csr <= MEPC;
            when x"342" => -- mcause
                csr_decoder_implementation <= SPECIAL;
                csr_decoder_special_csr <= MCAUSE;
            when x"343" => -- mtval
                csr_decoder_implementation <= SPECIAL;
                csr_decoder_special_csr <= MTVAL;
            when x"344" => -- mip
                csr_decoder_implementation <= SPECIAL;
                csr_decoder_special_csr <= MIP;
            when x"34A" => csr_decoder_implementation <= READ_ONLY_ZERO; -- mtinst
            when x"34B" => csr_decoder_implementation <= READ_ONLY_ZERO; -- mtval2
            -- Machine Configuration
            when others => csr_decoder_implementation <= UNIMPLEMENTED;
        end case;
    end process;

end architecture;
