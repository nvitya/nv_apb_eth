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
-- file:     eth_crc.vhd
-- brief:    Real Ethernet CRC calculation
--   calculated the same way, as published by Peter A Bennett here:
--   https://github.com/pabennett/ethernet_mac/blob/master/source/CRC.vhd
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_crc is
port
(
  DATA          : in  unsigned(7 downto 0);
  CRC_OUT       : out unsigned(31 downto 0);
  CRC_OUT_NEXT  : out unsigned(31 downto 0);
  ENABLE     	  : in  std_ulogic := '0';
	RESET     	  : in  std_ulogic := '0';
	CLK		 			  : in  std_logic
);
end entity;

architecture behavioral of eth_crc
is
	signal CRC      : unsigned(31 downto 0) := X"FFFFFFFF";
	signal CRC_NEXT : unsigned(31 downto 0);
	signal DREV     : unsigned(7 downto 0);

  function reversed(slv: unsigned) return unsigned is
      variable result: unsigned(slv'reverse_range);
  begin
      for i in slv'range loop
          result(i) := slv(i);
      end loop;
      return result;
  end reversed;

begin

  --CRC_OUT      <= not reversed(CRC);
  --CRC_OUT_NEXT <= not reversed(CRC_NEXT);

  CRC_OUT      <= CRC;
  CRC_OUT_NEXT <= CRC_NEXT;

  DREV <= reversed(DATA);

  CRC_NEXT( 0) <= CRC(24) xor CRC(30) xor DREV(0) xor DREV(6);
  CRC_NEXT( 1) <= CRC(24) xor CRC(25) xor CRC(30) xor CRC(31) xor DREV(0) xor DREV(1) xor DREV(6) xor DREV(7);
  CRC_NEXT( 2) <= CRC(24) xor CRC(25) xor CRC(26) xor CRC(30) xor CRC(31) xor DREV(0) xor DREV(1) xor DREV(2) xor DREV(6) xor DREV(7);
  CRC_NEXT( 3) <= CRC(25) xor CRC(26) xor CRC(27) xor CRC(31) xor DREV(1) xor DREV(2) xor DREV(3) xor DREV(7);
  CRC_NEXT( 4) <= CRC(24) xor CRC(26) xor CRC(27) xor CRC(28) xor CRC(30) xor DREV(0) xor DREV(2) xor DREV(3) xor DREV(4) xor DREV(6);
  CRC_NEXT( 5) <= CRC(24) xor CRC(25) xor CRC(27) xor CRC(28) xor CRC(29) xor CRC(30) xor CRC(31) xor DREV(0) xor DREV(1) xor DREV(3) xor DREV(4) xor DREV(5) xor DREV(6) xor DREV(7);
  CRC_NEXT( 6) <= CRC(25) xor CRC(26) xor CRC(28) xor CRC(29) xor CRC(30) xor CRC(31) xor DREV(1) xor DREV(2) xor DREV(4) xor DREV(5) xor DREV(6) xor DREV(7);
  CRC_NEXT( 7) <= CRC(24) xor CRC(26) xor CRC(27) xor CRC(29) xor CRC(31) xor DREV(0) xor DREV(2) xor DREV(3) xor DREV(5) xor DREV(7);
  CRC_NEXT( 8) <= CRC(0) xor CRC(24) xor CRC(25) xor CRC(27) xor CRC(28) xor DREV(0) xor DREV(1) xor DREV(3) xor DREV(4);
  CRC_NEXT( 9) <= CRC(1) xor CRC(25) xor CRC(26) xor CRC(28) xor CRC(29) xor DREV(1) xor DREV(2) xor DREV(4) xor DREV(5);
  CRC_NEXT(10) <= CRC(2) xor CRC(24) xor CRC(26) xor CRC(27) xor CRC(29) xor DREV(0) xor DREV(2) xor DREV(3) xor DREV(5);
  CRC_NEXT(11) <= CRC(3) xor CRC(24) xor CRC(25) xor CRC(27) xor CRC(28) xor DREV(0) xor DREV(1) xor DREV(3) xor DREV(4);
  CRC_NEXT(12) <= CRC(4) xor CRC(24) xor CRC(25) xor CRC(26) xor CRC(28) xor CRC(29) xor CRC(30) xor DREV(0) xor DREV(1) xor DREV(2) xor DREV(4) xor DREV(5) xor DREV(6);
  CRC_NEXT(13) <= CRC(5) xor CRC(25) xor CRC(26) xor CRC(27) xor CRC(29) xor CRC(30) xor CRC(31) xor DREV(1) xor DREV(2) xor DREV(3) xor DREV(5) xor DREV(6) xor DREV(7);
  CRC_NEXT(14) <= CRC(6) xor CRC(26) xor CRC(27) xor CRC(28) xor CRC(30) xor CRC(31) xor DREV(2) xor DREV(3) xor DREV(4) xor DREV(6) xor DREV(7);
  CRC_NEXT(15) <= CRC(7) xor CRC(27) xor CRC(28) xor CRC(29) xor CRC(31) xor DREV(3) xor DREV(4) xor DREV(5) xor DREV(7);
  CRC_NEXT(16) <= CRC(8) xor CRC(24) xor CRC(28) xor CRC(29) xor DREV(0) xor DREV(4) xor DREV(5);
  CRC_NEXT(17) <= CRC(9) xor CRC(25) xor CRC(29) xor CRC(30) xor DREV(1) xor DREV(5) xor DREV(6);
  CRC_NEXT(18) <= CRC(10) xor CRC(26) xor CRC(30) xor CRC(31) xor DREV(2) xor DREV(6) xor DREV(7);
  CRC_NEXT(19) <= CRC(11) xor CRC(27) xor CRC(31) xor DREV(3) xor DREV(7);
  CRC_NEXT(20) <= CRC(12) xor CRC(28) xor DREV(4);
  CRC_NEXT(21) <= CRC(13) xor CRC(29) xor DREV(5);
  CRC_NEXT(22) <= CRC(14) xor CRC(24) xor DREV(0);
  CRC_NEXT(23) <= CRC(15) xor CRC(24) xor CRC(25) xor CRC(30) xor DREV(0) xor DREV(1) xor DREV(6);
  CRC_NEXT(24) <= CRC(16) xor CRC(25) xor CRC(26) xor CRC(31) xor DREV(1) xor DREV(2) xor DREV(7);
  CRC_NEXT(25) <= CRC(17) xor CRC(26) xor CRC(27) xor DREV(2) xor DREV(3);
  CRC_NEXT(26) <= CRC(18) xor CRC(24) xor CRC(27) xor CRC(28) xor CRC(30) xor DREV(0) xor DREV(3) xor DREV(4) xor DREV(6);
  CRC_NEXT(27) <= CRC(19) xor CRC(25) xor CRC(28) xor CRC(29) xor CRC(31) xor DREV(1) xor DREV(4) xor DREV(5) xor DREV(7);
  CRC_NEXT(28) <= CRC(20) xor CRC(26) xor CRC(29) xor CRC(30) xor DREV(2) xor DREV(5) xor DREV(6);
  CRC_NEXT(29) <= CRC(21) xor CRC(27) xor CRC(30) xor CRC(31) xor DREV(3) xor DREV(6) xor DREV(7);
  CRC_NEXT(30) <= CRC(22) xor CRC(28) xor CRC(31) xor DREV(4) xor DREV(7);
  CRC_NEXT(31) <= CRC(23) xor CRC(29) xor DREV(5);

	crc_latch: process (CLK)
	begin
	  if rising_edge(CLK)
	  then
      if RESET = '1'
      then
        CRC <= X"FFFFFFFF";
      --
      elsif ENABLE = '1'
      then
        CRC <= CRC_NEXT;
      end if;
	  end if;
	end process;

end architecture;
