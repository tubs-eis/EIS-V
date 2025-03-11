--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: RISCV instruction decoder, decodes opcode field and splits instruction word according to instruction type
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_decoder is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        instruction_word_i : in word_t;
        decoded_instruction_o : out decoded_instruction_t
    );
end entity;

architecture rtl of eisv_decoder is

    -- OP Code Map (Table 24.1)
    function map_opcode(opcode : encoded_opcode_t) return opcode_t is

        type opcode_map_column_t is array(0 to 3) of opcode_t;
        type opcode_map_t is array(0 to 7) of opcode_map_column_t;

        constant opcode_map : opcode_map_t :=
            (
                (OP_LOAD,      OP_STORE,    OP_MADD,     OP_BRANCH),
                (OP_LOAD_FP,   OP_STORE_FP, OP_MSUB,     OP_JALR),
                (OP_CUST_0,    OP_CUST_1,   OP_NMSUB,    OP_RESVD_0),
                (OP_MISC_MEM,  OP_AMO,      OP_NMADD,    OP_JAL),
                (OP_OP_IMM,    OP_OP,       OP_OP_FP,    OP_SYSTEM),
                (OP_AUIPC,     OP_LUI,      OP_RESVD_1,  OP_RESVD_2),
                (OP_OP_IMM_32, OP_OP_32,    OP_CUST_2,   OP_CUST_3),
                (OP_48B_0,     OP_64B,      OP_48B_1,    OP_GE_80B)
            );

        variable opcode_map_column_index : unsigned(2 downto 0);
        variable opcode_map_row_index : unsigned(1 downto 0);
    begin

        opcode_map_column_index := unsigned(opcode(4 downto 2));
        opcode_map_row_index := unsigned(opcode(6 downto 5));

        return opcode_map(to_integer(opcode_map_column_index))
                         (to_integer(opcode_map_row_index));

    end function;

    function decode(instruction : word_t) return decoded_instruction_t is
        type format_t is (
            R, I, S, B, U, J
        );

        variable format : format_t;
        variable result : decoded_instruction_t;

        variable encoded_opcode : encoded_opcode_t;
    begin
        -- All early returns are inavlid
        result.valid := '0';

        result.funct7 := std_ulogic_vector(instruction(31 downto 25));
        result.rs2 := rf_addr_t(instruction(24 downto 20));
        result.shamt := shamt_t(instruction(24 downto 20));
        result.rs1 := rf_addr_t(instruction(19 downto 15));
        result.funct3 := std_ulogic_vector(instruction(14 downto 12));
        result.rd := rf_addr_t(instruction(11 downto 7));
        encoded_opcode := encoded_opcode_t(instruction(6 downto 0));

        result.opcode := std_ulogic_vector(encoded_opcode);

        -- Check if instruction is not 32 bit
        if encoded_opcode(1) nand encoded_opcode(0) then
            return result;
        end if;

        case map_opcode(encoded_opcode) is
            when OP_OP_IMM | OP_JALR | OP_LOAD | OP_MISC_MEM => format := I;
            when OP_LUI | OP_AUIPC => format := U;
            when OP_OP | OP_SYSTEM => format := R;
            when OP_JAL => format := J;
            when OP_BRANCH => format := B;
            when OP_STORE => format := S;
            when others => return result;
        end case;

        result.imm(31) := instruction(31);
        case (format) is
            when U => result.imm(30 downto 20) := instruction(30 downto 20);
            when others => result.imm(30 downto 20) := (others => instruction(31));
        end case;
        case (format) is
            when U | J => result.imm(19 downto 12) := instruction(19 downto 12);
            when others => result.imm(19 downto 12) := (others => instruction(31));
        end case;
        case (format) is
            when B => result.imm(11) := instruction(7);
            when U => result.imm(11) := '0';
            when J => result.imm(11) := instruction(20);
            when others => result.imm(11) := instruction(31);
        end case;
        case (format) is
            when U => result.imm(10 downto 5) := (others => '0');
            when others => result.imm(10 downto 5) := instruction(30 downto 25);
        end case;
        case (format) is
            when I | J => result.imm(4 downto 1) := instruction(24 downto 21);
            when S | B => result.imm(4 downto 1) := instruction(11 downto 8);
            when others => result.imm(4 downto 1) := (others => '0');
        end case;
        case (format) is
            when I => result.imm(0) := instruction(20);
            when S => result.imm(0) := instruction(7);
            when others => result.imm(0) := '0';
        end case;

        result.valid := '1';
        return result;
    end function;

    signal decoded_instruction : decoded_instruction_t;

begin

    process (all) is
    begin
        if rst_ni then
            decoded_instruction <= decode(instruction_word_i);
        else
            decoded_instruction <= decode((others => '0'));
        end if;
    end process;

    decoded_instruction_o <= decoded_instruction;

end architecture;