-------------------------------------------------------------------------------
-- This file is a part of the nv_apb_eth project at https://github.com/nvitya/nv_apb_eth
-- Copyright (c) 2024 Viktor Nagy, nvitya
--
-- This software is provided 'as-is', without any express or implied warranty.
-- In no event will the authors be held liable for any damages arising from
-- the use of this software. Permission is granted to anyone to use this
-- software for any purpose, including commercial applications, and to alter
-- it and redistribute it freely, subject to the following restrictions:
--
-- 1. The origin of this software must not be misrepresented; you must not
--    claim that you wrote the original software. If you use this software in
--    a product, an acknowledgment in the product documentation would be
--    appreciated but is not required.
--
-- 2. Altered source versions must be plainly marked as such, and must not be
--    misrepresented as being the original software.
--
-- 3. This notice may not be removed or altered from any source distribution.
-----------------------------------------------------------------------------
-- file:     ddr_gereric.vhd
-- brief:    DDR blocks using generic code, usually does not work with gigabit
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ddr_input is
generic
(
  DATA_WIDTH : natural
);
port
(
  DATA_IN    : in  unsigned(DATA_WIDTH - 1 downto 0);
  DATA_OUT_R : out unsigned(DATA_WIDTH - 1 downto 0);
  DATA_OUT_F : out unsigned(DATA_WIDTH - 1 downto 0);  -- one clock delayed !
  CLOCK      : in  std_logic
);
end entity;

architecture rtl of ddr_input
is
  signal DCAP_F : unsigned(3 downto 0);  -- captured falling edge data
begin
  proc_ddri : process(CLOCK)
  begin
    if rising_edge(CLOCK)
    then
      DATA_OUT_R <= DATA_IN; -- rising edge data, one clock delayed
      DATA_OUT_F <= DCAP_F;  -- falling edge data, two clocks (1.5) delayed
    end if;

    if falling_edge(CLOCK)
    then
      DCAP_F <= DATA_IN;  -- capture falling edge data
    end if;
  end process;

end architecture;

-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ddr_output is
generic
(
  DATA_WIDTH : natural
);
port
(
  DATA_IN_R  : in  unsigned(DATA_WIDTH - 1 downto 0);  -- rising edge data
  DATA_IN_F  : in  unsigned(DATA_WIDTH - 1 downto 0);  -- falling edge data
  DATA_OUT   : out unsigned(DATA_WIDTH - 1 downto 0);
  CLOCK      : in  std_logic
);
end entity;

architecture rtl of ddr_output
is
  signal DATA_R_Q : unsigned(DATA_WIDTH - 1 downto 0);
  signal DATA_F_Q : unsigned(DATA_WIDTH - 1 downto 0);
begin

  DATA_OUT <= DATA_R_Q when CLOCK = '1' else DATA_F_Q;

  proc_ddro : process(CLOCK)
  begin
    if rising_edge(CLOCK)
    then
      DATA_R_Q <= DATA_IN_R;
      DATA_F_Q <= DATA_IN_F;
    end if;
  end process;

end architecture;