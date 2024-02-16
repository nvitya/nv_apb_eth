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
-- file:     eth_apb_main.vhd
-- brief:    Main APB Module
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.version.all;

entity eth_apb_main is
generic
(
  TXMEM_ADDR_BITS : natural := 10;  -- 10 -> 4k, 11 -> 8k, 12 -> 16 kByte RAM
  RXMEM_ADDR_BITS : natural := 10;  -- 10 -> 4k, 11 -> 8k, 12 -> 16 kByte RAM
  TXMEM_APB_READ  : std_logic := '0'  -- '1' will use twice as much TXRAM
);
port
(
  APB_PADDR			: in  std_logic_vector(15 downto 0);
  APB_PSEL			: in  std_logic;
  APB_PENABLE		: in  std_logic;
  APB_PREADY		: out std_logic;
  APB_PWRITE		: in  std_logic;
  APB_PWDATA		: in  std_logic_vector(31 downto 0);
  APB_PRDATA		: out std_logic_vector(31 downto 0);
  APB_PSLVERROR	: out std_logic;

  ETH_RXD			: in  std_logic_vector(7 downto 0); -- GMII RX data
  ETH_TXD			: out std_logic_vector(7 downto 0); -- GMII TX data
  ETH_RXC			: in  std_logic;  -- 125 MHz clock
  ETH_TXC			: in  std_logic;  --  25 Mhz mii tx clock
  ETH_GTXC		: out std_logic;
  ETH_RESET		: out std_logic;
  ETH_RXDV		: in  std_logic;
  ETH_RXER		: in  std_logic;
  ETH_TXEN		: out std_logic;

  ETH_MDC			: out   std_logic;
  ETH_MDIO		: inout std_logic;

  RESET     	: in  std_ulogic := '0'; 	-- global reset, low-active, async
  APB_CLK		  : in  std_logic
);
end entity;

