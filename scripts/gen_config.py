import os

vhdl = f"""\
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;

package eisv_config is
    constant EISV_CONFIG_C : std_ulogic_vector(0 downto 0) := "{os.environ['EISV_CONFIG']}";
end package;

package body eisv_config is
end package body;
"""
print(vhdl)
