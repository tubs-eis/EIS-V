--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: Simple adder/subtractor with signed compare
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_adder is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        op_a_i : in word_t;
        op_b_i : in word_t;
        addsub_i : in std_ulogic;
        set_lsb_zero : in std_ulogic;
        result_o : out word_t;
        carry_out_o : out std_ulogic;
        less_o : out std_ulogic
    );
end entity;

architecture rtl of eisv_adder is

    signal op_b : unsigned(31 downto 0);
    signal carry_in : std_ulogic;

begin

    carry_in <= addsub_i;

    op_b_sel : process (all) is
    begin
        if addsub_i then
            op_b <= not unsigned(op_b_i);
        else
            op_b <= unsigned(op_b_i);
        end if;
    end process;

    add : process (all) is
        variable wide_op_a : unsigned(32 downto 0);
        variable wide_op_b : unsigned(32 downto 0);
        variable wide_result : unsigned(32 downto 0);
    begin
        wide_op_a := unsigned('0' & unsigned(op_a_i));
        wide_op_b := unsigned('0' & op_b);
        wide_result := wide_op_a + wide_op_b + (0 => carry_in);

        wide_result(0) := wide_result(0) and (not set_lsb_zero);

        result_o <= word_t(wide_result(31 downto 0));
        carry_out_o <= wide_result(32);
        less_o <= wide_op_a(31) xor wide_op_b(31) xor wide_result(32);
    end process;

end architecture;