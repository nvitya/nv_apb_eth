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
-- file:     eth_crc_fake.vhd
-- brief:    Some fake CRC calculation for debugging of timings
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_crc_fake is
port
(
  DATA          : in  unsigned(7 downto 0);
  CRC_OUT       : out unsigned(31 downto 0);
  CRC_OUT_NEXT  : out unsigned(31 downto 0);
  ENABLE     	  : in  std_ulogic := '0';
	RESET     	  : in  std_ulogic := '0'; 	-- global reset, low-active, async
	CLK		 			  : in  std_logic
);
end entity;

architecture behavioral of eth_crc_fake
is
	signal CRC      : unsigned(31 downto 0) := X"00000000";
	signal CRC_NEXT : unsigned(31 downto 0);
begin

  CRC_OUT       <= CRC;
  CRC_OUT_NEXT  <= CRC_NEXT;

  CRC_NEXT(31 downto  8) <= CRC(23 downto 0);
  CRC_NEXT( 7 downto  0) <= DATA;

	crc_latch: process (CLK)
	begin
	  if rising_edge(CLK)
	  then
      if RESET = '1'
      then
        CRC <= X"00000000";
      --
      elsif ENABLE = '1'
      then
        CRC <= CRC_NEXT;
      end if;
	  end if;
	end process;

end architecture;
