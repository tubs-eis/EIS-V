--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: Non-Restoring Divider
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;
use eisv.eisv_config_pkg.all;

entity eisv_div is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        enable_i : in std_ulogic;
        op_a_i : in word_t;
        op_b_i : in word_t;
        div_mode_i : in div_mode_t;

        result_o : out word_t
    );
end entity;

architecture rtl of eisv_div is

    type division_matrix is array (31 downto 0) of word_t;

    signal dividend : std_ulogic_vector(62 downto 0);
    signal divisor : word_t;
    signal quotient : word_t;
    signal remainder : word_t;
    signal corrected_remainder : word_t;

    signal cas_d_in : division_matrix;
    signal cas_q_in : division_matrix;
    signal cas_p_in : division_matrix;
    signal cas_r_in : division_matrix;
    signal cas_d_out : division_matrix;
    signal cas_q_out : division_matrix;
    signal cas_r_out : division_matrix;

    signal overflow : std_ulogic;
    signal is_signed : std_ulogic;

begin

    generate_divider : if eisv_cfg.isa_enable_M_c generate
        correction : process (all) is
        begin
            if remainder(31) then
                corrected_remainder <= word_t(unsigned(remainder) + unsigned(divisor));
            else
                corrected_remainder <= remainder;
            end if;
        end process;

        output : process (all) is
            variable result_quotient : word_t;
            variable result_remainder : word_t;
        begin
            result_quotient := quotient;
            result_remainder := corrected_remainder;

            if (??is_signed) and op_a_i(31) /= op_b_i(31) then
                result_quotient := word_t(-signed(result_quotient));
            end if;

            if is_signed and op_a_i(31) then
                result_remainder := word_t(-signed(result_remainder));
            end if;

            if overflow then
                result_quotient := (others => '0');
                result_remainder := op_a_i;
            end if;

            case (div_mode_i) is
                when DIVU | DIV => result_o <= result_quotient;
                when REMS | REMU => result_o <= result_remainder;
            end case;
        end process;

        input : process (all) is
            variable op_a_signed : signed(31 downto 0);
            variable op_a_unsigned : unsigned(31 downto 0);
            variable op_a_abs : unsigned(31 downto 0);
            variable op_b_signed : signed(31 downto 0);
            variable op_b_unsigned : unsigned(31 downto 0);
            variable op_b_abs : unsigned(31 downto 0);
        begin
            case (div_mode_i) is
                when DIVU | REMU => is_signed <= '0';
                when DIV | REMS => is_signed <= '1';
            end case;

            op_a_signed := signed(op_a_i);
            op_a_unsigned := unsigned(op_a_i);
            if (??is_signed) and op_a_signed < 0 then
                op_a_abs := unsigned(-op_a_signed);
            else
                op_a_abs := op_a_unsigned;
            end if;

            op_b_signed := signed(op_b_i);
            op_b_unsigned := unsigned(op_b_i);
            if (??is_signed) and op_b_signed < 0 then
                op_b_abs := unsigned(-op_b_signed);
            else
                op_b_abs := op_b_unsigned;
            end if;

            overflow <= '0';
            if op_b_abs > op_a_abs then
                overflow <= '1';
            end if;

            case (div_mode_i) is
                when DIVU | REMU =>
                    dividend <= std_ulogic_vector(resize(op_a_unsigned, 63));
                    divisor <= word_t(op_b_unsigned);
                when DIV | REMS =>
                    dividend <= std_ulogic_vector(resize(op_a_abs, 63));
                    divisor <= word_t(op_b_abs);
            end case;
        end process;

        cas_p_in(0) <= (others => '1');
        cas_q_in(0)(0) <= '1';

        cas_r_in(0)(31 downto 0) <= word_t(dividend(62 downto 31));
        cas_d_in(0) <= divisor;

        remainder <= cas_r_out(31);

        cas_row : for y in 0 to 31 generate
            connect_rows : if y > 0 generate
                cas_d_in(y) <= cas_d_out(y - 1);
                cas_q_in(y)(0) <= cas_q_out(y - 1)(31);
            end generate;

            quotient(y) <= cas_q_out(31 - y)(31);

            cas_cell : for x in 0 to 31 generate
                connect_rows_p : if y > 0 generate
                    cas_p_in(y)(x) <= cas_q_out(y - 1)(31);
                end generate;

                connect_columns : if x > 0 generate
                    cas_q_in(y)(x) <= cas_q_out(y)(x - 1);
                end generate;

                connect_r : if y > 0 and x > 0 generate
                    cas_r_in(y)(x) <= cas_r_out(y - 1)(x - 1);
                elsif y > 0 generate
                    cas_r_in(y)(x) <= dividend(dividend'high - 31 - y);
                end generate;

                cas : block is
                    signal a, b, s, c_in, c_out : std_ulogic;
                begin
                    a <= cas_d_in(y)(x) xor cas_p_in(y)(x);
                    b <= cas_r_in(y)(x);
                    c_in <= cas_q_in(y)(x);

                    s <= a xor b xor c_in;
                    c_out <= (a and b) or (c_in and (a xor b));

                    cas_d_out(y)(x) <= cas_d_in(y)(x);
                    cas_q_out(y)(x) <= c_out;
                    cas_r_out(y)(x) <= s;
                end block;
            end generate;
        end generate;
    end generate;
end architecture;
