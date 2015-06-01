/*
 * Copyright (C) 2000-2004 Underbit Technologies, Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * $Id: one_core.c,v 1.3 2008/08/20 17:56:34 sulei Exp $
 */


#include "mp3.h"
#include "mad.h"


#ifdef DEBUG_MP3TOP
#define mprintstr(s) myprintstr(s)
#define mprinthex(x) myprinthex(x)
#else
#define mprintstr(s) {;}
#define mprinthex(x) {;}
#endif

#define chanend unsigned
struct DATA {
  unsigned char *buffer;
  signed long length;
	chanend mp3_chan;
	chanend pcm_chan;
	unsigned mp3_eof;
	unsigned frameCount;
};


/*
 * This is the input callback. The purpose of this callback is to (re)fill
 * the stream buffer which is to be decoded. In this example, an entire file
 * has been mapped into memory, so we just call mad_stream_buffer() with the
 * address and length of the mapping. When this callback is called a second
 * time, we are finished decoding.
 */

unsigned mp3_read(unsigned char ptr[], unsigned count, chanend data);

#ifdef SAMPLES_16_BITS
int pcm_write(signed short scaled_left_ch[], signed short scaled_right_ch[], unsigned nsamples, unsigned nchannels, chanend pcm_chan);
#else
int pcm_write(signed int const left_ch[], signed int const right_ch[], unsigned nsamples, unsigned nchannels, chanend pcm_chan);
#endif



enum mad_flow input(void *data, struct mad_stream *stream)
{
  struct DATA *dataPtr = (struct DATA*)data;
  unsigned need, get;


  if(dataPtr->mp3_eof == true) {
    return MAD_FLOW_STOP;
  }

  if (stream->next_frame) {
     dataPtr->length = &dataPtr->buffer[dataPtr->length] - stream->next_frame;
     if(dataPtr->length > 0)
         memmove(dataPtr->buffer, stream->next_frame, dataPtr->length);
  }
  else{
     dataPtr->length = 0;
  }

  need = BUFFER_SIZE - dataPtr->length;

  get = mp3_read(((&(dataPtr->buffer[0])) + dataPtr->length),   need, dataPtr->mp3_chan);

  if(get <= 0){
    return MAD_FLOW_STOP;
  }

  if(get < need){
    dataPtr->mp3_eof = true;
  }

  mad_stream_buffer(stream, dataPtr->buffer, dataPtr->length += get);
  return MAD_FLOW_CONTINUE;

}

/*
 * This is the output callback function. It is called after each frame of
 * MPEG audio data has been completely decoded. The purpose of this callback
 * is to output (or play) the decoded PCM audio.
 */

int frameCount = 0;
enum mad_flow output(void *data,
		     struct mad_header const *header,
		     struct mad_pcm *pcm)
{
#ifdef SAMPLES_16_BITS
  signed short *scaled_left_ch, *scaled_right_ch;
#else
  mad_fixed_t const *left_ch, *right_ch;
#endif
  unsigned int nchannels, nsamples;
  int result;
  struct DATA *dataPtr = data;



  /* pcm->samplerate contains the sampling frequency */
  nchannels = pcm->channels;
  nsamples  = pcm->length;
#ifdef SAMPLES_16_BITS
  scaled_left_ch = pcm->scaled_samples[0];
  scaled_right_ch = pcm->scaled_samples[1];
	result = pcm_write(scaled_left_ch, scaled_right_ch,	nsamples, nchannels, dataPtr->pcm_chan);
#else
  left_ch   = pcm->samples[0];
  right_ch  = pcm->samples[1];
	result = pcm_write(left_ch, right_ch,	nsamples, nchannels, dataPtr->pcm_chan);
#endif

	frameCount++;

	mprintstr("mp3top: outputted frame #");
	mprinthex(frameCount);
	mprintstr(".\n");

	if(result >= 0)
		return MAD_FLOW_CONTINUE;
	else
		return MAD_FLOW_STOP;
}

/*
 * This is the error callback function. It is called whenever a decoding
 * error occurs. The error is indicated by stream->error; the list of
 * possible MAD_ERROR_* errors can be found in the mad.h (or stream.h)
 * header file.
 */

enum mad_flow error(void *data,
		    struct mad_stream *stream,
		    struct mad_frame *frame)
{
//  struct DATA *dataPtr = data;
	mprintstr("mp3top: Error#");
	mprinthex(stream->error);
	mprintstr("\n");

  if(stream->error != MAD_ERROR_LOSTSYNC){
  	mprintstr("mp3top: MAD_FLOW_BREAK\n");
  	return MAD_FLOW_BREAK;
  }
  else {
		mprintstr("mp3top: MAD_FLOW_CONTINUE\n");

    return MAD_FLOW_CONTINUE;
  }

	return MAD_FLOW_CONTINUE;
}

/*
 * This is the function called by main() above to perform all the decoding.
 * It instantiates a decoder object and configures it with the input,
 * output, and error callback functions above. A single call to
 * mad_decoder_run() continues until a callback function returns
 * MAD_FLOW_STOP (to stop decoding) or MAD_FLOW_BREAK (to stop decoding and
 * signal an error).
 */
unsigned mp3_finish(chanend mp3_chan, chanend pcm_chan, int frameCount);

int mp3_decode(chanend mp3_chan, chanend pcm_chan)
{
  struct DATA data;
  struct mad_decoder decoder;
  int result;

  unsigned char buf[BUFFER_SIZE];

  /* initialize our private message structure */
  data.buffer = buf;
  data.length = 0;//empty buffer
  data.frameCount = 0;

  data.mp3_chan = mp3_chan;
  data.pcm_chan = pcm_chan;
  data.mp3_eof = false;

  /* configure input, output, and error functions */
  mad_decoder_init(&decoder, &data,
		           input, 0 /* header */, 0 /* filter */, output,
		           error, 0 /* message */);

  /* start decoding */
	result = mad_decoder_run(&decoder);


  /* release the decoder */

  mad_decoder_finish(&decoder);

  mp3_finish(mp3_chan, pcm_chan, frameCount);
  return result;
}
