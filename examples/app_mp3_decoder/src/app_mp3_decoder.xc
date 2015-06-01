/*
 * app_mp3_decoder.xc
 *
 *  Created on: 6 May 2015
 *      Author: Simon Cooksey
 *
 *  -*- mode: xc;-*-
 */

#include <xs1.h>

#include <platform.h>
#include <i2c.h>
#include <i2s.h>
#include <gpio.h>
#include <xscope.h>

// Libraries
#include "ethernet.h"
#include "mp3.h"
#include "smi.h"
#include "xtcp.h"

// Headers
#include "fifo.h"
#include "codec.h"
#include "app_mp3_decoder.h"
#include "http_stream.h"

fifo_t samples;

static char gpio_pin_map[2] = {2, 1};

on tile[1]: port dumpy = XS1_PORT_16A;
int main() {
    chan chan_in, chan_out, chan_httpc;
    chan c_xtcp[1];
    mii_if i_mii;
    smi_if i_smi;
    interface i2s_callback_if i2s;
    interface i2c_master_if i_i2c[1];
    interface output_gpio_if i_gpio[2];
    interface fifo_if i_fifo[2];

    par {
        on tile[1]:
        {
            configure_clock_src(mclk, p_mclk);
            start_clock(mclk);
            i2s_master(i2s, p_dout, 2, p_din, 2, p_bclk, p_lrclk, bclk, mclk);
        }

        on tile[1]:demo(chan_in, chan_out, chan_httpc, i_fifo[0]);
        on tile[1]:i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0x0);
        on tile[1]:output_gpio(i_gpio, 2, p_gpio, gpio_pin_map);
        on tile[1]:i2s_server(i2s, i_i2c[0], i_gpio[0], i_gpio[1], dumpy, i_fifo[1]);
        on tile[1]:[[distribute]]fifo(i_fifo);

        // The main ethernet/tcp server
        on ETHERNET_DEFAULT_TILE: mii(i_mii,
                                      p_eth_rxclk, p_eth_rxerr, p_eth_rxd, p_eth_rxdv, p_eth_txclk,
                                      p_eth_txen, p_eth_txd, p_eth_dummy, eth_rxclk, eth_txclk,
                                      ETH_RX_BUFFER_SIZE_WORDS);
        on ETHERNET_DEFAULT_TILE: smi(i_smi, p_smi_mdio, p_smi_mdc);
        on ETHERNET_DEFAULT_TILE: xtcp(c_xtcp, 1, i_mii, null, null,
                                       null, i_smi, ETHERNET_SMI_PHY_ADDRESS,
                                       null, otp_ports, ipconfig);
        on ETHERNET_DEFAULT_TILE: http_client(c_xtcp, chan_httpc);

        // Apparently having this last might remove stack-size bounds
        on tile[1]:mp3_decode(chan_in, chan_out);
    }
    return 0;
}

[[distributable]]
void fifo(server interface fifo_if i_fifo[2])
{
    fifo_t data;
    while(1)
    {
        select
        {
            case i_fifo[int k].init():
                init_fifo(data);
                for(int channel = 0; channel < 2; channel++)
                    for(int i = 0; i < FIFOSIZE; i++)
                        data.buf[channel][i] = 0;
                break;
            case i_fifo[int k].fifo_push(int value, int channel):
                add_to_fifo(data, channel, value);
                break;
            case i_fifo[int k].fifo_pop(int channel) -> int value:
                if(!get_from_fifo(data, channel, value))
                    value = 0x0;
                break;
            case i_fifo[int k].fifo_full(int channel) -> int result:
                result = is_fifo_full(data, channel);
                break;
        }
    }
}

int demo(chanend chan_mp3, chanend chan_pcm, chanend chan_httpc, client interface fifo_if i_fifo) {
#ifndef SIM
#error check this
    wait(3);
#endif
    unsigned command, count, result;
    unsigned sample_cnt, channels, sample, i, mp3_finish = 0, pcm_finish = 0;
    struct DEMO data;
    int frameCount;
    i_fifo.init();

# ifdef DEBUG_TEST
#  ifdef SIM
            myprintstr("test: Starting mp3 decoder in SIM mode...\n");
#  else
    myprintstr("test: Starting mp3 decoder in LIVE mode...\n");
#  endif
# endif

    while (!pcm_finish || !mp3_finish) {
        select {
            case chan_mp3 :> command:
            switch(command) {
                case _C_READ:
                    unsigned char val;

                    chan_mp3 :> count;
                    chan_httpc <: count;

                    chan_httpc :> result;
//                    printstr("*** count: "); printintln(count);
//                    printstr("*** read:  "); printintln(result);

                    if(result > 0) {
                        chan_mp3 <: _C_WRITE;
                        chan_mp3 <: result;
                        for(i = 0; i < result; i++) {
                            chan_httpc :> val;
                            chan_mp3 <: (unsigned)val;
                        }
                    }
                    else
                    {
                        chan_mp3 <: _C_EOF;
                    }
                    break;

                case _C_FINISH:
# ifdef DEBUG_TEST
                myprintstr("test: mp3_finish = 1\n");
# endif
                mp3_finish = 1;
                break;
            }
            break;
            case chan_pcm :> command:
                switch(command) {
                    case _C_WRITE:
                        chan_pcm :> sample_cnt;
                        chan_pcm :> channels;
                        chan_pcm <: _C_READ;
                        for(i = 0; i < sample_cnt; i+=1)
                        {
                            // 16bit pcm data
                            chan_pcm :> sample;
                            do { delay_microseconds(1); } while(i_fifo.fifo_full(0));
                            i_fifo.fifo_push(sample, 0);

                            if(channels == 2) {
                                chan_pcm :> sample;
                                do { delay_microseconds(1); } while(i_fifo.fifo_full(1));
                                i_fifo.fifo_push(sample, 1);
                            }
                        }
                        break;

                    case _C_FINISH:
                        chan_pcm :> frameCount;

                        #ifdef DEBUG_TEST
                        myprintstr("test: pcm_finish = 1\n");
                        myprintstr("test: decoded ");
                        myprinthex(frameCount);
                        myprintstr(" frames.\n");
                        #endif

                        pcm_finish = 1;
                        break;
                }
                break;
        }
    }
#ifdef DEBUG_TEST
    myprintstr("test: demo finish\n");
#endif
    return 0;
}

void http_client(chanend c_xtcp[], chanend chan_httpc){
    xtcp_connection_t conn;
    while(1){
        select{
            case xtcp_event(c_xtcp[0], conn):
            {
                handle_http_event(c_xtcp[0], conn, chan_httpc);
                break;
            }
        }
    }
}
