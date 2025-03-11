--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: BRAM inferrring RAM with 2 read and 2 write ports
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library fpga;

entity arty_memory is
    generic (
        DATA_WIDTH : integer := 32;
        ADDR_WIDTH : integer := 6
    );
    port (
        clk_i : in std_ulogic;
        port_a_we_i : in std_ulogic;
        port_a_addr_i : in std_ulogic_vector(ADDR_WIDTH-1 downto 0);
        port_a_wdata_i : in std_ulogic_vector(DATA_WIDTH-1 downto 0);
        port_a_rdata_o : out std_ulogic_vector(DATA_WIDTH-1 downto 0);
        port_b_we_i : in std_ulogic;
        port_b_be_i : in std_ulogic_vector(3 downto 0);
        port_b_addr_i : in std_ulogic_vector(ADDR_WIDTH-1 downto 0);
        port_b_wdata_i : in std_ulogic_vector(DATA_WIDTH-1 downto 0);
        port_b_rdata_o : out std_ulogic_vector(DATA_WIDTH-1 downto 0)
    );
end entity;

architecture rtl of arty_memory is
    type ram is array (0 to (2**ADDR_WIDTH)-1) of std_ulogic_vector(DATA_WIDTH-1 downto 0);
    signal memory : ram := (others => (others => '0')); -- Initial values for simulation

begin

    port_a : process(clk_i) is
    begin
        if rising_edge(clk_i) then
            if port_a_we_i then
                -- memory(to_integer(unsigned(port_a_addr_i))) <= port_a_wdata_i;
            else
                port_a_rdata_o <= memory(to_integer(unsigned(port_a_addr_i)));
            end if;
        end if;
    end process;

    port_b : process(clk_i) is
    begin
        if rising_edge(clk_i) then
            if port_b_we_i then
                for i in 3 downto 0 loop
                    if port_b_be_i(i) then
                        memory(to_integer(unsigned(port_b_addr_i)))((i+1)*8-1 downto i*8) <= port_b_wdata_i((i+1)*8-1 downto i*8);
                    end if;
                end loop;
            else
                port_b_rdata_o <= memory(to_integer(unsigned(port_b_addr_i)));
            end if;
        end if;
    end process;
end architecture;