architecture behavioral of eth_apb_main
is
  signal ETH_TX_CLK  : std_logic;
  signal ETH_RX_CLK  : std_logic;
  signal ETH_TX_DATA : unsigned(7 downto 0);

  --

  signal APB_WRITE_CYCLE : std_logic;
  signal APB_WDATA : unsigned(31 downto 0);
  signal APB_RDATA : unsigned(31 downto 0);

  signal REG_RANGE : unsigned(1 downto 0);
  signal REG_ADDR  : unsigned(7 downto 0);
  signal REG_RDATA  : unsigned(31 downto 0);

  signal MEM_APB_WDATA  : unsigned(31 downto 0);

  -- TX MODULE

  signal TX_SLOT_WORDS  : unsigned(11 downto 0) := X"000";
  signal TX_ENABLE : std_logic := '0';
  signal TX_MANUAL_CRC : std_logic := '0';

  signal TXMEM_ETH_ADDR  : unsigned(11 downto 0);
  signal TXMEM_ETH_DATA  : unsigned(31 downto 0);

  signal TXMEM_APB_RDATA    : unsigned(31 downto 0);
  signal TXMEM_APB_RDATA_Q  : unsigned(31 downto 0);
  signal TXMEM_APB_WR       : std_logic;

  signal TX_PUT_VALID  : std_logic;
  signal TX_PUT_ADDR   : unsigned(11 downto 0);
  signal TX_PUT_FILLED : std_logic := '0';
  signal TX_PUT_FBYTES : unsigned(11 downto 0) := X"000";

  signal TX_GET_ADDR    : unsigned(11 downto 0);
  signal TX_GET_FBYTES  : unsigned(11 downto 0);
  signal TX_GET_FILLED  : std_logic;
  signal TX_GET_RELEASE : std_logic;

  signal TXDATA         : unsigned(7 downto 0);
  signal TXDATA_VALID   : std_logic;
  signal TXDATA_CLOCK   : std_logic;

  -- RX MODULE

  signal RX_SLOT_WORDS  : unsigned(11 downto 0) := X"000";
  signal RX_ENABLE      : std_logic := '0';
  signal RX_PROMISCUOUS : std_logic := '0';
  signal RX_IGNORE_ERR  : std_logic := '0';

  signal RXMEM_ETH_ADDR  : unsigned(11 downto 0);
  signal RXMEM_ETH_DATA  : unsigned(31 downto 0);
  signal RXMEM_ETH_WR    : std_logic;

  signal RXMEM_APB_RDATA   : unsigned(31 downto 0);
  signal RXMEM_APB_RDATA_Q : unsigned(31 downto 0);

  signal RX_PUT_VALID  : std_logic;
  signal RX_PUT_ADDR   : unsigned(11 downto 0);
  signal RX_PUT_FILLED : std_logic;
  signal RX_PUT_FBYTES : unsigned(11 downto 0);

  signal RX_GET_ADDR    : unsigned(11 downto 0);
  signal RX_GET_FBYTES  : unsigned(11 downto 0);
  signal RX_GET_FILLED  : std_logic;
  signal RX_GET_RELEASE : std_logic := '0';

  signal RXDATA         : unsigned(7 downto 0);
  signal RXDATA_VALID   : std_logic;
  signal RXDATA_CLOCK   : std_logic;

  -- MDIO MODULE

  signal MDIO_HALF_BIT_CLOCKS : unsigned(7 downto 0) := X"14";  -- 2.5 MHz @ 100 MHz
  signal MDIO_PHY_ADDR        : unsigned(4 downto 0) := "00000";
  signal MDIO_REG_ADDR        : unsigned(4 downto 0) := "00000";
  signal MDIO_WR_DATA         : unsigned(15 downto 0) := X"0000";
  signal MDIO_RD_DATA         : unsigned(15 downto 0) := X"0000";
  signal MDIO_PHY_RESET       : std_logic := '0';
  signal MDIO_BUSY            : std_logic := '0';
  signal MDIO_WRITE_NREAD     : std_logic := '0';
  signal MDIO_START           : std_logic := '0';

  -----------------------------------------------------------------------------

  signal MAC_ADDRESS   : unsigned(47 downto 0) := X"000000000000";
  signal PHY_SPEED     : unsigned(1 downto 0) := "01";

  -- registers for APB reads
  signal REG_VERSION   : unsigned(31 downto 0);  -- read only
  signal REG_INFO      : unsigned(31 downto 0) := X"00000000";
  signal REG_TXCTRL    : unsigned(31 downto 0) := X"00000000";
  signal REG_RXCTRL    : unsigned(31 downto 0) := X"00000000";
  signal REG_PHYCTRL   : unsigned(31 downto 0) := X"00000000";
  signal REG_MACADDR1  : unsigned(31 downto 0) := X"00000000";
  signal REG_MACADDR2  : unsigned(31 downto 0) := X"00000000";

  signal REG_MDIO_SPEED  : unsigned(31 downto 0) := X"00000000";
  signal REG_MDIO_CMD    : unsigned(31 downto 0) := X"00000000";
  signal REG_MDIO_STATUS : unsigned(31 downto 0) := X"00000000";

  signal REG_TXPUT     : unsigned(31 downto 0) := X"00000000";
  signal REG_RXGET     : unsigned(31 downto 0) := X"00000000";


