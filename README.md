lib_mp3
============

Summary
-------

MP3 decoder library. Uses [Underbit Technolgies'
MAD](http://www.underbit.com/products/mad/) mpeg audio decoder, which is under a
GPLv2 license.

*Caution*: The GPL license is restrictive, applications which use this library
must be under a GPL compatible license. As dynamic linking is not an option, and
that the library is likely to form a core part of any application built from it,
there is no way to avoid this. Exceptions to the license may be purchased from
Underbit Technologies in order to enable proprietary use. These licenses should
be purchased by customers wanting to use the library, as XMOS can't purchase an
exception and sublicense it to customers.

### Features

 * MP3 Decoding at 16 and 24 bit.

### Resource Usage

 * Single thread + input thread + output thread
 * 60kb memory 
 * 1 channel of mp3 data in
 * 1 channel to consume pcm data out

### Software version and dependencies

Version 0.1. 

### Related application notes

None.


Usage
-----

There's some configuration in `mp3.h` which is important. Primarily the
`SIZE_OF_FRAME` define.

Depending on what the application is going to be streaming data from different
values are appropriate.

 * 9000 is good for web-radio streaming
   * Even larger buffers might be better for radio streaming, YMMV.
 * 4660 is good for streaming MP3s from a webserver
 * 2330 is good for local streaming of MP3 files from hardware on the xCORE
   (e.g. an SD card)


You can toggle debug messages by commenting out the debug lines:
```xc
#define DEBUG
#define DEBUG_DECODER       TRUE        //decoder.c
#define DEBUG_TEST          TRUE        //test.xc
#define DEBUG_MP3TOP        TRUE
#define DEBUG_FRAME         TRUE        //frame.c
```

The MP3 decoder takes 1 channel of MP3 data in, and writes uncompressed audio
samples (PCM) out on another. The channels have a simple communication protocol.

```xc
int mp3_decode(chanend mp3_chan, chanend pcm_chan);
```

### mp3_chan

The decoder part _requests_ mp3 data. The program then replies with a write
command followed by the number of bytes it plans to write, followed by the data.

Normally the number of bytes to write should equal the request size. It may not
be larger than the request size. It may be less than the request size, this
might happen when you're reading the last part of a file, for example. It
shouldn't be happening because you can't read data fast enough.

```xc
char command;
chan_mp3 :> command;

switch(command)
{
    case _C_READ:
        unsigned request_size;
        chan_mp3 :> request_size; /* The mp3 decoder then asks for n bytes */
        chan_mp3 <: _C_WRITE;     /* Reply that we're going to write back */
        chan_mp3 <: data_avail;   /* Reply with how many bytes (ideally = equal
                                     to request_size, may not be greater) */
        for(int i = 0; i < data_avail; i++)
            mp3_data <: mp3_buffer[i];

        if(end_of_file)
            mp3_data <: _C_EOF;   /* We may optionally tell the decoder that 
                                     this is the end of the file */
        break;

    case _C_FINISH:
        /* The decoder beleives we've reached the end of the file. */
        close_streams();
        break;

    case _C_ERROR:
        /* An error has occured */
        error();
        break;
}
```

### pcm_chan

The decoder will output uncompressed audio data in PCM format. 

```xc
char command;
chan_pcm :> command;

switch(command)
{
    case _C_WRITE:
        unsigned sample_count, chan_count;
        chan_pcm :> sample_count; /* The number of samples to write */
        chan_pcm :> chan_count;   /* The number of channels in this frame */
        chan_pcm <: _C_READ;      /* Tell the decoder we're ready to read */

        /* Read out the data */
        for(int s = 0; s < sample_count; s++)
        {
            for(int c = 0; c < chan_count; c++)
            {
                unsigned sample;
                chan_pcm :> sample;
                pcm_buffer[c][s] = sample;
            }
        }
        break;

    case _C_FINISH:
        /* The decoding has completed. The Decoder will output the number of
           frames decoded. */
        unsigned frame_count;
        chan_pcm :> frame_count;
        break;

}
```
