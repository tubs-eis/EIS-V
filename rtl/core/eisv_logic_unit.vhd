--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: basic logic unit (XOR, OR, AND) with zero detection
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_logic_unit is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        op_a_i : in word_t;
        op_b_i : in word_t;
        logic_op_i : in logic_op_t;
        result_o : out word_t;
        zero_o : out std_ulogic
    );
end entity;

architecture rtl of eisv_logic_unit is

begin

    process (all) is
        variable result : word_t;
    begin
        case (logic_op_i) is
            when '^' => result := word_t(std_ulogic_vector(op_a_i) xor std_ulogic_vector(op_b_i));
            when '|' => result := word_t(std_ulogic_vector(op_a_i) or  std_ulogic_vector(op_b_i));
            when '&' => result := word_t(std_ulogic_vector(op_a_i) and std_ulogic_vector(op_b_i));
            when CLEAR => result := word_t(not std_ulogic_vector(op_a_i) and std_ulogic_vector(op_b_i));
        end case;

        result_o <= result;
        zero_o <= nor std_ulogic_vector(result);
    end process;

end architecture;
