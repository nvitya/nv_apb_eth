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
-- file:     eth_slot_ctrl.vhd
-- brief:    Ethernet memory slot controller. Allocates slots
--           and coordinates the reads and writes
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_slot_ctrl is
generic
(
  MEM_ADDR_BITS : natural  -- 10..12,   10 -> 4k, 11 -> 8k, 12 -> 16k RAM
);
port
(
	PUT_VALID			: out std_logic;
  PUT_ADDR      : out unsigned(11 downto 0);
  PUT_FILLED    : in  std_logic;             -- async at RX ! (ETH_CLK)
  PUT_FBYTES    : in  unsigned(11 downto 0); -- async at RX ! (ETH_CLK)

  GET_ADDR      : out unsigned(11 downto 0);
  GET_FILLED    : out std_logic;
  GET_FBYTES    : out unsigned(11 downto 0);
  GET_RELEASE   : in  std_logic;  -- async at TX ! (ETH_CLK)

  SLOT_WORDS    : in  unsigned(11 downto 0);
  ENABLE        : in  std_logic;
	APB_CLK 			: in  std_logic
);
end entity;

architecture behavioral of eth_slot_ctrl
is
  constant MEM_WORDS : natural := 2 ** MEM_ADDR_BITS;

  type T_SLOT_RECORD is
  record
    FILLED   : std_logic;
    ADDR     : unsigned(11 downto 0);
    FBYTES   : unsigned(11 downto 0);
  end record;

  type T_SLARR is array (7 downto 0) of T_SLOT_RECORD;
  signal SLARR : T_SLARR;

  signal IDX_PUT : integer range 0 to 7 := 0;
  signal IDX_GET : integer range 0 to 7 := 0;
  signal IDX_LAST : integer range 0 to 7 := 0;

  signal CADDR : unsigned(11 downto 0);

  signal GET_RELEASE_Q    : std_logic := '0';
  signal GET_RELEASE_PREV : std_logic := '0';

  signal PUT_FILLED_Q     : std_logic := '0';
  signal PUT_FILLED_PREV  : std_logic := '0';

  signal INITIALIZED : std_logic := '0';

begin

	slot_ctrl: process (APB_CLK)  -- one single process because of the shared slot registers
	begin
	  if rising_edge(APB_CLK)
	  then
      -- INIT SLOTS

      if ENABLE = '0'
      then
        INITIALIZED <= '0';
        IDX_LAST <= 0;
        CADDR <= X"000";

        PUT_VALID  <= '0';
        IDX_PUT <= 0;
        GET_FILLED <= '0';
        IDX_GET <= 0;
      --
      elsif INITIALIZED = '0' -- short initialization phase
      then
        SLARR(IDX_LAST).ADDR <= CADDR;
        SLARR(IDX_LAST).FILLED <= '0';
        SLARR(IDX_LAST).FBYTES <= X"000";

        -- (SLOT_WORDS & '0') = SLOT_WORDS * 2
        if (CADDR + (SLOT_WORDS & '0') <= MEM_WORDS) and (IDX_LAST < 7)
        then
          IDX_LAST <= IDX_LAST + 1;
          CADDR <= CADDR + SLOT_WORDS;
        else
          INITIALIZED <= '1';
        end if;
      --
      else  -- ENABLE and INITIALIZED

        -- PUT LOGIC
        PUT_FILLED_Q <= PUT_FILLED; -- synchronize the signal
        PUT_FILLED_PREV <= PUT_FILLED_Q;

        PUT_VALID <= not SLARR(IDX_PUT).FILLED and not PUT_FILLED_Q;
        PUT_ADDR  <= SLARR(IDX_PUT).ADDR;

        if (SLARR(IDX_PUT).FILLED = '0') and (PUT_FILLED_Q = '1') and (PUT_FILLED_PREV = '0')
        then
          SLARR(IDX_PUT).FBYTES <= PUT_FBYTES;
          SLARR(IDX_PUT).FILLED <= '1';
          if IDX_PUT = IDX_LAST
          then
            IDX_PUT <= 0;
          else
            IDX_PUT <= IDX_PUT + 1;
          end if;
        end if;

        -- GET LOGIC
        GET_RELEASE_Q <= GET_RELEASE; -- synchronize the signal
        GET_RELEASE_PREV <= GET_RELEASE_Q;

        GET_ADDR <= SLARR(IDX_GET).ADDR;
        GET_FILLED <= SLARR(IDX_GET).FILLED and not GET_RELEASE_Q;
        GET_FBYTES <= SLARR(IDX_GET).FBYTES;

        if (SLARR(IDX_GET).FILLED = '1') and (GET_RELEASE_Q = '1') and (GET_RELEASE_PREV = '0')
        then
          SLARR(IDX_GET).FILLED <= '0'; -- releases the slot
          if IDX_GET = IDX_LAST
          then
            IDX_GET <= 0;
          else
            IDX_GET <= IDX_GET + 1;
          end if;
        end if;

      end if; -- ENABLE and INITIALIZED

    end if; -- clock rising edge
  end process;

end architecture;