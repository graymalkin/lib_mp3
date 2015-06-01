// Copyright (c) 2011, XMOS Ltd., All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

#ifndef __fifo_h__
#define __fifo_h__

/*************************************************************************
 * A very simple fifo library.
 *
 * This library provides a simple fifo to use in example code.
 * The fifo stores FIFOSIZE members where each member is an array
 * of DATASIZE words.
 *
 *************************************************************************/

/** The size of the fifo */
#define FIFOSIZE 786
#define CHANNELS 2

/** The datatype representing a fifo */
typedef struct fifo_t {
  int rdptr[CHANNELS];
  int wrptr[CHANNELS];
  int buf[CHANNELS][FIFOSIZE];
  int d_cnt[CHANNELS];
} fifo_t;

typedef interface fifo_if {
    void init();
    int  fifo_pop(int channel);
    void fifo_push(int value, int channel);
    int fifo_full(int channel);
} fifo_if;

void init_fifo(fifo_t &fifo);

int add_to_fifo(fifo_t &fifo, int channel, int data);

int get_from_fifo(fifo_t &fifo, int channel, int &data);

int is_fifo_full(fifo_t &fifo, int channel);
#endif // __fifo_h__
