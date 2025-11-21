--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: XXXX
--  SPDX-FileCopyrightText: 2024, XXXX
--  Description: Multiplier with optional Pipelining
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;
use eisv.eisv_config_pkg.all;

entity eisv_mul is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        enable_i : in std_ulogic;
        op_a_i : in word_t;
        op_b_i : in word_t;
        mul_mode_i : in mul_mode_t;

        result_o : out word_t;
        valid_o : out std_ulogic
    );
end entity;

architecture rtl of eisv_mul is

    signal mul_result : mul_result_t;

    constant MUL_DELAY : natural := 0;
    type mul_pipeline_t is array (MUL_DELAY downto 0) of word_t;

    signal mul_pipeline_ff, mul_pipeline_nxt : mul_pipeline_t;
    signal mul_pipeline_valid_ff, mul_pipeline_valid_nxt : std_ulogic_vector(MUL_DELAY downto 0);
begin

    generate_multiplier : if eisv_cfg.isa_enable_M_c generate
        multiply : process (all) is
            variable op_a_signed : signed(63 downto 0);
            variable op_a_unsigned : unsigned(63 downto 0);
            variable op_b_signed : signed(63 downto 0);
            variable op_b_unsigned : unsigned(63 downto 0);
        begin
            op_a_signed := resize(signed(op_a_i), 64);
            op_a_unsigned := resize(unsigned(op_a_i), 64);

            op_b_signed := resize(signed(op_b_i), 64);
            op_b_unsigned := resize(unsigned(op_b_i), 64);

            case (mul_mode_i) is
                when MULHU => mul_result <= mul_result_t(resize(op_a_unsigned * op_b_unsigned, 64));
                when MULHSU => mul_result <= mul_result_t(resize(op_a_signed * signed(op_b_unsigned), 64));
                when MUL | MULH => mul_result <= mul_result_t(resize(op_a_signed * op_b_signed, 64));
            end case;

            if (mul_mode_i = MUL) then
                mul_pipeline_nxt(0) <= word_t(mul_result(31 downto 0));
            else
                mul_pipeline_nxt(0) <= word_t(mul_result(63 downto 32));
            end if;
        end process;

        mul_pipeline_valid_nxt(0) <= enable_i;

        generate_pipeline : if MUL_DELAY > 0 generate
            mul_pipeline_nxt(MUL_DELAY downto 1) <= mul_pipeline_ff(MUL_DELAY-1 downto 0);
            mul_pipeline_valid_nxt(MUL_DELAY downto 1) <= mul_pipeline_valid_ff(MUL_DELAY-1 downto 0);

            pipeline : process (clk_i) is
            begin
                if rising_edge(clk_i) then
                    if (rst_ni) then
                        mul_pipeline_ff <= mul_pipeline_nxt;
                        mul_pipeline_valid_ff <= mul_pipeline_valid_nxt;
                    else
                        mul_pipeline_valid_ff <= (others => '0');
                    end if;
                end if;
            end process;
        end generate;

        result_o <= mul_pipeline_nxt(MUL_DELAY);
        valid_o <= mul_pipeline_valid_nxt(MUL_DELAY);
    end generate;

end architecture;