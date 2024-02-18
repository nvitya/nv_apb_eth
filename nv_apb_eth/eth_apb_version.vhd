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
-- file:     eth_apb_version.vhd
-- brief:    Version number and change log
-- created:  2024-02-16
-- authors:  nvitya

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package version is

--                                                       II_JN_CCCC, II=module id, J=Major version, N=Minor, CC=Change increment
constant NV_ETH_APB_VERSION : unsigned(31 downto 0) := X"E0_10_0006";

/* version description :

10_0006:
  - Finally working RGMII TX (with proper clock skew)
10_0005:
  - IGNORE_RX_ERR handling
10_0004:
  - TXMEM read disabled
  - SLOT count fix
10_0003:
  - RXMEM APB data read fix
10_0002:
  - RXGET.RELEASE polarity fix
10_0001:
  - Initial version

*/

end package;
