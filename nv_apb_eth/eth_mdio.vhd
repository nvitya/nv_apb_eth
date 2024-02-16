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
-- file:     eth_mdio.vhd
-- brief:    MDIO read write handling APB module
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_mdio is
port
(
	ETH_MDC	    : out   std_logic;
	ETH_MDIO    : inout std_logic;

  HALF_BIT_CLKS : in unsigned(7 downto 0);

  START       : in  std_logic;
  WRITE_NREAD : in  std_logic;
  PHY_ADDR    : in  unsigned(4 downto 0);
  REG_ADDR    : in  unsigned(4 downto 0);
  WR_DATA     : in  unsigned(15 downto 0);
  RD_DATA     : out unsigned(15 downto 0);

  BUSY        : out std_logic;

	APB_CLK 		: in  std_logic
);
end entity;

architecture behavioral of eth_mdio
is
  type TSTATE is (ST_IDLE, ST_LOW, ST_HIGH, ST_FINISH);
  signal STATE : TSTATE := ST_IDLE;

  signal DSAMPLE : std_ulogic;
  signal SHREG : unsigned(31 downto 0);
  signal PRECNT : integer range 0 to 32;
  signal CNT    : integer range 0 to 32;
  signal OUTCNT : integer range 0 to 32;
  signal HALF_BIT_CNT : unsigned(7 downto 0);
begin

  mdio : process(APB_CLK)
  begin
    if rising_edge(APB_CLK)
    then
      case STATE
      is
        when ST_IDLE
        =>
          BUSY <= '0';
          ETH_MDC <= '0';
          ETH_MDIO <= 'Z';
          DSAMPLE <= '0';

          if '1' = START
          then
            SHREG(31 downto 30) <= "01";     -- ST
            -- bit 29-28 are WR/RD specific
            SHREG(27 downto 23) <= PHY_ADDR; -- PA5
            SHREG(22 downto 18) <= REG_ADDR; -- RA5
            -- write only
            SHREG(17 downto 16) <= "10";     -- TA: turn around
            SHREG(15 downto  0) <= WR_DATA;
            if WRITE_NREAD = '1'
            then
              SHREG(29 downto 28) <= "01";     -- OP: 01 = write, 10 = read
              OUTCNT <= 32;
            else -- read
              SHREG(29 downto 28) <= "10";     -- OP: 01 = write, 10 = read
              OUTCNT <= 14;
            end if;
            PRECNT <= 31;
            CNT <= 32;
            ETH_MDIO <= '1';
            HALF_BIT_CNT <= HALF_BIT_CLKS;
            STATE <= ST_LOW;
          end if;
        --
        when ST_LOW
        =>
          BUSY <= '1';
          ETH_MDC <= '0';
          if HALF_BIT_CNT = X"00"
          then
            ETH_MDC <= '1';
            DSAMPLE <= ETH_MDIO;  -- sample the input data here, processed in high to low
            HALF_BIT_CNT <= HALF_BIT_CLKS;
            STATE <= ST_HIGH;
          else
            HALF_BIT_CNT <= HALF_BIT_CNT - 1;
          end if;
        --
        when ST_HIGH
        =>
          BUSY <= '1';
          ETH_MDC <= '1';
          if HALF_BIT_CNT = X"00"  -- put the new data here
          then
            ETH_MDC <= '0';
            HALF_BIT_CNT <= HALF_BIT_CLKS;
            STATE <= ST_LOW; -- this might be overridden later
            if PRECNT = 0
            then
              -- put the output data
              if CNT = 0
              then
                STATE <= ST_FINISH;
              else
                if OUTCNT = 0
                then
                  ETH_MDIO <= 'Z';
                else
                  ETH_MDIO <= SHREG(31); -- shift is a few lines later
                  OUTCNT <= OUTCNT - 1;
                end if;
                CNT <= CNT - 1;
              end if;
              -- shift the data, adding the input samples
              SHREG(31 downto 1) <= SHREG(30 downto 0);
              SHREG(0) <= DSAMPLE;
            else
              ETH_MDIO <= '1';
              PRECNT <= PRECNT - 1;
            end if;
          else
            HALF_BIT_CNT <= HALF_BIT_CNT - 1;
          end if;
        --
        when ST_FINISH
        =>
          BUSY <= '1';
          ETH_MDC <= '0';
          ETH_MDIO <= 'Z';
          RD_DATA <= SHREG(15 downto 0); -- latch the input data
          if '0' = START  -- the controller should remove the start signals
          then
            STATE <= ST_IDLE;
          end if;
        --
      end case;
    end if;
  end process;

end architecture;