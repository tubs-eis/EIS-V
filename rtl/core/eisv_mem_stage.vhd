--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: XXXX
--  SPDX-FileCopyrightText: 2024, XXXX
--  Description: EISV Core memory stage
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisv_types_pkg.all;

entity eisv_mem_stage is
    port (
        clk_i : in std_ulogic;
        rst_ni : in std_ulogic;
        -- CTRL and Pipeline
        ctrl_i : in control_word_t;
        pipeline_i : in ex_pipeline_t;
        pipeline_o : out mem_pipeline_t
    );
end entity;

architecture rtl of eisv_mem_stage is

begin

    pipeline_o.pc <= pipeline_i.pc;
    pipeline_o.rs1 <= pipeline_i.rs1;
    pipeline_o.rd <= pipeline_i.rd;
    pipeline_o.rp2_rdata <= pipeline_i.rp2_rdata;
    pipeline_o.operand_b <= pipeline_i.operand_b;
    pipeline_o.eu_result <= pipeline_i.eu_result;
    pipeline_o.condition <= pipeline_i.condition;

end architecture;
