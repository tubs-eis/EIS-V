import sys

rom_contents = {}

indent = 12


program_data = []
with open(sys.argv[1], "rb") as program_file:
    while True:
        bytes_ = program_file.read(4)
        if len(bytes_) != 4:
            break
        program_data.append(int.from_bytes(bytes_, byteorder="little"))

entity_name = sys.argv[2]

cases = ""
address = 0
for instruction in program_data:
    cases += f'{12*" "}{address:04} => x"{instruction:08X}",\n'
    address += 1

vhdl = f"""\
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library fpga;

entity {entity_name} is
    port (
        clk_i : in std_ulogic;
        port_a_addr_i : in std_ulogic_vector(31 downto 0);
        port_a_data_o : out std_ulogic_vector(31 downto 0);
        port_b_addr_i : in std_ulogic_vector(31 downto 0);
        port_b_data_o : out std_ulogic_vector(31 downto 0)
    );
end entity;

architecture rtl of {entity_name} is

    type rom_t is array (0 to 2**10) of std_ulogic_vector(31 downto 0);

    constant ROM : rom_t := (
{cases}
            others => x"00000013"
    );

begin

    seq : process (clk_i) is
    begin
        if rising_edge(clk_i) then
            port_a_data_o <= ROM(to_integer(unsigned(port_a_addr_i(31 downto 2))));
            port_b_data_o <= ROM(to_integer(unsigned(port_b_addr_i(31 downto 2))));
        end if;
    end process;

end architecture;
"""
print(vhdl)