begin
  -----------------------------------------------------------------------------
  -- ASYNC PATHS
  -----------------------------------------------------------------------------

  APB_PSLVERROR   <= '0';
  APB_PREADY      <= APB_PSEL and APB_PENABLE;
  APB_WRITE_CYCLE <= APB_PSEL and APB_PENABLE and APB_PWRITE;

  REG_RANGE <= unsigned(APB_PADDR(15 downto 14));
  REG_ADDR  <= unsigned(APB_PADDR( 7 downto  2)) & "00";  -- ensure that the low two bits are zero

  TXMEM_APB_WR <= '1' when (APB_WRITE_CYCLE = '1') and ("01" = REG_RANGE) else '0';

  APB_WDATA <= unsigned(APB_PWDATA);

  ETH_RESET <= not MDIO_PHY_RESET;

  ETH_RX_CLK <= ETH_RXC;
  ETH_TX_CLK <= ETH_RXC;     -- this should come from an internal PLL
  ETH_GTXC   <= ETH_TX_CLK;

  ETH_TXD <= std_logic_vector(ETH_TX_DATA);

  -----------------------------------------------------------------------------
  -- REGISTERS, all non-filled bits will be read back as zero
  -----------------------------------------------------------------------------

  REG_VERSION <= NV_ETH_APB_VERSION;

  REG_INFO(3 downto 0)  <= to_unsigned(TXMEM_ADDR_BITS, 4);
  REG_INFO(7 downto 4)  <= to_unsigned(RXMEM_ADDR_BITS, 4);

  REG_TXCTRL(31)           <= TX_ENABLE;
  REG_TXCTRL(30)           <= TX_MANUAL_CRC;
  REG_TXCTRL(11 downto 0)  <= TX_SLOT_WORDS;

  REG_RXCTRL(31)           <= RX_ENABLE;
  REG_RXCTRL(30)           <= RX_PROMISCUOUS;
  REG_RXCTRL(29)           <= RX_IGNORE_ERR;
  REG_RXCTRL(11 downto 0)  <= RX_SLOT_WORDS;

  REG_PHYCTRL(1 downto 0)  <= PHY_SPEED;

  REG_MACADDR1(31 downto 0) <= MAC_ADDRESS(31 downto  0);
  REG_MACADDR2(15 downto 0) <= MAC_ADDRESS(47 downto 32);

  REG_MDIO_CMD(15 downto  0) <= MDIO_WR_DATA;
  REG_MDIO_CMD(20 downto 16) <= MDIO_REG_ADDR;
  REG_MDIO_CMD(25 downto 21) <= MDIO_PHY_ADDR;
  REG_MDIO_CMD(26)           <= MDIO_PHY_RESET;
  REG_MDIO_CMD(30)           <= MDIO_WRITE_NREAD;

  REG_MDIO_STATUS(15 downto  0) <= MDIO_RD_DATA;
  REG_MDIO_STATUS(20 downto 16) <= MDIO_REG_ADDR;
  REG_MDIO_STATUS(25 downto 21) <= MDIO_PHY_ADDR;
  REG_MDIO_STATUS(30)           <= MDIO_WRITE_NREAD;
  REG_MDIO_STATUS(31)           <= MDIO_BUSY;

  REG_MDIO_SPEED(7 downto 0) <= MDIO_HALF_BIT_CLOCKS;

  REG_TXPUT(11 downto 0)   <= TX_PUT_ADDR;
  REG_TXPUT(23 downto 12)  <= TX_PUT_FBYTES;
  REG_TXPUT(31)            <= TX_PUT_FILLED;

  REG_RXGET(11 downto 0)   <= RX_GET_ADDR;
  REG_RXGET(23 downto 12)  <= RX_GET_FBYTES;
  REG_RXGET(31)            <= RX_GET_FILLED;

  REG_RDATA
  <=
    REG_VERSION      when (X"00" = REG_ADDR) else
    REG_INFO         when (X"04" = REG_ADDR) else
    REG_TXCTRL       when (X"08" = REG_ADDR) else
    REG_RXCTRL       when (X"0C" = REG_ADDR) else
    REG_PHYCTRL      when (X"10" = REG_ADDR) else
    REG_MACADDR1     when (X"18" = REG_ADDR) else
    REG_MACADDR2     when (X"1C" = REG_ADDR) else

    REG_MDIO_CMD     when (X"20" = REG_ADDR) else
    REG_MDIO_STATUS  when (X"24" = REG_ADDR) else
    REG_MDIO_SPEED   when (X"28" = REG_ADDR) else

    REG_TXPUT        when (X"30" = REG_ADDR) else
    REG_RXGET        when (X"40" = REG_ADDR) else
    --
    X"00000000"
  ;

  APB_RDATA
  <=
    TXMEM_APB_RDATA_Q  when ("01" = REG_RANGE) else
    RXMEM_APB_RDATA_Q  when ("10" = REG_RANGE) else
    REG_RDATA
  ;
  APB_PRDATA <= std_logic_vector(APB_RDATA);

  -----------------------------------------------------------------------------
  -- APB bus clock domain (100 MHz)
  -----------------------------------------------------------------------------

  eth_apb: process (APB_CLK) -- bus writes
  begin
    if rising_edge(APB_CLK)
    then
      RXMEM_APB_RDATA_Q <= RXMEM_APB_RDATA;  -- clocked read is required for inferred memory
      if TXMEM_APB_READ = '1' -- is it possible to read back the TX MEMORY ? (allocates twice as much RAM)
      then
        TXMEM_APB_RDATA_Q <= TXMEM_APB_RDATA;  -- clocked read is required for inferred memory
      else
        TXMEM_APB_RDATA_Q <= X"00000000";
      end if;

      if APB_WRITE_CYCLE = '1' and ("00" = REG_RANGE)
      then
        case REG_ADDR
        is
          when X"08"  -- TXCTRL
          =>
            TX_SLOT_WORDS <= APB_WDATA(11 downto 0);
            TX_MANUAL_CRC <= APB_WDATA(30);
            TX_ENABLE     <= APB_WDATA(31);
          --
          when X"0C"  -- RXCTRL
          =>
            RX_SLOT_WORDS  <= APB_WDATA(11 downto 0);
            RX_IGNORE_ERR  <= APB_WDATA(29);
            RX_PROMISCUOUS <= APB_WDATA(30);
            RX_ENABLE      <= APB_WDATA(31);
          --
          when X"18"  -- MACADDR1
          =>
            MAC_ADDRESS(31 downto 0) <= APB_WDATA;
          --
          when X"1C"  -- MACADDR2
          =>
            MAC_ADDRESS(47 downto 32) <= APB_WDATA(15 downto 0);
          --

          when X"20"  -- MDIO_CMD
          =>
            MDIO_WR_DATA     <= APB_WDATA(15 downto  0);
            MDIO_REG_ADDR    <= APB_WDATA(20 downto 16);
            MDIO_PHY_ADDR    <= APB_WDATA(25 downto 21);
            MDIO_PHY_RESET   <= APB_WDATA(26);
            MDIO_WRITE_NREAD <= APB_WDATA(30);
            MDIO_START       <= APB_WDATA(31);
          --
          when X"28"  -- MDIO_SPEED
          =>
            MDIO_HALF_BIT_CLOCKS <= APB_WDATA(7 downto 0);
          --

          when X"30"  -- TXPUT
          =>
            TX_PUT_FBYTES <= APB_WDATA(23 downto 12);
            TX_PUT_FILLED <= APB_WDATA(31);
          --
          when X"40"  -- RXGET
          =>
            RX_GET_RELEASE <= not APB_WDATA(31);
          --
          when others
          =>
            null;
          --
        end case;
      end if;

      ---------------------------------------
      -- Clearing some written bits on events
      ---------------------------------------

      if TX_PUT_VALID = '0'
      then
        TX_PUT_FILLED <= '0';  -- remove the filled signal when the TX Slot becomes invalid
      end if;

      if RX_GET_FILLED = '0'
      then
        RX_GET_RELEASE <= '0';  -- remove the release signal when the RX Slot becomes empty
      end if;

      if MDIO_BUSY = '1'
      then
        MDIO_START <= '0';  -- remove start signal when busy
      end if;

    end if;  -- rising APB clock edge
  end process;

  -----------------------------------------------------------------------------
  -- TX
  -----------------------------------------------------------------------------

	tx_mem : entity work.eth_tx_mem
	generic map
	(
		ADDR_BITS => TXMEM_ADDR_BITS
	)
	port map
	(
		ETH_ADDR    => TXMEM_ETH_ADDR,   -- in unsigned(11 downto 0);  -- addresses are always 12 bit
		ETH_RDATA   => TXMEM_ETH_DATA,   -- in unsigned(31 downto 0);
		ETH_CLK     => TXDATA_CLOCK,     -- in std_logic;

		APB_ADDR    => unsigned(APB_PADDR(13 downto 2)),  -- in  unsigned(11 downto 0);
		APB_RDATA   => TXMEM_APB_RDATA,  -- out unsigned(31 downto 0);
		APB_WDATA   => APB_WDATA,        -- in unsigned(31 downto 0);
		APB_WR		  => TXMEM_APB_WR,     -- in std_logic
		APB_CLK     => APB_CLK           -- in  std_logic
	);

  tx_slot_ctrl : entity work.eth_slot_ctrl
	generic map
  (
    MEM_ADDR_BITS => TXMEM_ADDR_BITS
  )
  port map
  (
    PUT_VALID			=> TX_PUT_VALID,
    PUT_ADDR      => TX_PUT_ADDR,
    PUT_FILLED    => TX_PUT_FILLED,
    PUT_FBYTES    => TX_PUT_FBYTES,

    GET_ADDR      => TX_GET_ADDR,
    GET_FILLED    => TX_GET_FILLED,
    GET_FBYTES    => TX_GET_FBYTES,
    GET_RELEASE   => TX_GET_RELEASE,

    SLOT_WORDS    => TX_SLOT_WORDS,
    ENABLE        => TX_ENABLE,

    APB_CLK 			=> APB_CLK
  );

  tx_data : entity work.eth_tx_data
  port map
  (
		SLOT_FILLED 	  => TX_GET_FILLED,  -- in  std_logic;  -- data synchronization ? (APB clock)
		SLOT_ADDR       => TX_GET_ADDR,    -- in  unsigned(11 downto 0);
		SLOT_FBYTES     => TX_GET_FBYTES,  -- in  unsigned(11 downto 0);
		SLOT_RELEASE    => TX_GET_RELEASE, -- out std_logic;  -- handshake with SLOT_FILLED

		MEM_ADDR        => TXMEM_ETH_ADDR,  -- out unsigned(11 downto 0);
		MEM_DATA        => TXMEM_ETH_DATA,  -- in  unsigned(31 downto 0);

		MANUAL_CRC      => TX_MANUAL_CRC,   -- in std_logic;

		ETH_DATA        => TXDATA,          -- out  unsigned(7 downto 0);
		ETH_DATA_VALID  => TXDATA_VALID,    -- out  std_logic;
		ETH_DATA_CLOCK  => TXDATA_CLOCK     -- in  std_logic
  );

  mii_tx : entity work.eth_gmii_tx
  port map
  (
    GMII_CLK       => ETH_TX_CLK,     -- in  std_logic;
    GMII_TXEN      => ETH_TXEN,       -- out std_logic;
    GMII_TXD		   => ETH_TX_DATA,    -- out unsigned(7 downto 0);

    ETH_DATA       => TXDATA,        -- in  unsigned(7 downto 0);  -- without preamble
    ETH_DATA_VALID => TXDATA_VALID,  -- in  std_logic;
    ETH_DATA_CLK   => TXDATA_CLOCK   -- out std_logic
  );

  -----------------------------------------------------------------------------
  -- RX
  -----------------------------------------------------------------------------

	rx_mem : entity work.eth_rx_mem
	generic map
	(
		ADDR_BITS => RXMEM_ADDR_BITS
	)
	port map
	(
		ETH_ADDR    => RXMEM_ETH_ADDR,  -- in unsigned(11 downto 0);  -- addresses are always 12 bit
		ETH_WDATA   => RXMEM_ETH_DATA,  -- in unsigned(31 downto 0);
		ETH_WR      => RXMEM_ETH_WR,    -- in std_logic;
		ETH_CLK     => RXDATA_CLOCK,    -- in std_logic;

		APB_ADDR    => unsigned(APB_PADDR(13 downto 2)), -- in  unsigned(11 downto 0);
		APB_RDATA   => RXMEM_APB_RDATA, -- out unsigned(31 downto 0);
		APB_CLK     => APB_CLK          -- in  std_logic
	);

  rx_slot_ctrl : entity work.eth_slot_ctrl
	generic map
	(
		MEM_ADDR_BITS => RXMEM_ADDR_BITS
	)
  port map
  (
    PUT_VALID			=> RX_PUT_VALID,
    PUT_ADDR      => RX_PUT_ADDR,
    PUT_FILLED    => RX_PUT_FILLED,
    PUT_FBYTES    => RX_PUT_FBYTES,

    GET_ADDR      => RX_GET_ADDR,
    GET_FILLED    => RX_GET_FILLED,
    GET_FBYTES    => RX_GET_FBYTES,
    GET_RELEASE   => RX_GET_RELEASE,

    SLOT_WORDS    => RX_SLOT_WORDS,
    ENABLE        => RX_ENABLE,

    APB_CLK 			=> APB_CLK
  );

  rx_data : entity work.eth_rx_data
  port map
  (
    SLOT_VALID		  => RX_PUT_VALID,  -- in  std_logic;
    SLOT_ADDR       => RX_PUT_ADDR,   -- in  unsigned(11 downto 0);
    SLOT_WORDS      => RX_SLOT_WORDS, -- in  unsigned(11 downto 0);
    SLOT_FILLED     => RX_PUT_FILLED, -- out std_logic;
    SLOT_FBYTES     => RX_PUT_FBYTES, -- out unsigned(11 downto 0);

    MEM_ADDR        => RXMEM_ETH_ADDR, -- out unsigned(11 downto 0);
    MEM_DATA        => RXMEM_ETH_DATA, -- out unsigned(31 downto 0);
    MEM_WR          => RXMEM_ETH_WR,   -- out unsigned(11 downto 0);

    ERR_OVF_TOG     => open, -- out std_logic;
    ERR_CRC_TOG     => open, -- ERR_TOG_CRC, -- out std_logic;

    MAC_ADDR        => MAC_ADDRESS, -- in  unsigned(47 downto 0);
    MAC_ADDR_FILT   => not RX_PROMISCUOUS,  -- in  std_logic;

    ETH_DATA        => RXDATA,          -- in  unsigned(7 downto 0);
    ETH_DATA_VALID  => RXDATA_VALID,    -- in  std_logic;  -- does this require synchronization ?
    ETH_DATA_CLOCK  => RXDATA_CLOCK     -- in  std_logic
  );

  mii_rx : entity work.eth_gmii_rx
  port map
  (
    GMII_CLK      => ETH_RX_CLK, -- in  std_logic;
    GMII_RXDV     => ETH_RXDV,   -- in std_logic;
    GMII_RXD		  => unsigned(ETH_RXD),  -- in unsigned(7 downto 0);

    ETH_DATA      => RXDATA,        -- out unsigned(7 downto 0);  -- without preamble
    ETH_DVALID    => RXDATA_VALID,  -- out std_logic;
    ETH_DCLK      => RXDATA_CLOCK   -- out std_logic
  );

  -----------------------------------------------------------------------------
  -- MDIO
  -----------------------------------------------------------------------------

  mdio : entity work.eth_mdio
  port map
  (
		ETH_MDC	    => ETH_MDC,   -- out   std_logic
		ETH_MDIO    => ETH_MDIO,  -- inout std_logic

		HALF_BIT_CLKS  => MDIO_HALF_BIT_CLOCKS,

		START       => MDIO_START,
		WRITE_NREAD => MDIO_WRITE_NREAD, -- in  std_logic
		PHY_ADDR    => MDIO_PHY_ADDR,    -- in  unsigned(4 dowto 0)
		REG_ADDR    => MDIO_REG_ADDR,    -- in  unsigned(4 dowto 0)
		WR_DATA     => MDIO_WR_DATA,     -- in  unsigned(15 downto 0)
		RD_DATA     => MDIO_RD_DATA,     -- out unsigned(15 downto 0)

		BUSY       	=> MDIO_BUSY,

    APB_CLK			=> APB_CLK
  );


end architecture;
