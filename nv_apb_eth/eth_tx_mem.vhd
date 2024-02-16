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
-- file:     eth_tx_mem.vhd
-- brief:    TX MEMORY for Ethernet, WO from APB, RO from ETH
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- data width is always 32

entity eth_tx_mem is
generic
(
  ADDR_BITS : natural := 10  -- 10 -> 4 kByte, max 12 -> 16 kByte
);
port
(
  ETH_ADDR    : in  unsigned(11 downto 0);  -- addresses are always 12 bit
  ETH_RDATA   : out unsigned(31 downto 0);
  ETH_CLK     : in  std_logic;

  APB_ADDR    : in  unsigned(11 downto 0);
  APB_WR      : in  std_logic;
  APB_WDATA   : in  unsigned(31 downto 0);
  APB_RDATA   : out unsigned(31 downto 0);  -- using this on altera allocated twice as much memory !
  APB_CLK     : in  std_logic
);
end entity;

architecture behavioral of eth_tx_mem
is
  type   ARRAY_TXMEM is array (0 to 2 ** ADDR_BITS - 1) of unsigned(31 downto 0);
  signal TXMEM : ARRAY_TXMEM;
begin
  ETH_RDATA <= TXMEM(to_integer(ETH_ADDR(ADDR_BITS-1 downto 0)));  -- must be handdled in clocked logic later
  APB_RDATA <= TXMEM(to_integer(APB_ADDR(ADDR_BITS-1 downto 0)));  -- must be handdled in clocked logic later

  eth : process(ETH_CLK)
  begin
    if rising_edge(ETH_CLK)
    then
    end if;
  end process;

  apb : process(APB_CLK)
  begin
    if rising_edge(APB_CLK)
    then
      if APB_WR = '1'
      then
        TXMEM(to_integer(APB_ADDR(ADDR_BITS-1 downto 0))) <= APB_WDATA;
      end if;
    end if;
  end process;

end architecture;