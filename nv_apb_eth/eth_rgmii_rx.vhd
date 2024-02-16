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
-- file:     eth_rgmii_rx.vhd
-- brief:    PHY RX handling for RGMII, cutting the preamble off and using
--           DDR input drivers
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_rgmii_rx is
port
(
  RGMII_CLK   : in std_logic;
	RGMII_RXDV  : in std_logic;
	RGMII_RXD		: in unsigned(3 downto 0);

  ETH_DATA    : out unsigned(7 downto 0);  -- without preamble
  ETH_DVALID  : out std_logic;
  ETH_DCLK    : out std_logic
);
end entity;

architecture behavioral of eth_rgmii_rx
is
  type TSTATE is (ST_SYNC, ST_BODY);
  signal STATE : TSTATE := ST_SYNC;

  signal RX_DDR_R      : unsigned(3 downto 0);
  signal RX_DDR_R_PREV : unsigned(3 downto 0);
  signal RX_DDR_F      : unsigned(3 downto 0);

	signal RXDV_SH : std_logic_vector(1 downto 0);

  signal PREAMBCNT  : integer range 0 to 7 := 0;
begin

  ETH_DCLK <= RGMII_CLK;

  rgmii : process(RGMII_CLK)
    variable VDATA : unsigned(7 downto 0);
    variable VDV   : std_logic;
  begin
    if rising_edge(RGMII_CLK)
    then
      VDATA := RX_DDR_F & RX_DDR_R_PREV;
      VDV   := RXDV_SH(0);

			ETH_DATA <= VDATA;

      -- delay the rising edge part to match the double-delayed falling edge data
			RX_DDR_R_PREV <= RX_DDR_R;

			-- delay the valid signal too:
			RXDV_SH(0) <= RXDV_SH(1);
			RXDV_SH(1) <= RGMII_RXDV;

      case STATE
      is
        when ST_SYNC
        =>
          ETH_DVALID <= '0';
          if VDV = '0'
          then
             PREAMBCNT <= 0;
          else
            if (VDATA = X"D5") and (PREAMBCNT = 7)  -- last byte of the preamble?
            then
              STATE <= ST_BODY;
            --
            elsif VDATA = X"55"
            then
              if PREAMBCNT < 7
              then
                PREAMBCNT <= PREAMBCNT + 1;
              end if;
            else
              PREAMBCNT <= 0;
            end if;
          end if;
        --
        when ST_BODY
        =>
          ETH_DVALID <= VDV;
          if VDV = '0'
          then
            STATE <= ST_SYNC;
          end if;
        --
      end case;
    end if; -- clock
  end process;

	rgmmi_rx_ddr : entity work.ddr_input  -- platform dependent implementation
	generic map
	(
		DATA_WIDTH => 4
	)
	port map
	(
		DATA_IN     => RGMII_RXD,  -- in  unsigned(DATA_WIDTH - 1 downto 0);
		DATA_OUT_R  => RX_DDR_R,   -- out unsigned(DATA_WIDTH - 1 downto 0);
		DATA_OUT_F  => RX_DDR_F,   -- out unsigned(DATA_WIDTH - 1 downto 0);
		CLOCK       => RGMII_CLK   -- std_logic
	);

end architecture;