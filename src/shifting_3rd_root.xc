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

#ifndef GCC
#include <xs1.h>
#include <xclib.h>
#endif

#include <stdio.h>
#include <stdlib.h>


#ifndef GCC
timer t;

#define EXACT

unsigned readTime(){
  unsigned time;
  t :> time;
  return time;
}
#else
unsigned readTime();
#endif

#ifdef GCC
unsigned clz(unsigned n){
  
  int i;
  unsigned count = 0;
  for(i = 31; i >= 0; i--){
    if(n >> i == 0)
      count++;
    else
      break;
  }
  
  return count;
}
#endif

#if defined(EXACT)
unsigned short history[210] = {
#include "history.h"
};

unsigned doRound(unsigned target){

  //binary search of the history array
  unsigned current = 210 >> 1;
  unsigned max = 209;
  unsigned min = 0;

  unsigned iTemp = 0, temp;

  while(1){

    iTemp = history[current] >> 1;

    temp = current;

    if(iTemp == target)
      return ((history[current] & 0x1) + 1);//return either 1 or 2
    else if(current == min || current == max)
      return 0;
    else if(iTemp < target){

      min = current;
      current = (current + max) >> 1;
      if(current == temp )
        current++;

    }
    else{

      max = current;
      current = (current + min) >> 1;
      if(current == temp)
        current--;
    
    }

  }
  return 0;

}

unsigned char ROUND = 0xbb; 
#elif defined(ACCURATE)
unsigned char ROUND = 0x80;
#else 
#error "Need to define either ACCURATE or EXACT"
#endif

//this will return a struct fixedfloat format
unsigned shifting_3rd_root(unsigned x) {

    unsigned answer = 0;
    unsigned bits = 0;
    unsigned test;


    unsigned bl, bh;
    unsigned th, tl;
  
    unsigned ah, al;
    unsigned mantissa;
    unsigned exponent;

    unsigned expo_fix = 0;
    unsigned x_old = x;

    int i;

#ifdef GCC 
    unsigned long temp;
#endif
    unsigned temp2;


    switch(clz(x)){
  
      case 17:
      case 18:
      case 19:
        expo_fix = 0;
        break;

      case 20:
      case 21:
      case 22:
        x <<= 3;
        expo_fix = 1;
        break;

      case 23:
      case 24:
      case 25:
        x <<= 6;
        expo_fix = 2; 
        break;

      case 26:
      case 27:
      case 28:
        x <<= 9;
        expo_fix = 3;
        break;
    
      case 29:
      case 30:
      case 31:
        x <<= 12;
        expo_fix = 4;
        break;
  
    }

   //assuming the original number is 15 bits max, we only need 14 for the algorithm

    //all the integer bits (15 bits x, 5 bits x^0.33333)
    for(i = 12; i >= 0; i-=3) {
        answer <<= 1;
        bits = bits << 3 | ((x >> i) & 7);
        test = 3 * answer * (answer + 1) + 1;
        if (test <= bits) {
            bits -= test;//why? taking care of the x^3?!, or only keeping track of the error (r = b - x^3)
            answer |= 1;
        }
    }

    //more 17 bits of the fraction (totalling 32 bits number: 5 + 27) 
#ifdef GCC
    unsigned long bits2 = (unsigned long)bits, test2;
#else
    bl = bits;
    bh = 0;
#endif

    for(i = 26; i >= 0; i--) {
        answer <<= 1;
#ifdef GCC

        bits2 <<= 3;
        test2 = 3*(unsigned long)answer*((unsigned long)answer+1) +1;


        if(test2 <= bits2){
          bits2 -= test2;
          answer |= 1;
        } 

#else
        bh = (bh << 3) | (bl >>29);
        bl = bl << 3;
        //can't use a single mac since `3*answer` is overflowing the 32 bit register
        {
          unsigned t1h, t1l, t2h;
          {t1h,t1l} = mac(answer, 3, 0, 0);
          t2h = t1h*(answer+1);
          {th,tl} =  mac(t1l, answer+1, t2h, 1);
        }

        if (bh > th || (bh == th && bl >= tl)) {
           
            bh = bh - th;
            if(tl > bl)
              bh -= 1;
            bl = bl - tl;
            
            answer |= 1;
        }

#endif

    }

    //14.0*5.27=19.27
#ifdef GCC
    temp = (unsigned long)answer * (unsigned long)x_old;
    al = (unsigned)temp;
    ah = (unsigned)(temp >> 32);
#else
    {ah, al} = lmul(x_old, answer, 0, 0);
#endif
 
    if(clz(ah)!= 32){
      unsigned needLo = 27 - (32 - clz(ah));

      //need to round
      unsigned char roundByte = al >> 32 - needLo - 8 & 0xff;

#ifdef EXACT
      unsigned CHECK = doRound(x_old);//check if a value exits in the table which would tell weather to round or not.
      if((roundByte >= ROUND && CHECK == 0) || CHECK == 1){
        temp2 = al;
        al += 1 << (32 - needLo);
        if(al <= temp2)
          ah += 1;
      }
 
#else
      if(roundByte >= ROUND){
        temp2 = al;
        al += 1 << (32 - needLo);
        if(al <= temp2)
          ah += 1;
      }
 
#endif

      mantissa = ((al >> (32 - clz(ah))) | (ah << clz(ah))) >> 5;
      exponent = 32 - clz(ah) + 6 - expo_fix;
    }
    else if(clz(al) != 32){
      exponent = 2;
      mantissa = 0x04000000;
    } 
    else{
      exponent = 0;
      mantissa = 0;
    }
 
    return (exponent << 27 | mantissa);
}


