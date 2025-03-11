--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  Description: EISV Core instruction fetch stage
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_if_stage is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        -- IMEM interface
        instr_addr_o : out mem_addr_t;
        instr_ren_o : out std_ulogic;
        -- Control signals from core
        hold_pc_i : in std_ulogic;
        jump_en_i : in std_ulogic;
        condition_i : in std_ulogic;
        jump_addr_i : in mem_addr_t;

        -- Pipeline in
        pipeline_i : in if_pipeline_t;
        -- Pipeline out
        pipeline_o : out if_pipeline_t
    );
end entity;

architecture rtl of eisv_if_stage is

    signal instr_addr : mem_addr_t;

begin

    -- Combinational Logic
    pc_control : process (all) is
    begin
        instr_addr <= mem_addr_t((unsigned(pipeline_i.pc) + 4));

        if hold_pc_i then
            instr_addr <= pipeline_i.pc;
        end if;

        if jump_en_i then
            if condition_i then
                instr_addr <= mem_addr_t(unsigned(jump_addr_i));
            else
                instr_addr <= mem_addr_t((unsigned(pipeline_i.pc) + 4));
            end if;
        end if;
    end process;

    -- Output

    instr_addr_o <= instr_addr;
    instr_ren_o <= '1';
    pipeline_o.pc <= instr_addr;

end architecture;