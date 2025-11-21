--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: XXXX
--  SPDX-FileCopyrightText: 2024, XXXX
--  Description: EISV Top Module for GHDL based simulation, exposes a vhsock on VHSOCK_NAME
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.finish;

library sim;
use sim.vhsock_pkg.all;

library eisv;

entity core_sim is
    generic (
        VHSOCK_NAME : c_string_t;
        HART_ID : integer := 0
    );
end entity;

architecture rtl of core_sim is

    signal clk : std_ulogic;
    signal rst_n : std_ulogic;

    signal imem_addr : std_ulogic_vector(31 downto 0);
    signal imem_ren : std_ulogic;
    signal imem_rdata : std_ulogic_vector(31 downto 0);
    signal dmem_addr : std_ulogic_vector(31 downto 0);
    signal dmem_ren : std_ulogic;
    signal dmem_rdata : std_ulogic_vector(31 downto 0);
    signal dmem_wen : std_ulogic;
    signal dmem_wdata : std_ulogic_vector(31 downto 0);
    signal dmem_byte_enable : std_ulogic_vector(3 downto 0);
    signal external_interrupt_pending : std_ulogic;
    signal timer_interrupt_pending : std_ulogic;

begin

    core_wrapper_inst : entity eisv.eisv_core_wrapper
        generic map (
            HART_ID => HART_ID
        )
        port map(
            clk_i => clk,
            rst_ni => rst_n,
            imem_addr_o => imem_addr,
            imem_ren_o => imem_ren,
            imem_rdata_i => imem_rdata,
            dmem_addr_o => dmem_addr,
            dmem_ren_o => dmem_ren,
            dmem_rdata_i => dmem_rdata,
            dmem_wen_o => dmem_wen,
            dmem_wdata_o => dmem_wdata,
            dmem_byte_enable_o => dmem_byte_enable,
            external_interrupt_pending_i => external_interrupt_pending,
            timer_interrupt_pending_i => timer_interrupt_pending
        );

    clock : process is
    begin
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
    end process;

    vhsock : process is
        variable sock : vhsock_handle_ptr_t;

        variable ob_idx : integer;
        variable ib_idx : integer;

        variable i : integer := 0;
    begin
        sock := vhsock_create;

        sock.name(VHSOCK_NAME'left to VHSOCK_NAME'right) := VHSOCK_NAME;
        sock.name(VHSOCK_NAME'right+1 to 31) := (others => nul);

        -- Memory layout for input and output buffers:
        -- Input: rst_n | imem_rdata | dmem_rdata | external_interrupt_pending | timer_interrupt_pending
        -- Input Length: 1 + 32 + 32 + 1 + 1 = 67
        -- Output: imem_addr | imem_ren | dmem_addr |
        --         dmem_ren | dmem_wen | dmem_wdata
        --         dmem_byte_enable
        -- Output Length: 32 + 1 + 32 + 1 + 1 + 32 + 4 = 103
        sock.in_buffer_size := 67;
        sock.in_buffer := new std_ulogic_vector(sock.in_buffer_size - 1 downto 0);
        sock.out_buffer_size := 103;
        sock.out_buffer := new std_ulogic_vector(sock.out_buffer_size - 1 downto 0);
        vhsock_init(sock.all);

        while true loop
            wait until rising_edge(clk);
            wait for 1 ps;

            -- Receive data for next clock cycle
            vhsock_recv(sock.all);

            -- Copy received data to signals
            ib_idx := sock.in_buffer_size - 1;
            rst_n <= sock.in_buffer(ib_idx);
            ib_idx := ib_idx - 1;
            imem_rdata <= sock.in_buffer(ib_idx downto ib_idx - 31);
            ib_idx := ib_idx - 32;
            dmem_rdata <= sock.in_buffer(ib_idx downto ib_idx - 31);
            ib_idx := ib_idx - 32;
            external_interrupt_pending <= sock.in_buffer(ib_idx);
            ib_idx := ib_idx - 1;
            timer_interrupt_pending <= sock.in_buffer(ib_idx);
            ib_idx := ib_idx - 1;

            assert ib_idx = -1 report "ib_idx" severity failure;

            wait for 1 ps;

            -- Copy current state into out buffer
            ob_idx := sock.out_buffer_size - 1;
            sock.out_buffer(ob_idx downto ob_idx - 31) := imem_addr;
            ob_idx := ob_idx - 32;
            sock.out_buffer(ob_idx) := imem_ren;
            ob_idx := ob_idx - 1;
            sock.out_buffer(ob_idx downto ob_idx - 31) := dmem_addr;
            ob_idx := ob_idx - 32;
            sock.out_buffer(ob_idx) := dmem_ren;
            ob_idx := ob_idx - 1;
            sock.out_buffer(ob_idx) := dmem_wen;
            ob_idx := ob_idx - 1;
            sock.out_buffer(ob_idx downto ob_idx - 31) := dmem_wdata;
            ob_idx := ob_idx - 32;
            sock.out_buffer(ob_idx downto ob_idx - 3) := dmem_byte_enable;
            ob_idx := ob_idx - 4;
            assert ob_idx = -1 report "ob_idx" severity failure;

            -- Send data
            vhsock_send(sock.all);
        end loop;

    end process;

end architecture;