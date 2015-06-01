/*
 * codec.h
 *
 *  Created on: 21 May 2015
 *      Author: Simon Cooksey
 *
 *  -*- mode: xc;-*-
 */


#ifndef CODEC_H_
#define CODEC_H_

#define SAMPLE_FREQUENCY 44100
#define MASTER_CLOCK_FREQUENCY 24576000
#define CODEC_I2C_DEVICE_ADDR 0x48

#define MCLK_FREQUENCY_48  24576000
#define MCLK_FREQUENCY_441 22579200

enum codec_mode_t {
  CODEC_IS_I2S_MASTER,
  CODEC_IS_I2S_SLAVE
};

#define CODEC_DEV_ID_ADDR           0x01
#define CODEC_PWR_CTRL_ADDR         0x02
#define CODEC_MODE_CTRL_ADDR        0x03
#define CODEC_ADC_DAC_CTRL_ADDR     0x04
#define CODEC_TRAN_CTRL_ADDR        0x05
#define CODEC_MUTE_CTRL_ADDR        0x06
#define CODEC_DACA_VOL_ADDR         0x07
#define CODEC_DACB_VOL_ADDR         0x08


#endif /* CODEC_H_ */
