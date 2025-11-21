--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: XXXX
--  SPDX-FileCopyrightText: 2024, XXXX
--  Description: EISV Core execute stage
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;
use eisv.eisv_config_pkg.all;

entity eisv_ex_stage is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        ctrl_i : in control_word_t;
        pipeline_i : in de_pipeline_t;
        special_csr_value_i : in word_t;
        rp1_forward_i : in word_t;
        rp2_forward_i : in word_t;
        pipeline_o : out ex_pipeline_t
    );
end entity;

architecture rtl of eisv_ex_stage is

    signal operand_a : word_t;
    signal operand_b : word_t;

    signal adder_result : word_t;
    signal carry_out : std_ulogic;
    signal adder_less : std_ulogic;

    signal logic_unit_result : word_t;
    signal logic_unit_zero : std_ulogic;

    signal shifter_result : word_t;

    signal mul_enable : std_ulogic;
    signal mul_result : word_t;

    signal div_enable : std_ulogic;
    signal div_result : word_t;

    signal selected_condition : std_ulogic;

begin

    operand_select : process (all) is
    begin
        case (ctrl_i.operand_a_sel) is
            when REG => operand_a <= rp1_forward_i;
            when PC => operand_a <= word_t(pipeline_i.pc);
            when ZERO => operand_a <= (others => '0');
            when RS1 => operand_a <= word_t(resize(unsigned(pipeline_i.rs1), word_t'length));
        end case;

        case (ctrl_i.operand_b_sel) is
            when REG => operand_b <= rp2_forward_i;
            when IMM => operand_b <= pipeline_i.imm;
            when CSR => operand_b <= special_csr_value_i;
        end case;
    end process;

    adder_inst : entity eisv.eisv_adder
        port map(
            clk_i => clk_i,
            rst_ni => rst_ni,
            op_a_i => operand_a,
            op_b_i => operand_b,
            addsub_i => ctrl_i.addsub,
            set_lsb_zero => ctrl_i.adder_set_lsb_zero,
            result_o => adder_result,
            carry_out_o => carry_out,
            less_o => adder_less
        );

    logic_unit_inst: entity eisv.eisv_logic_unit
        port map(
            clk_i => clk_i,
            rst_ni => rst_ni,
            op_a_i => operand_a,
            op_b_i => operand_b,
            logic_op_i => ctrl_i.logic_op,
            result_o => logic_unit_result,
            zero_o => logic_unit_zero
        );

   shifter_inst: entity eisv.eisv_shifter
        port map(
            clk_i => clk_i,
            rst_ni => rst_ni,
            data_i => operand_a,
            shamt_i => shamt_t(operand_b(4 downto 0)),
            shift_mode_i => ctrl_i.shift_mode,
            result_o => shifter_result
        );

    mul_enable <= '1' when ctrl_i.eu_result_sel = MULTIPLIER else '0';
    eisv_mul_inst: entity eisv.eisv_mul
    port map(
        clk_i => clk_i,
        rst_ni => rst_ni,
        enable_i => mul_enable,
        op_a_i => operand_a,
        op_b_i => operand_b,
        mul_mode_i => ctrl_i.mul_mode,
        result_o => mul_result,
        valid_o => open
    );

    div_enable <= '1' when ctrl_i.eu_result_sel = DIVIDER else '0';
    eisv_div_inst: entity eisv.eisv_div
     port map(
        clk_i => clk_i,
        rst_ni => rst_ni,
        enable_i => div_enable,
        op_a_i => operand_a,
        op_b_i => operand_b,
        div_mode_i => ctrl_i.div_mode,
        result_o => div_result
    );

    condition_sel : process (all) is
    begin
        case ctrl_i.condition is
            when ALWAYS => selected_condition <= '1';
            when ZERO => selected_condition <= logic_unit_zero;
            when NOT_ZERO => selected_condition <= not logic_unit_zero;
            when LESS => selected_condition <= adder_less;
            when NOT_LESS => selected_condition <= not adder_less;
            when CARRY => selected_condition <= carry_out;
            when NOT_CARRY => selected_condition <= not carry_out;
        end case;
    end process;

   output : process (all) is
   begin
        pipeline_o.pc <= pipeline_i.pc;
        pipeline_o.imm <= pipeline_i.imm;
        pipeline_o.rs1 <= pipeline_i.rs1;
        pipeline_o.rd <= pipeline_i.rd;
        pipeline_o.rp2_rdata <= rp2_forward_i;
        pipeline_o.operand_b <= operand_b;

        result_sel : case ctrl_i.eu_result_sel is
            when OP_A => pipeline_o.eu_result <= operand_a;
            when ADDER => pipeline_o.eu_result <= adder_result;
            when LOGIC => pipeline_o.eu_result <= logic_unit_result;
            when SHIFTER => pipeline_o.eu_result <= shifter_result;
            when CONDITION => pipeline_o.eu_result <= (0 => selected_condition, others => '0');
            when MULTIPLIER => pipeline_o.eu_result <= mul_result;
            when DIVIDER => pipeline_o.eu_result <= div_result;
        end case;

        pipeline_o.condition <= selected_condition;
   end process;

end architecture;