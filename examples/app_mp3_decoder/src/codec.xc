/*
 * codec.xc
 *
 *  Created on: 21 May 2015
 *      Author: simonc
 */

#include <i2c.h>
#include <i2s.h>
#include <gpio.h>
#include <fifo.h>

#include "codec.h"

void cs4270_reset(client i2c_master_if i2c, uint8_t device_addr,
                 unsigned sample_frequency, unsigned master_clock_frequency,
                 enum codec_mode_t codec_mode)
{
  /* Set power down bit in the CODEC over I2C */
  i2c.write_reg(device_addr, CODEC_DEV_ID_ADDR, 0x01);

  /* Now set all registers as we want them */
  if (codec_mode == CODEC_IS_I2S_SLAVE) {
    /* Mode Control Reg:
       Set FM[1:0] as 11. This sets Slave mode.
       Set MCLK_FREQ[2:0] as 010. This sets MCLK to 512Fs in Single,
       256Fs in Double and 128Fs in Quad Speed Modes.
       This means 24.576MHz for 48k and 22.5792MHz for 44.1k.
       Set Popguard Transient Control.
       So, write 0x35. */
    i2c.write_reg(device_addr, CODEC_MODE_CTRL_ADDR, 0x35);

  } else {
    /* In master mode (i.e. Xcore is I2S slave) to avoid contention
       configure one CODEC as master one the other as slave */

    /* Set FM[1:0] Based on Single/Double/Quad mode
       Set MCLK_FREQ[2:0] as 010. This sets MCLK to 512Fs in Single, 256Fs in Double and 128Fs in Quad Speed Modes.
       This means 24.576MHz for 48k and 22.5792MHz for 44.1k.
       Set Popguard Transient Control.*/

    unsigned char val = 0b0101;

    if(sample_frequency < 54000) {
      // | with 0..
    } else if(sample_frequency < 108000) {
      val |= 0b00100000;
    } else  {
      val |= 0b00100000;
    }
    i2c.write_reg(device_addr, CODEC_MODE_CTRL_ADDR, val);
  }

  /* ADC & DAC Control Reg:
     Leave HPF for ADC inputs continuously running.
     Digital Loopback: OFF
     DAC Digital Interface Format: I2S
     ADC Digital Interface Format: I2S
     So, write 0x09. */
  i2c.write_reg(device_addr, CODEC_ADC_DAC_CTRL_ADDR, 0b00011001);

  /* Transition Control Reg:
     No De-emphasis. Don't invert any channels.
     Independent vol controls. Soft Ramp and Zero Cross enabled.*/
  i2c.write_reg(device_addr, CODEC_TRAN_CTRL_ADDR, 0x60);

  /* Mute Control Reg: Turn off AUTO_MUTE */
  i2c.write_reg(device_addr, CODEC_MUTE_CTRL_ADDR, 0x00);

  /* DAC Chan A Volume Reg:
     We don't require vol control so write 20 (-10dB) */
  i2c.write_reg(device_addr, CODEC_DACA_VOL_ADDR, 20);

  /* DAC Chan B Volume Reg:
     We don't require vol control so write 20 (-10dB)  */
  i2c.write_reg(device_addr, CODEC_DACB_VOL_ADDR, 20);

  /* Clear power down bit in the CODEC over I2C */
  i2c.write_reg(device_addr, CODEC_PWR_CTRL_ADDR, 0x00);
}

void i2s_server(server i2s_callback_if i2s,
        client i2c_master_if i2c,
        client output_gpio_if codec_reset,
        client output_gpio_if clock_select,
        port p_gpio,
        client interface fifo_if i_fifo)
{
  while (1) {
    select {
      case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
        /* Set CODEC in reset */
        codec_reset.output(1);
        delay_milliseconds(500);

        codec_reset.output(0);


        /* Set master clock select appropriately */
        if ((SAMPLE_FREQUENCY % 22050) == 0) {
          clock_select.output(0);
        }else {
          clock_select.output(1);
        }

        /* Hold in reset for 2ms while waiting for MCLK to stabilise */
        delay_milliseconds(2);

        /* CODEC out of reset */
        codec_reset.output(1);


        i2s_config.mode = I2S_MODE_I2S;
        i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/SAMPLE_FREQUENCY)/64;

        delay_milliseconds(2000);

        // Reset both codecs on the slice as slaves.
        cs4270_reset(i2c, CODEC_I2C_DEVICE_ADDR,
                SAMPLE_FREQUENCY, MASTER_CLOCK_FREQUENCY,
                CODEC_IS_I2S_SLAVE);
        cs4270_reset(i2c, CODEC_I2C_DEVICE_ADDR+1,
                SAMPLE_FREQUENCY, MASTER_CLOCK_FREQUENCY,
                CODEC_IS_I2S_SLAVE);
        printstrln("I2S Reset complete.");
        break;

      case i2s.restart_check() -> i2s_restart_t restart:
        restart = I2S_NO_RESTART;
        break;

      case i2s.receive(size_t index, int32_t sample):
        break;

      case i2s.send(size_t channel) -> int32_t sample:
        // We currently only handle 2 channels, this could be expanded.
        if(channel < 2)
            sample = i_fifo.fifo_pop(channel);
        else
            sample = 0x00;
        break;
    }
  }
};
