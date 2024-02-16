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
-- file:     eth_tx_data.vhd
-- brief:    PHY TX data control. Reading the data from the TXMEM
--           and sends to the PHY, calulates the CRC
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_tx_data is
port
(
	SLOT_FILLED 	  : in  std_logic;  -- data synchronization required
  SLOT_ADDR       : in  unsigned(11 downto 0);
  SLOT_FBYTES     : in  unsigned(11 downto 0);
  SLOT_RELEASE    : out std_logic;  -- handshake with SLOT_FILLED

  MEM_ADDR        : out unsigned(11 downto 0);
  MEM_DATA        : in  unsigned(31 downto 0);

  MANUAL_CRC      : in std_logic;

  ETH_DATA        : out  unsigned(7 downto 0);
  ETH_DATA_VALID  : out  std_logic;
	ETH_DATA_CLOCK 	: in  std_logic
);
end entity;

architecture behavioral of eth_tx_data
is
	function BIT_REVERSE(A : in unsigned)  return unsigned
  is
		variable RESULT : unsigned(A'range);
		alias AA : unsigned(A'reverse_range) is A;
	begin
		for i in AA'range loop
			RESULT(i) := AA(i);
		end loop;
		return RESULT;
	end;

  signal MADDR      : unsigned(11 downto 0);
  signal MADDR_PREV : unsigned(11 downto 0);

  signal MDATA      : unsigned(31 downto 0);
  signal SHREG      : unsigned(31 downto 0);
  signal SHCNT      : integer range 0 to 3;

  type TSTATE is (ST_START, ST_PREAMBLE, ST_BODY, ST_CRC, ST_WAIT, ST_RELEASE);
  signal STATE : TSTATE := ST_START;

  signal PREAMBCNT   : integer range 0 to 7;

  signal CRC         : unsigned(31 downto 0);
  signal CRC_ENABLE  : std_logic;
  signal CRC_RESET   : std_logic;
  signal CRCBCNT     : integer range 0 to 3;

	signal TXDATA      : unsigned(7 downto 0);
	signal TXEN        : std_logic;
  signal TXCNT       : unsigned(11 downto 0);

  signal WAITCNT     : integer range 0 to 15;

  signal SLOT_FILLED_Q : std_logic;

begin

  MEM_ADDR <= MADDR;

  ETH_DATA <= TXDATA;
  ETH_DATA_VALID <= TXEN;

	tx_data: process (ETH_DATA_CLOCK)
	begin
	  if rising_edge(ETH_DATA_CLOCK)
	  then
      SLOT_FILLED_Q <= SLOT_FILLED;  -- synchronizing cross clock-domain signal
      if SLOT_FILLED_Q = '0'  -- empty slot resets the state machine
      then
        CRC_ENABLE <= '0';
        CRC_RESET <= '1';
        SLOT_RELEASE <= '0';
        TXDATA <= X"00";
        TXEN <= '0';
        STATE <= ST_START;
      else
        case STATE
        is
          when ST_START
          =>
            TXEN <= '0';
            CRC_ENABLE <= '0';
            CRC_RESET <= '1';
            SLOT_RELEASE <= '0';
            MADDR <= SLOT_ADDR;
            PREAMBCNT <= 7;
            WAITCNT <= 11;
            TXCNT <= SLOT_FBYTES - 1;
            STATE <= ST_PREAMBLE;
          --
          when ST_PREAMBLE -- send the preamble
          =>
            TXEN <= '1';
            CRC_ENABLE <= '0';
            CRC_RESET <= '0';
            if PREAMBCNT = 0
            then
              TXDATA <= X"D5";
              SHREG <= MEM_DATA;
              SHCNT <= 3;
              MADDR <= MADDR + 1;
              STATE <= ST_BODY;
            else
              TXDATA <= X"55";
              PREAMBCNT <= PREAMBCNT - 1;
            end if;
          --
          when ST_BODY
          =>
            TXEN <= '1';
            TXDATA <= SHREG(7 downto 0);
            CRC_RESET <= '0';
            CRC_ENABLE <= '1';
            if TXCNT = 0
            then
              if MANUAL_CRC = '1'
              then
                STATE <= ST_RELEASE;
              else
                CRCBCNT <= 3;
                CRC_ENABLE <= '0';  -- do not rotate the CRC in the next cycle, the CRC next uses direct logic
                STATE <= ST_CRC;
              end if;
            else
              if SHCNT = 0
              then
                SHREG <= MEM_DATA;
                MADDR <= MADDR + 1;
                SHCNT <= 3;
              else
                SHREG(23 downto 0) <= SHREG(31 downto 8);
                SHCNT <= SHCNT - 1;
              end if;
              TXCNT <= TXCNT - 1;
            end if;
          --
          when ST_CRC
          =>
            TXEN <= '1';
            CRC_RESET <= '0';
            CRC_ENABLE <= '0';
            if CRCBCNT = 3
            then
              -- the CRC must sent be bit-reversed and inverted
              -- non bit-reversed+inverted version:
              --   TXDATA <= CRC(7 downto 0);
              --   SHREG(23 downto 0) <= CRC(31 downto 8);
              TXDATA <= not BIT_REVERSE(CRC(31 downto 24));
              SHREG(23 downto 0) <= not BIT_REVERSE(CRC(23 downto 0));
              CRCBCNT <= 2;
            else
              TXDATA <= SHREG(7 downto 0);
              if CRCBCNT = 0
              then
                STATE <= ST_WAIT;
              else
                SHREG(23 downto 0) <= SHREG(31 downto 8);
                CRCBCNT <= CRCBCNT - 1;
              end if;
            end if;
          --
          when ST_WAIT  -- inter frame gap: minimum 12 bytes = 12 clocks here
          =>
            TXEN <= '0';
            CRC_RESET <= '0';
            CRC_ENABLE <= '0';
            TXDATA <= X"00";
            if WAITCNT = 0
            then
              STATE <= ST_RELEASE;
            else
              WAITCNT <= WAITCNT - 1;
            end if;
          --
          when ST_RELEASE
          =>
            TXEN <= '0';
            SLOT_RELEASE <= '1';
            -- the controller must remove the SLOT_FILLED which resets this state machine
          --
        end case;
      end if;
    end if;
  end process;

	eth_txcrc : entity work.eth_crc
	port map
	(
    DATA          => TXDATA,
    CRC_OUT       => open,
    CRC_OUT_NEXT  => CRC,
    ENABLE        => CRC_ENABLE,
		RESET     		=> CRC_RESET,
		CLK		 				=> ETH_DATA_CLOCK
	);

end architecture;