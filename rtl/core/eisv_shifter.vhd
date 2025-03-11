--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: 32 bit shifter
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_shifter is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        data_i : in word_t;
        shamt_i : in shamt_t;
        shift_mode_i : in shift_mode_t;
        result_o : out word_t
    );
end entity;

architecture rtl of eisv_shifter is

    function shift(
        input: word_t;
        shamt: shamt_t;
        mode: shift_mode_t)
    return word_t is
        variable shamt_int : integer;
    begin
        shamt_int := to_integer(unsigned(shamt));
        case mode is
            when LEFT =>
                return word_t(shift_left(unsigned(input), shamt_int));
            when RIGHT_LOGICAL =>
                return word_t(shift_right(unsigned(input), shamt_int));
            when RIGHT_ARITHMETIC =>
                return word_t(shift_right(signed(input), shamt_int));
        end case;
    end function;

begin

    result_o <= shift(data_i, shamt_i, shift_mode_i);

end architecture;
