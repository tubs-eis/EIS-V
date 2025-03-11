--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: EISV Controller FSM
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_controller is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        trap_i : in std_ulogic;
        trap_return_i : in std_ulogic;
        trap_cause_i : in trap_cause_t;
        flushed_i : in std_ulogic;
        flushing_o : out std_ulogic;
        jump_trap_handler_o : out std_ulogic;
        jump_trap_return_o : out std_ulogic;
        trap_cause_o : out trap_cause_t
    );
end entity;

architecture rtl of eisv_controller is

    type fsm_t is (EXECUTE, TRAP_FLUSH, TRAP_RETURN_FLUSH);

    signal fsm_ff, fsm_nxt : fsm_t;
    signal trap_cause_ff, trap_cause_nxt : trap_cause_t;

begin

    seq : process (clk_i) is
    begin
        if (rising_edge(clk_i)) then
            if rst_ni then
                fsm_ff <= fsm_nxt;
                trap_cause_ff <= trap_cause_nxt;
            else
                fsm_ff <= EXECUTE;
            end if;
        end if;
    end process;

    control : process (all) is
    begin
        fsm_nxt <= fsm_ff;
        trap_cause_nxt <= trap_cause_ff;

        jump_trap_handler_o <= '0';
        jump_trap_return_o <= '0';
        flushing_o <= '0';

        case fsm_ff is
            when EXECUTE =>
                if trap_return_i then
                    fsm_nxt <= TRAP_RETURN_FLUSH;
                end if;
                if trap_i then
                    fsm_nxt <= TRAP_FLUSH;
                    trap_cause_nxt <= trap_cause_i;
                end if;
            when TRAP_FLUSH =>
                flushing_o <= '1';
                if flushed_i then
                    flushing_o <= '0';
                    fsm_nxt <= EXECUTE;
                    jump_trap_handler_o <= '1';
                end if;
            when TRAP_RETURN_FLUSH =>
                flushing_o <= '1';
                if flushed_i then
                    flushing_o <= '0';
                    fsm_nxt <= EXECUTE;
                    jump_trap_return_o <= '1';
                end if;
        end case;
    end process;

    trap_cause_o <= trap_cause_ff;

end architecture;
