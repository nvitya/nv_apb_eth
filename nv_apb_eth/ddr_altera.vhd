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
-- file:     ddr_altera.vhd
-- brief:    DDR blocks using Altera internals
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity ddr_input is
generic
(
  DATA_WIDTH : natural
);
port
(
  DATA_IN    : in  unsigned(DATA_WIDTH - 1 downto 0);
  DATA_OUT_R : out unsigned(DATA_WIDTH - 1 downto 0);
  DATA_OUT_F : out unsigned(DATA_WIDTH - 1 downto 0);  -- one clock delayed !
  CLOCK      : in  std_logic
);
end entity;

architecture rtl of ddr_input
is
  signal DOUT_R : std_logic_vector(3 downto 0);
  signal DOUT_F : std_logic_vector(3 downto 0);
begin

  DATA_OUT_R <= unsigned(DOUT_R);
  DATA_OUT_F <= unsigned(DOUT_F);

  ddri : component altddio_in
  generic map
  (
    width => DATA_WIDTH
  )
  port map
  (
    datain    => std_logic_vector(DATA_IN),
    dataout_h => DOUT_R,
    dataout_l => DOUT_F,
    inclock   => CLOCK
  );
end architecture;

-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity ddr_output is
generic
(
  DATA_WIDTH : natural
);
port
(
  DATA_IN_R  : in  unsigned(DATA_WIDTH - 1 downto 0);
  DATA_IN_F  : in  unsigned(DATA_WIDTH - 1 downto 0);
  DATA_OUT   : out unsigned(DATA_WIDTH - 1 downto 0);
  CLOCK      : in  std_logic
);
end entity;

architecture rtl of ddr_output
is
  signal DOUT_SLV : std_logic_vector(DATA_WIDTH - 1 downto 0);
begin
  DATA_OUT <= unsigned(DOUT_SLV);

  ddro : component altddio_out
  generic map
  (
    width => DATA_WIDTH
  )
  port map
  (
    datain_h  => std_logic_vector(DATA_IN_R),
    datain_l  => std_logic_vector(DATA_IN_F),
    dataout   => DOUT_SLV,
    outclock  => CLOCK
  );
end architecture;