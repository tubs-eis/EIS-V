--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: EISV Core load store unit
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_load_store_unit is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        -- Memory interface
        data_addr_o : out mem_addr_t;
        data_ren_o : out std_ulogic;
        data_rdata_i : in word_t;
        data_wen_o : out std_ulogic;
        data_wdata_o : out word_t;
        data_byte_enable_o : out byte_flag_t;

        -- MEM Stage Interface (Access)
        acc_enable_i : in std_ulogic;
        acc_store_i : in std_ulogic;
        acc_address_i : in mem_addr_t;
        acc_width_i : in memory_width_t;
        acc_data_i : in word_t;
        acc_misaligned_o : out std_ulogic;

        -- WB Stage Interface (Resolution)
        res_enable_i : in std_ulogic;
        res_width_i : in memory_width_t;
        res_byte_addr_i : in std_ulogic_vector(1 downto 0);
        res_is_unsigned : in std_ulogic;
        res_data_o : out word_t
    );
end entity;

architecture rtl of eisv_load_store_unit is

    function gen_byte_enable(
        width : memory_width_t;
        byte_addr : std_ulogic_vector(1 downto 0)
    ) return byte_flag_t is
        variable rv : byte_flag_t;
        variable shamt : integer;
    begin
        rv := (others => '0');
        case width is
            when WORD => rv := "1111";
            when HALF => rv := "0011";
            when BYTE => rv := "0001";
        end case;

        shamt := to_integer(unsigned(byte_addr));
        rv := byte_flag_t(shift_left(unsigned(rv), shamt));

        return rv;
    end function;

    function reg_to_mem(
        reg_data : word_t;
        byte_addr : std_ulogic_vector(1 downto 0)
    ) return word_t is
        variable rv : word_t;
        variable shamt : integer;
    begin
        shamt := to_integer(unsigned(byte_addr)) * 8;
        rv := word_t(shift_left(unsigned(reg_data), shamt));

        return rv;
    end function;

    function mem_to_reg(
        mem_data : word_t;
        width : memory_width_t;
        byte_addr : std_ulogic_vector(1 downto 0);
        is_unsigned : std_ulogic
    ) return word_t is
        variable rv : word_t;
        variable shamt : integer;
        variable extend_bit : std_ulogic;
    begin
        shamt := to_integer(unsigned(byte_addr)) * 8;
        rv := word_t(shift_right(unsigned(mem_data), shamt));

        if is_unsigned then
            extend_bit := '0';
        else
            case width is
                when WORD => extend_bit := rv(31);
                when HALF => extend_bit := rv(15);
                when BYTE => extend_bit := rv(7);
            end case;
        end if;

        case width is
            when WORD => null;
            when HALF => rv(31 downto 16) := (others => extend_bit);
            when BYTE => rv(31 downto 8) := (others => extend_bit);
        end case;

        return rv;
    end function;

begin

    mem_access : process (all) is
        variable misaligned : std_ulogic;
    begin
        data_addr_o <= (others => '0');
        data_byte_enable_o <= (others => '0');
        data_ren_o <= '0';
        data_wen_o <= '0';
        data_wdata_o <= (others => '0');

        acc_misaligned_o <= '0';

        if acc_enable_i then
            case acc_width_i is
                when BYTE => misaligned := '0';
                when HALF => misaligned := acc_address_i(0);
                when WORD => misaligned := acc_address_i(0) or acc_address_i(1);
            end case;
            acc_misaligned_o <= misaligned;

            if not misaligned then
                data_addr_o(31 downto 2) <= acc_address_i(31 downto 2);
                data_byte_enable_o <= gen_byte_enable(acc_width_i, std_ulogic_vector(acc_address_i(1 downto 0)));

                if acc_store_i then
                    data_wen_o <= '1';
                    data_wdata_o <= reg_to_mem(acc_data_i, std_ulogic_vector(acc_address_i(1 downto 0)));
                else
                    data_ren_o <= '1';
                end if;
            end if;
        end if;
    end process;

    load : process (all) is
    begin
        res_data_o <= (others => '0');
        if res_enable_i then
            res_data_o <= mem_to_reg(data_rdata_i, res_width_i, res_byte_addr_i, res_is_unsigned);
        end if;
    end process;

end architecture;