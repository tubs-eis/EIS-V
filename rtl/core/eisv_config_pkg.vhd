--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: XXXX
--  SPDX-FileCopyrightText: 2024, XXXX
--  Description: EISV Configuration

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;

package eisv_config_pkg is
    -- Configuration
    constant CFG_NUM_C : integer := 1;

    -- Unpacked config
    type eisV_cfg_t is record
        -- ISA Configuration
        isa_enable_M_c : std_ulogic;
    end record;
    -- eisV_cfg_v.isa_enable_M_c := config(0); -- '1' -- ACTIVE

    function eisv_unpack_cfg_f (constant config : std_ulogic_vector(CFG_NUM_C-1 downto 0)) return eisV_cfg_t;

end package;

package body eisv_config_pkg is

    function eisv_unpack_cfg_f (constant config : std_ulogic_vector(CFG_NUM_C-1 downto 0))
    return eisV_cfg_t is
        variable eisV_cfg_v : eisV_cfg_t;
    begin
        -- IF Stage Configuration
        eisV_cfg_v.isa_enable_M_c := config(0);

        return eisV_cfg_v;
    end function;

end package body;
