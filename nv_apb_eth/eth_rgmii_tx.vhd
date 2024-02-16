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
-- file:     eth_rgmii_tx.vhd
-- brief:    PHY TX handling for RGMII, using DDR output drivers
-- created:  2024-02-16
-- authors:  nvitya
-- notes:
--   Work in progress, not working properly yet, TX timing must be adjusted

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_rgmii_tx is
port
(
  RGMII_CLK      : in  std_logic;
	RGMII_TXEN     : out std_logic;
	RGMII_TXD		   : out unsigned(3 downto 0);

  ETH_DATA       : in unsigned(7 downto 0);  -- with preamble
  ETH_DATA_VALID : in std_logic;
  ETH_DATA_CLK   : out std_logic
);
end entity;

architecture behavioral of eth_rgmii_tx
is
	signal TXEN_SH : std_logic_vector(0 downto 0);
	signal TXD_OUT : unsigned(3 downto 0);
begin

  ETH_DATA_CLK <= RGMII_CLK;
	RGMII_TXD    <= TXD_OUT;

  rgmii : process(RGMII_CLK)
  begin
    if rising_edge(RGMII_CLK)
    then
      RGMII_TXEN <= ETH_DATA_VALID;  -- one clock delay

      --TXEN_SH(0) <= ETH_DATA_VALID;
      --RGMII_TXEN <= TXEN_SH(0); -- two clocks delay
    end if; -- clock
  end process;

	rgmmi_tx_ddr : entity work.ddr_output  -- platform dependent implementation
	generic map
	(
		DATA_WIDTH => 4
	)
	port map
	(
		DATA_IN_R  => ETH_DATA(3 downto 0),   -- in  unsigned(DATA_WIDTH - 1 downto 0);
		DATA_IN_F  => ETH_DATA(7 downto 4),   -- in  unsigned(DATA_WIDTH - 1 downto 0);
		DATA_OUT   => TXD_OUT,                -- out unsigned(DATA_WIDTH - 1 downto 0);
		CLOCK      => RGMII_CLK
	);

end architecture;