// Copyright (c) 2011, XMOS Ltd., All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

//-*- mode: xc;-*-

#include "fifo.h"

void init_fifo(fifo_t &fifo) {
  for(int channel = 0; channel < CHANNELS; channel++){
    fifo.rdptr[channel] = 0;
    fifo.wrptr[channel] = 0;
    fifo.d_cnt[channel] = 0;
  }
}

int add_to_fifo(fifo_t &fifo, int channel, int data) {
  // Save the old pointer for the buffer full code path, but
  // continue assuming non-full for speed.
  register int old_ptr = fifo.wrptr[channel];
  fifo.wrptr[channel]++;
  if(fifo.wrptr[channel] >= FIFOSIZE)
      fifo.wrptr[channel] = 0;

  // Check the read and write ptrs aren't touching
  if (fifo.wrptr[channel] != fifo.rdptr[channel]) {
    fifo.buf[channel][fifo.wrptr[channel]] = data;
    fifo.d_cnt[channel]++;
    return 1;
  }

  // fifo is full, drop the data and move the ptr back
  fifo.wrptr[channel] = old_ptr;
  return 0;
}

int get_from_fifo(fifo_t &fifo, int channel, int &data)
{
  if (fifo.rdptr[channel] == fifo.wrptr[channel]) {
    data = 0;
    //buffer is empty
    return 0;
  }

  data = fifo.buf[channel][fifo.rdptr[channel]];

  fifo.rdptr[channel]++;
  if (fifo.rdptr[channel] >= FIFOSIZE)
    fifo.rdptr[channel] = 0;
  fifo.d_cnt[channel]--;
  return 1;
}

int fifo_empty(fifo_t &fifo) {
  return (fifo.rdptr[0] == fifo.wrptr[0]);
}

int is_fifo_full(fifo_t &fifo, int channel) {
    return (fifo.d_cnt[channel] > FIFOSIZE-2);
}
