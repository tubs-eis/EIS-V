--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: Top Module for EISV on Gatemate
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

library fpga;

entity gatemate_top is
    port (
        clk_i : in std_logic;
        rst_ni : in std_logic;
        led_o : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of gatemate_top is

    component CC_PLL is
        generic (
            REF_CLK         : string;  -- reference input in MHz
            OUT_CLK         : string;  -- pll output frequency in MHz
            PERF_MD         : string;  -- LOWPOWER, ECONOMY, SPEED
            LOW_JITTER      : integer; -- 0: disable, 1: enable low jitter mode
            CI_FILTER_CONST : integer; -- optional CI filter constant
            CP_FILTER_CONST : integer  -- optional CP filter constant
        );
        port (
            CLK_REF             : in  std_logic;
            USR_CLK_REF         : in  std_logic;
            CLK_FEEDBACK        : in  std_logic;
            USR_LOCKED_STDY_RST : in  std_logic;
            USR_PLL_LOCKED_STDY : out std_logic;
            USR_PLL_LOCKED      : out std_logic;
            CLK0                : out std_logic;
            CLK90               : out std_logic;
            CLK180              : out std_logic;
            CLK270              : out std_logic;
            CLK_REF_OUT         : out std_logic
        );
        end component;

    signal instr_addr : std_ulogic_vector(31 downto 0);
    signal instr_ren : std_ulogic;
    signal instr_rdata : std_ulogic_vector(31 downto 0);

    signal data_wen : std_ulogic;
    signal data_ren : std_ulogic;
    signal data_be : std_ulogic_vector(3 downto 0);
    signal data_addr : std_ulogic_vector(31 downto 0);
    signal data_wdata : std_ulogic_vector(31 downto 0);
    signal data_rdata : std_ulogic_vector(31 downto 0);

    signal led_ff, led_nxt : std_ulogic_vector(7 downto 0);

    signal reset_n_ff : std_ulogic;

    signal clock : std_ulogic;

begin

    pll_inst : CC_PLL
    generic map (
        REF_CLK         => "10.0",
        OUT_CLK         => "10.0",
        PERF_MD         => "",
        LOW_JITTER      => 1,
        CI_FILTER_CONST => 2,
        CP_FILTER_CONST => 4
    )
    port map (
        CLK_REF             => clk_i,
        USR_CLK_REF         => '0',
        CLK_FEEDBACK        => '0',
        USR_LOCKED_STDY_RST => '0',
        USR_PLL_LOCKED_STDY => open,
        USR_PLL_LOCKED      => open,
        CLK0                => clock,
        CLK90               => open,
        CLK180              => open,
        CLK270              => open,
        CLK_REF_OUT         => open
    );

    seq : process (clock) is
    begin
        if rising_edge(clock) then
            if reset_n_ff then
                led_ff <= led_nxt;
            else
                led_ff <= (others => '0');
            end if;
        end if;
    end process;

    button_debounce : block is
        signal counter_reg : unsigned(10 downto 0);
        signal reset_n_nxt : std_ulogic;
    begin
        process (clock) is
        begin
            if rising_edge(clock) then
                counter_reg <= counter_reg + 1;
                reset_n_ff <= reset_n_nxt;
            end if;
        end process;

        process (all) is begin
            reset_n_nxt <= reset_n_ff;
            if (or counter_reg) = '0' then
                reset_n_nxt <= rst_ni;
            end if;
        end process;

    end block;

    core_wrapper_inst: entity eisv.eisv_core_wrapper
     port map(
        clk_i => clock,
        rst_ni => reset_n_ff,
        imem_addr_o => instr_addr,
        imem_ren_o => instr_ren,
        imem_rdata_i => instr_rdata,
        dmem_addr_o => data_addr,
        dmem_ren_o => data_ren,
        dmem_rdata_i => data_rdata,
        dmem_wen_o => data_wen,
        dmem_wdata_o => data_wdata,
        dmem_byte_enable_o => data_be,
        external_interrupt_pending_i => '0',
        timer_interrupt_pending_i => '0'
    );

    memory_i : entity fpga.gatemate_memory
        generic map (
            DATA_WIDTH => 32,
            ADDR_WIDTH => 10
        )
        port map (
            clk_i => clock,
            port_a_we_i => '0',
            port_a_addr_i => instr_addr(9 downto 0),
            port_a_wdata_i => (others => '0'),
            port_a_rdata_o => open,
            port_b_we_i => data_wen,
            port_b_addr_i => data_addr(9 downto 0),
            port_b_wdata_i => data_wdata,
            port_b_rdata_o => data_rdata
        );

    rom_i : entity fpga.gatemate_rom
        port map (
            clk_i => clock,
            port_a_addr_i => instr_addr,
            port_a_data_o => instr_rdata,
            port_b_addr_i => (others => '0'),
            port_b_data_o => open
        );

    led_write : process (all) is
    begin
        led_nxt <= led_ff;
        if (??data_wen) and unsigned(data_addr) = x"80000000" then
            led_nxt <= data_wdata(7 downto 0);
        end if;
    end process;

    led_o <= led_ff;

end architecture;