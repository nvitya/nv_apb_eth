# nv_apb_eth
The NV APB Ethernet is a simple ethernet solution for FPGAs using only the simple APB bus interface.

## Main Features
 * Simple APB only interface for soft-CPU control
 * no bus mastering
 * VHDL implementation
 * Multi packet buffering up to 8 packets
 * Selectable TX and RX memory size between 4 kByte - 16 kByte
 * Selectable TX and RX maximum packet size (slot size)
 * Currently supported/tested phy protocols: GMII (soon can be expected: RGMII, RMII, MII)

## How it Works
The NV APB Ethernet contains two relatively large internal buffers for ethernet packet sending and receiving: TXMEM and RXMEM. Their size can be seleced at syntesis time between 4 kByte and 16 kByte. Both RXMEM and TXMEM are divided into fixed-size slots. The slot size can be selected by a register, which determines the maximal length of the transmit and receive packets. The maximal standard ethernet packet length is 1536 Bytes (including crc). If the slot size is set to 1536 bytes = 384 32-bit words then having 4 kByte RXMEM results in two slots. Setting the slot size to 1364 Bytes gives 3 slots. Maximum 8 slots are supported, also there is no reason to set the slot size smaller than 512 Bytes for 4 kByte RX/TX memory.

At the RX packets the CRC (last four bytes of the ethernet packet) must fit into the RX slot too, otherwise the packet will be dropped with OVF (overflow) error.

The RX and TX memories are organized into 32-bit words.
The RX memory is read-only from the CPU side (APB bus), write-only from the Ethernet side. The TX memory is write only from the CPU side and it is read only from the Ethernet side. (It is possible to make the TX memory CPU readable too, but then it will use twice as much RAM.)

The slot controller coordinates the read and write positions and slot availibility.

At RX side there is an RXGET register, which tells if a filled slot is available, when yes, then at which address the packet data starts and how many bytes were actually  filled. Writing zero into the RXGET register releases the filled slot and makes it available for another packet receival, and the  RXGET register advances to the next filled slot.

At TX side TXPUT register tells if an empty slot is available and its TXMEM word address. Writing the FILLED flag and the FBYTES field into the TXPUT register will schedule the packet for sending and the TXPUT register advances to the next empty slot.

The NV APB ETH also provides an MDIO module to configure the Ethernet phy and to poll its status.
