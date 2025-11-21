--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: XXXX
--  SPDX-FileCopyrightText: 2024, XXXX
--  Description: EISV Core Top decode stage
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_de_stage is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        pipeline_i : in if_pipeline_t;
        pc_i : in mem_addr_t;
        instr_rdata_i : in word_t;
        instr_valid_i : in std_ulogic;
        pipeline_o : out de_pipeline_t;
        ctrl_o : out control_word_t
    );
end entity;

architecture rtl of eisv_de_stage is

    signal decoded_instruction : decoded_instruction_t;
    signal ctrl : control_word_t;

begin

    decoder_inst: entity eisv.eisv_decoder
     port map(
        clk_i => clk_i,
        rst_ni => rst_ni,
        instruction_word_i => instr_rdata_i,
        decoded_instruction_o => decoded_instruction
     );

    ctrl_unit_inst : entity eisv.eisv_ctrl_unit
     port map(
        clk_i => clk_i,
        rst_ni => rst_ni,
        instruction_i => decoded_instruction,
        enable_i => instr_valid_i,
        ctrl_o => ctrl
     );

    pc_offset_adder : process (all) is
        variable pc : signed(31 downto 0);
        variable offset : signed(31 downto 0);
    begin
        pc := signed(pc_i);
        offset := resize(signed(decoded_instruction.imm(21 downto 0)), 32);
        pipeline_o.pc_offset <= mem_addr_t(pc + offset);
    end process;

    ctrl_o <= ctrl;

    pipeline_o.pc <= pc_i;
    pipeline_o.imm <= decoded_instruction.imm;
    pipeline_o.rs1 <= decoded_instruction.rs1;
    pipeline_o.rp1_addr <= decoded_instruction.rs1;
    pipeline_o.rp2_addr <= decoded_instruction.rs2;
    pipeline_o.rd <= decoded_instruction.rd;

end architecture;
