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
-- file:     eth_rmii_rx.vhd
-- brief:    PHY RX handling for RMII, cutting the preamble off and
--           putting 4x2 bits together, syncing to preamble
-- created:  2024-02-16
-- authors:  nvitya
-- note:
--   tx part is missing, but it is easier as this one

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_rmii_rx is
port
(
  RMII_CLK    : in  std_logic;
	RMII_CRS_DV : in std_logic;
	RMII_RX			: in unsigned(1 downto 0);

  ETH_DATA    : out unsigned(7 downto 0);  -- without preamble
  ETH_DVALID  : out std_logic;
  ETH_DCLK    : out std_logic
);
end entity;

architecture behavioral of eth_rmii_rx
is
  type TSTATE is (ST_SYNC, ST_BODY);
  signal STATE : TSTATE := ST_SYNC;

  signal DATA    : unsigned(7 downto 0);
  signal DVALID  : std_logic := '0';

  signal SHREG   : unsigned(7 downto 0);
  signal CLKCNT  : integer range 0 to 3 := 0;
  signal PRECNT  : integer range 0 to 63 := 0;
begin

  ETH_DVALID <= DVALID;

  ETH_DCLK <= '1' when (CLKCNT = 0) or (CLKCNT = 1) else '0';

  rmii : process(RMII_CLK)
  begin
    if rising_edge(RMII_CLK)
    then
      if CLKCNT = 3
      then
        CLKCNT <= 0;
      else
        CLKCNT <= CLKCNT + 1;
      end if;

      case STATE
      is
        when ST_SYNC
        =>
          DVALID <= '0';
          if RMII_CRS_DV = '0'
          then
            PRECNT <= 0;
          else
            if "01" = RMII_RX
            then
              if PRECNT < 63
              then
                PRECNT <= PRECNT + 1;
              end if;
            --
            elsif "11" = RMII_RX
            then
              if PRECNT >= 31
              then
                CLKCNT <= 0; -- resync data clock
                STATE <= ST_BODY;
              end if;
            end if;
          end if;
        --
        when ST_BODY
        =>
          if CLKCNT = 3
          then
            ETH_DATA(7 downto 6) <= RMII_RX;
            ETH_DATA(5 downto 0) <= SHREG(7 downto 2);
            DVALID <= '1';
          else
            if RMII_CRS_DV = '0'
            then
              DVALID <= '0';
              STATE <= ST_SYNC;
            end if;
          end if;
          SHREG(7 downto 6) <= RMII_RX;
          SHREG(5 downto 0) <= SHREG(7 downto 2);
        --
      end case;
    end if; -- clock
  end process;

end architecture;