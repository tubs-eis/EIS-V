--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: XXXX
--  SPDX-FileCopyrightText: 2024, XXXX
--  Description: EISV Core hazard detection
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_hazard_unit is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        de_ctrl_out_i : in control_word_t;
        de_pipeline_out_i : in de_pipeline_t;
        de_pipeline_reg_i : in de_pipeline_t;
        ex_ctrl_i : in control_word_t;
        ex_pipeline_reg_i : in ex_pipeline_t;
        mem_ctrl_i : in control_word_t;
        mem_pipeline_reg_i : in mem_pipeline_t;
        wb_ctrl_i : in control_word_t;
        hazard_o : out hazard_t
    );
end entity;

architecture rtl of eisv_hazard_unit is

    type stages_t is (EX, MEM, WB);
    type rd_match_t is array (stages_t) of std_ulogic;

    function match_to_forward(match : rd_match_t) return forward_sel_t is
    begin
        if match(EX) then
            return EX;
        elsif match(MEM) then
            return MEM;
        elsif match(WB) then
            return WB;
        else
            return REG;
        end if;
    end function;

begin

    hazard_comb : process (all) is
        variable operand_a_match : rd_match_t;
        variable operand_b_match : rd_match_t;

        variable rp1_addr, rp2_addr : rf_addr_t;

        variable forward_from_ex : boolean;

        variable hazard : hazard_t;

        variable csr_access_in_pipeline : std_ulogic;
    begin
        rp1_addr := de_pipeline_out_i.rp1_addr;
        rp2_addr := de_pipeline_out_i.rp2_addr;

        operand_a_match := (
            EX => ex_ctrl_i.rf_wp1_enable and (std_ulogic_vector(rp1_addr) ?= std_ulogic_vector(de_pipeline_reg_i.rd)),
            MEM => mem_ctrl_i.rf_wp1_enable and (std_ulogic_vector(rp1_addr) ?= std_ulogic_vector(ex_pipeline_reg_i.rd)),
            WB => wb_ctrl_i.rf_wp1_enable and (std_ulogic_vector(rp1_addr) ?= std_ulogic_vector(mem_pipeline_reg_i.rd))
        );

        operand_b_match := (
            EX => ex_ctrl_i.rf_wp1_enable and (std_ulogic_vector(rp2_addr) ?= std_ulogic_vector(de_pipeline_reg_i.rd)),
            MEM => mem_ctrl_i.rf_wp1_enable and (std_ulogic_vector(rp2_addr) ?= std_ulogic_vector(ex_pipeline_reg_i.rd)),
            WB => wb_ctrl_i.rf_wp1_enable and (std_ulogic_vector(rp2_addr) ?= std_ulogic_vector(mem_pipeline_reg_i.rd))
        );

        hazard.operand_a_forward_sel := match_to_forward(operand_a_match);
        hazard.operand_b_forward_sel := match_to_forward(operand_b_match);

        if rp1_addr = R0 or not (??de_ctrl_out_i.rf_rp1_enable) then
            hazard.operand_a_forward_sel := REG;
        end if;

        if rp2_addr = R0 or not (??de_ctrl_out_i.rf_rp2_enable) then
            hazard.operand_b_forward_sel := REG;
        end if;

        forward_from_ex := hazard.operand_a_forward_sel = EX or hazard.operand_b_forward_sel = EX;

        hazard.stall := '0';
        if forward_from_ex and not (??ex_ctrl_i.eu_result_is_result) then
            hazard.stall := '1';
        end if;

        csr_access_in_pipeline := ex_ctrl_i.csr_access or mem_ctrl_i.csr_access or wb_ctrl_i.csr_access;
        if de_ctrl_out_i.csr_access and csr_access_in_pipeline then
            hazard.stall := '1';
        end if;

        hazard_o <= hazard;
    end process;

end architecture;