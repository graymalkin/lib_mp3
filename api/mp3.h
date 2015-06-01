/**
* Module:  xmos_mp3
* File:    mp3.h
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

#ifndef _MP3_H
#define _MP3_H

#include <syscall.h>

#include <stdio.h>     //file operations
#include <string.h>    //memory functions


#define SIM

#define LAYER_3_ONLY
#define SAMPLES_16_BITS


#define false 0
#define true 1

#define SIZE_OF_FRAME  4660

#define MAX_RESERVOIR_SIZE 1023

#ifdef SIM
# define MAX_FRAME_SIZE 2880
#else
# define MAX_FRAME_SIZE 1440//1440
#endif

#define BUFFER_GUARD 16

#define BUFFER_SIZE (MAX_RESERVOIR_SIZE + MAX_FRAME_SIZE + BUFFER_GUARD) 

#define ASSERT_ERROR 	0x8000
#define PCM_WRITE_ERROR 0x8001
#define MP3_READ_ERROR 	0x8002

#define assert(x)	do { if (!(x)) _exit(ASSERT_ERROR); } while (0)

#define SIZEOF_INT 4
#define SIZEOF_LONG 8
#define SIZEOF_LONG_LONG 8


enum mad_flow {
  MAD_FLOW_CONTINUE = 0x0000,	/* continue normally */
  MAD_FLOW_STOP     = 0x0010,	/* stop decoding normally */
  MAD_FLOW_BREAK    = 0x0011,	/* stop decoding and signal an error */
  MAD_FLOW_IGNORE   = 0x0020	/* ignore the current frame */
};


#define DEBUG
//#define DEBUG_DECODER 	    TRUE		//decoder.c
#define DEBUG_TEST 			TRUE 		//test.xc
//#define DEBUG_MP3TOP		TRUE
//#define DEBUG_FRAME 		TRUE		//frame.c

// IO Commands
#define _C_START 		1
#define _C_RESTART  	2
#define _C_FINISH		4
#define _C_READ			8
#define	_C_WRITE		16
#define _C_ERROR	    32
#define _C_EOF			64


#include <print.h>

#ifdef DEBUG 
	#define myprintstr(s) printstr(s)
	#define myprinthex(x) printhex(x)
#else	
	#define myprintstr(s) {;}
	#define myprinthex(x) {;}
#endif



#endif
