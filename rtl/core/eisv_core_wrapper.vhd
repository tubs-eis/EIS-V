--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: EISV Core wrapper using plain ulogic signals
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_core_wrapper is
    generic (
        HART_ID : integer := 0
    );
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        imem_addr_o : out std_ulogic_vector(31 downto 0);
        imem_ren_o : out std_ulogic;
        imem_rdata_i : in std_ulogic_vector(31 downto 0);
        dmem_addr_o : out std_ulogic_vector(31 downto 0);
        dmem_ren_o : out std_ulogic;
        dmem_rdata_i : in std_ulogic_vector(31 downto 0);
        dmem_wen_o : out std_ulogic;
        dmem_wdata_o : out std_ulogic_vector(31 downto 0);
        dmem_byte_enable_o : out std_ulogic_vector(3 downto 0);
        external_interrupt_pending_i : in std_ulogic;
        timer_interrupt_pending_i : in std_ulogic
    );
end entity;

architecture rtl of eisv_core_wrapper is

    signal imem_addr : mem_addr_t;
    signal dmem_addr : mem_addr_t;
    signal dmem_wdata : word_t;
    signal dmem_byte_enable : byte_flag_t;

begin

    core_inst : entity eisv.eisv_core
     generic map (
        HART_ID => HART_ID
     )
     port map(
        clk_i => clk_i,
        rst_ni => rst_ni,
        imem_addr_o => imem_addr,
        imem_ren_o => imem_ren_o,
        imem_rdata_i => word_t(imem_rdata_i),
        dmem_addr_o => dmem_addr,
        dmem_ren_o => dmem_ren_o,
        dmem_rdata_i => word_t(dmem_rdata_i),
        dmem_wen_o => dmem_wen_o,
        dmem_wdata_o => dmem_wdata,
        dmem_byte_enable_o => dmem_byte_enable,
        external_interrupt_pending_i => external_interrupt_pending_i,
        timer_interrupt_pending_i => timer_interrupt_pending_i
    );

    imem_addr_o <= std_ulogic_vector(imem_addr);
    dmem_addr_o <= std_ulogic_vector(dmem_addr);
    dmem_wdata_o <= std_ulogic_vector(dmem_wdata);
    dmem_byte_enable_o <= std_ulogic_vector(dmem_byte_enable);

end architecture;