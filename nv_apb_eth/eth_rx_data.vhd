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
-- file:     eth_rx_data.vhd
-- brief:    PHY RX data processing, storing into the RXMEM
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_rx_data is
port
(
	SLOT_VALID		  : in  std_logic;
  SLOT_ADDR       : in  unsigned(11 downto 0);
  SLOT_WORDS      : in  unsigned(11 downto 0);
  SLOT_FILLED     : out std_logic;
  SLOT_FBYTES     : out unsigned(11 downto 0);

  MEM_ADDR        : out unsigned(11 downto 0);
  MEM_DATA        : out unsigned(31 downto 0);
  MEM_WR          : out std_logic;

  ERR_OVF_TOG     : out std_logic;
  ERR_CRC_TOG     : out std_logic;

  MAC_ADDR        : in  unsigned(47 downto 0);
  MAC_ADDR_FILT   : in  std_logic;
  IGNORE_ERR      : in  std_logic;

  ETH_DATA        : in  unsigned(7 downto 0);
  ETH_DATA_VALID  : in  std_logic;
	ETH_DATA_CLOCK 	: in  std_logic
);
end entity;

architecture behavioral of eth_rx_data
is
  signal MADDR      : unsigned(11 downto 0);
  signal MADDR_PREV : unsigned(11 downto 0);

  signal MDATA     : unsigned(31 downto 0);

  type TSTATE is (ST_DATA, ST_CRC_CHECK, ST_STORE, ST_WAITPAUSE);
  signal STATE : TSTATE := ST_DATA;

  signal MEMWBYTECNT    : integer range 0 to 3;  -- memory word byte counter
  signal FRAMELEN  : unsigned(11 downto 0);
  signal MACCNT    : integer range 0 to 7;

  signal ERR_TOG_OVF : std_logic := '0';
  signal ERR_TOG_CRC : std_logic := '0';

  signal CRC         : unsigned(31 downto 0);

  signal SLOT_VALID_Q : std_logic;  -- for cross-domain synchronization

begin

  ERR_OVF_TOG <= ERR_TOG_OVF;
  ERR_CRC_TOG <= ERR_TOG_CRC;
  MEM_ADDR    <= MADDR_PREV; -- 1 clock delayed for the address increment logic
  SLOT_FBYTES <= FRAMELEN;

	rx_data: process (ETH_DATA_CLOCK)
	begin
	  if rising_edge(ETH_DATA_CLOCK)
	  then
      SLOT_VALID_Q <= SLOT_VALID; -- synchronizing cross clock-domain signal
      MADDR_PREV <= MADDR;

      if SLOT_VALID_Q = '0'  -- invalid slot resets the state machine
      then
        MEM_WR <= '0';
        SLOT_FILLED <= '0';
        MDATA <= X"00000000";
        FRAMELEN <= X"000";
        MEMWBYTECNT <= 0;
        STATE <= ST_DATA;
      else
        case STATE
        is
          -- The xMII RX module provides the data without preamble because
          -- it might need clock adjustments. So in the ST_DATA state handled several cases

          when ST_DATA  -- process the main data, including CRC at the end
          =>
            MEM_WR <= '0'; -- might be overridden later
            if FRAMELEN = X"000"
            then
              MEMWBYTECNT <= 0;
              MADDR <= SLOT_ADDR;  -- latch the slot start address
            end if;

            if ETH_DATA_VALID = '1'
            then
              FRAMELEN <= FRAMELEN + 1;
              if FRAMELEN >= unsigned(SLOT_WORDS & "00")  -- data too much ?
              then
                ERR_TOG_OVF <= not ERR_TOG_OVF;
                STATE <= ST_WAITPAUSE;
              else
                if MEMWBYTECNT = 3  -- last byte of the 32-bit memory word
                then
                  -- store to the memory, write directly to MEM_DATA without delay
                  MEM_DATA(31 downto 24) <= ETH_DATA;
                  MEM_DATA(23 downto  0) <= MDATA(31 downto 8);
                  MEM_WR <= '1'; -- override it for one clock
                  MADDR <= MADDR + 1; -- increment for the future, but the MADDR_PREV will be used on the next cycle
                  MEMWBYTECNT <= 0;
                else
                  MEMWBYTECNT <= MEMWBYTECNT + 1;
                end if;

                -- shift the ETH_DATA into the MDATA from left:
                MDATA(31 downto 24) <= ETH_DATA;
                MDATA(23 downto 0) <= MDATA(31 downto 8);
              end if;
            else
              if FRAMELEN = X"000"
              then
                -- still waiting for the first data byte
              else
                -- last byte was received
                if MEMWBYTECNT /= 0  -- partial data in the MDATA ?
                then
                  -- store the last bytes
                  if    MEMWBYTECNT = 3  then   MEM_DATA(31 downto  0) <= X"00"     & MDATA(31 downto  8);
                  elsif MEMWBYTECNT = 2  then   MEM_DATA(31 downto  0) <= X"0000"   & MDATA(31 downto 16);
                  elsif MEMWBYTECNT = 1  then   MEM_DATA(31 downto  0) <= X"000000" & MDATA(31 downto 24);
                  end if;
                  MEM_WR <= '1';
                end if;

                STATE <= ST_CRC_CHECK;
              end if;
            end if;
          --
          when ST_CRC_CHECK
          =>
            MEM_WR <= '0';
            MEM_DATA <= CRC;  -- for debugging
            -- original magic number: X"C704DD7B"
            -- not reversed() magic number: X"2144DF1C"
            if CRC /= X"C704DD7B" -- magic number, remainder after special processing
            then
              ERR_TOG_CRC <= not ERR_TOG_CRC;
              if IGNORE_ERR = '1'
              then
                STATE <= ST_STORE;
              else
                STATE <= ST_WAITPAUSE;  -- normal case, do not store this packet
              end if;
            else
              STATE <= ST_STORE;
            end if;
          --
          when ST_STORE  -- close the slot storing the data
          =>
            MEM_WR <= '0';
            SLOT_FILLED <= '1';  -- signalize the slot handler to advance to the next slot

            -- the controller must remove the SLOT_VALID which resets this state machine
          ---
          when ST_WAITPAUSE -- wait for ETH_DATA_VALID = '0'
          =>
            MEM_WR <= '0';
            SLOT_FILLED <= '0';
            if ETH_DATA_VALID = '0'
            then
              FRAMELEN <= X"000";
              MEMWBYTECNT <= 0;
              MADDR <= SLOT_ADDR; -- for the case if the next clock is a valid byte
              STATE <= ST_DATA;
            end if;
          --
        end case;
      end if;
    end if;
  end process;

	eth_rxcrc : entity work.eth_crc
	port map
	(
    DATA          => ETH_DATA,
    CRC_OUT       => CRC,
    CRC_OUT_NEXT  => open,
    ENABLE        => ETH_DATA_VALID,  -- do not process data without ETH_VALID
		RESET     		=> not SLOT_VALID_Q,
		CLK		 				=> ETH_DATA_CLOCK
	);

end architecture;