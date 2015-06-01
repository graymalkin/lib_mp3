/**
* Module:  xmos_mp3
* File:    mp3topxc.xc
*
* The copyrights, all other intellectual and industrial
* property rights are retained by XMOS and/or its licensors.
* Terms and conditions covering the use of this code can
* be found in the Xmos End User License Agreement.
*
* Copyright XMOS Ltd 2009
*
* In the case where this code is a modification of existing code
* under a separate license, the separate license terms are shown
* below. The modifications to the code are still covered by the
* copyright notice above.
*
**/

#include "mp3.h"

unsigned mp3_finish(chanend mp3_chan, chanend pcm_chan, int frameCount){
  mp3_chan <: _C_FINISH;
  pcm_chan <: _C_FINISH;
  pcm_chan <: frameCount;
  return 0;
}

unsigned mp3_read(unsigned char ptr[], unsigned count, chanend mp3_chan){
  unsigned i;
  unsigned get, command, data_item;
  unsigned result;
  mp3_chan <: _C_READ;

  mp3_chan <: count;

  mp3_chan :> command;

  if(command == _C_WRITE){
    mp3_chan :> get;
    for(i = 0; i < get; i+=1){
      mp3_chan :> data_item;
      ptr[i] = data_item & 0xff;
    }
    result = get;
  } else {
    result = -1;
  }
  return result;
}

#ifdef SAMPLES_16_BITS
int pcm_write(signed short scaled_left_ch[], signed short scaled_right_ch[], unsigned nsamples, unsigned nchannels, chanend pcm_chan)
#else
int pcm_write(signed int const left_ch[], signed int const right_ch[], unsigned nsamples, unsigned nchannels, chanend pcm_chan)
#endif
{
  signed short sample;
  unsigned i = 0, command;
  pcm_chan <: _C_WRITE;
  pcm_chan <: nsamples;
  pcm_chan <: nchannels;

  pcm_chan :> command;

  if(command == _C_READ){
    while (nsamples--) {
      /* output sample(s) in 16-bit signed little-endian PCM */

#ifdef SAMPLES_16_BITS
      sample = scaled_left_ch[i];
      pcm_chan <: (unsigned)sample;

      if (nchannels == 2) {
        sample = scaled_right_ch[i];
        pcm_chan <: (unsigned)sample;
      }
#else
      sample = left_ch[i];
      pcm_chan <: (unsigned)sample;

      if (nchannels == 2) {
        sample = right_ch[i];
        pcm_chan <: (unsigned)sample;
      }
#endif
      i+=1;
    }
  }
  else {
    return -1;
  }

  return 0;
}
