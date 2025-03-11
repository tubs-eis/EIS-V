--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: RISCV (RV32I) register file
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_register_file is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        -- Read Port1
        rp1_addr_i : in rf_addr_t;
        rp1_enable_i : in std_ulogic;
        rp1_data_o : out word_t;
        -- Read Port2
        rp2_addr_i : in rf_addr_t;
        rp2_enable_i : in std_ulogic;
        rp2_data_o : out word_t;
        -- Write Port1
        wp1_addr_i : in rf_addr_t;
        wp1_enable_i : in std_ulogic;
        wp1_data_i : in word_t;
        -- Write Port2 (CSR)
        wp2_addr_i : in rf_addr_t;
        wp2_enable_i : in std_ulogic;
        wp2_data_i : in word_t
    );
end entity;

architecture rtl of eisv_register_file is

    type registers_t is array (1 to 31) of word_t;
    signal registers_reg : registers_t;

    signal rp1_data_reg : word_t;
    signal rp2_data_reg : word_t;

begin

    seq : process (clk_i) is
    begin
        if rising_edge(clk_i) then
            rp1_data_reg <= (others => '0');
            rp2_data_reg <= (others => '0');
            if rst_ni then
                if (??rp1_enable_i) and unsigned(rp1_addr_i) /= 0 then
                    rp1_data_reg <= registers_reg(to_integer(unsigned(rp1_addr_i)));
                end if;

                if (??rp2_enable_i) and unsigned(rp2_addr_i) /= 0 then
                    rp2_data_reg <= registers_reg(to_integer(unsigned(rp2_addr_i)));
                end if;

                if (??wp1_enable_i) and unsigned(wp1_addr_i) /= 0 then
                    registers_reg(to_integer(unsigned(wp1_addr_i))) <= wp1_data_i;
                end if;

                if (??wp2_enable_i) and unsigned(wp2_addr_i) /= 0 then
                    registers_reg(to_integer(unsigned(wp2_addr_i))) <= wp2_data_i;
                end if;
            end if;
        end if;
    end process;

    rp1_data_o <= rp1_data_reg;
    rp2_data_o <= rp2_data_reg;

end architecture;