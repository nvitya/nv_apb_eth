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
-- file:     eth_gmii_tx.vhd
-- brief:    PHY TX handling for GMII, just passing through, because
--           the internal processing format is the same
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_gmii_tx is
port
(
  GMII_CLK      : in  std_logic;
	GMII_TXEN     : out std_logic;
	GMII_TXD		   : out unsigned(7 downto 0);

  ETH_DATA       : in unsigned(7 downto 0);  -- with preamble
  ETH_DATA_VALID : in std_logic;
  ETH_DATA_CLK   : out std_logic
);
end entity;

architecture behavioral of eth_gmii_tx
is
begin

  GMII_TXD    <= ETH_DATA;
  GMII_TXEN   <= ETH_DATA_VALID;

  ETH_DATA_CLK  <= GMII_CLK;

end architecture;