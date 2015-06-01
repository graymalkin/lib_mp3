/*
 * app_mp3_decoder.h
 *
 *  Created on: 11 May 2015
 *      Author: Simon Cooksey
 *
 *  -*- mode: xc;-*-
 */


#ifndef APP_MP3_DECODER_
#define APP_MP3_DECODER_

#define ETHERNET_SMI_PHY_ADDRESS (0)

#define ETHERNET_DEFAULT_TILE tile[0]
#define PORT_ETH_RXCLK  on ETHERNET_DEFAULT_TILE: XS1_PORT_1J
#define PORT_ETH_RXD    on ETHERNET_DEFAULT_TILE: XS1_PORT_4E
#define PORT_ETH_TXD    on ETHERNET_DEFAULT_TILE: XS1_PORT_4F
#define PORT_ETH_RXDV   on ETHERNET_DEFAULT_TILE: XS1_PORT_1K
#define PORT_ETH_TXEN   on ETHERNET_DEFAULT_TILE: XS1_PORT_1L
#define PORT_ETH_TXCLK  on ETHERNET_DEFAULT_TILE: XS1_PORT_1I
#define PORT_ETH_MDIO   on ETHERNET_DEFAULT_TILE: XS1_PORT_1M
#define PORT_ETH_MDC    on ETHERNET_DEFAULT_TILE: XS1_PORT_1N
#define PORT_ETH_INT    on ETHERNET_DEFAULT_TILE: XS1_PORT_1O
#define PORT_ETH_ERR    on ETHERNET_DEFAULT_TILE: XS1_PORT_1P
on ETHERNET_DEFAULT_TILE: clock eth_rxclk       = XS1_CLKBLK_3;
on ETHERNET_DEFAULT_TILE: clock eth_txclk       = XS1_CLKBLK_4;
on ETHERNET_DEFAULT_TILE: otp_ports_t otp_ports = OTP_PORTS_INITIALIZER;
on ETHERNET_DEFAULT_TILE: port p_eth_dummy      = XS1_PORT_8C; // May be incorrect.
port p_eth_rxclk = PORT_ETH_RXCLK;
port p_eth_rxd   = PORT_ETH_RXD;
port p_eth_txd   = PORT_ETH_TXD;
port p_eth_rxdv  = PORT_ETH_RXDV;
port p_eth_txen  = PORT_ETH_TXEN;
port p_eth_txclk = PORT_ETH_TXCLK;
port p_eth_rxerr = PORT_ETH_ERR;
port p_smi_mdio  = PORT_ETH_MDIO;
port p_smi_mdc   = PORT_ETH_MDC;
#define ETH_RX_BUFFER_SIZE_WORDS 4096
on tile[1]: out buffered port:32 p_dout[2] = {XS1_PORT_1D, XS1_PORT_1H};
on tile[1]: in buffered port:32 p_din[2] = {XS1_PORT_1K, XS1_PORT_1L};
on tile[1]: port p_mclk = XS1_PORT_1E;
on tile[1]: out buffered port:32 p_bclk = XS1_PORT_1A;
on tile[1]: out buffered port:32 p_lrclk = XS1_PORT_1I;
on tile[1]: clock mclk = XS1_CLKBLK_1;
on tile[1]: clock bclk = XS1_CLKBLK_2;
on tile[1]: port p_i2c = XS1_PORT_4F;
on tile[1]: port p_gpio = XS1_PORT_4E;


// Initialise an IP Config to use DHCP
xtcp_ipconfig_t ipconfig = {
        { 0,   0,   0,   0 },   // ip address (eg 192, 168, 0,   2) 0.0.0.0 auto
        { 0,   0,   0,   0 },   // netmask    (eg 255, 255, 255, 0)
        { 0,   0,   0,   0 }    // gateway    (eg 192, 168, 0,   1)
};


struct DEMO {
    unsigned char buffer[BUFFER_SIZE];
    unsigned long length;
    unsigned mp3_eof;
    unsigned frameCount;
};


void i2s_server(server i2s_callback_if i_i2s,
                client i2c_master_if i2c,
                client output_gpio_if codec_reset,
                client output_gpio_if clock_select,
                port p_gpio,
                client interface fifo_if i_fifo);
[[distributable]]
void fifo(server interface fifo_if i_fifo[2]);
int demo(chanend mp3_chan,
         chanend pcm_chan,
         chanend chan_httpc,
         client interface fifo_if i_fifo);
void http_client(chanend c_xtcp[], chanend chan_httpc);


#endif //APP_MP3_DECODER_
