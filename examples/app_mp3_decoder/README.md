# `app_mp3_decoder`

This example streams an MP3 file from a webserver and decodes it on
the fly. It's made up of 3 main components:

1. Ethernet & TCP/IP stack
2. lib_mp3 decoder
3. I2S codec

```
------------  Request  ---------------      PCM out     -------------
| Ethernet |  <------  | mp3_decoder |  --------------> | I2S codec |
|  TCP/IP  |           |             |                  |           |
|          |  buffer   |             |    fifo_buffer   |           |
|          |           |             |                  |           |
|  (xtcp)  |  ------>  |  (lib_mp3)  |  <-------------- | (lib_i2s) |
------------   Data    ---------------   Buffer status  -------------
```

Each stage of this has some buffering. The Ethernet stack fills into a
frame buffer, writes out `request_size` data when asked. It blocks
stops receiving if the buffer is full.

The mp3_decoder has internal frame and PCM buffering. When it is ready
to output PCM data it checks a fifo for being full and pushes into
that when there's space.

The fifo is read out of by the i2s codec. This means that ultimately
the codec governs the rate at which a file is decoded, and provides
"back-pressure" through the system so that buffers don't overrun, or
underrun.

## Ethernet & TCP/IP

This component is moderately simple. When the Ethernet Interface comes
up (`XTCP_IFUP`), it connects to a given host and sends an HTTP
request.

```xc
char * HTTP_REQUEST = "GET /%s HTTP/1.1\r\n"
                      "Host: 192.168.0.1\r\n"
                      "Connection: keep-alive\r\n"
                      "\r\n";
char * request_buffer[200];
char * file_name[20] = {'m', 'u', 's', 'i', 'c', '.', 'm', 'p', '3', 0};

void create_request(chanend c_xtcp, xtcp_connection_t &conn)
{
    if(!conn.appstate)
        accept_connection(c_xtcp, conn);
    unsafe {
        // App state now contains a pointer to a connection_type_t struct.
        //  This will require some casting...
        sprintf(request_buffer, HTTP_REQUEST, file_name);
	
        ((connection_type_t *)conn.appstate)->dptr = request_buffer;
        ((connection_type_t *)conn.appstate)->dlen = strlen(request_buffer);
        DBG(printintln(((connection_type_t *)conn.appstate)->dlen);)
    }
}
```

The `sprintf(3)` call allows us to build a request from a given
filename. This is a crude way to build requests.


Once the connection is established and the request is sent, the HTTP
server will begin sending the file to us. This will fire `XTCP_RECV`
events in the `xtcp` stack.

The 1st thing to do is strip the HTTP header, which is as easy as
matching "\r\n\r\n" in the input buffer. Following that everything is
MP3 data and may be sent to the MP3 decoder.

The data is coppied into a buffer. When the ammount of data in the
buffer is greater than the ammount requested by the MP3 decoder,
`request_size` bytes are read out. The remaining bytes are shifted
down to the start of the buffer.

```xc
void recv_data(chanend c_xtcp, xtcp_connection_t &conn, chanend chan_httpc)
{
    // If request_size isn't set, read it from the MP3 decoder.
    if(!request_size)
        chan_httpc :> request_size;
    int len = xtcp_recvi(c_xtcp, buffer, h_ptr);
    int header_len = 0;

    // Move the end ptr on by length
    h_ptr += len;

    if(!seen_header){
        int i;
        for(i = d_ptr; i < d_ptr + len; i++){
            if(buffer[i]   == '\r' && buffer[i+1] == '\n' &&
               buffer[i+2] == '\r' && buffer[i+3] == '\n')
                break;
            else
                printchar(buffer[i]);
        }
        printchar(buffer[i + 0]); printchar(buffer[i + 1]);
        printchar(buffer[i + 2]); printchar(buffer[i + 3]);
        seen_header = 1;
        header_len = i + 4;
        // Skip the data pointer past the HTTP header, as the MP3 decoder doesn't want that.
        d_ptr += header_len;
    }

    while((h_ptr - d_ptr) > request_size)
    {
        // Tell the MP3 decoder we have request_size bytes available for it and write them
        chan_httpc <: request_size;
        for(int i = 0; i < request_size; i++){
            chan_httpc <: buffer[d_ptr + i];
        }

	// Move the remaining data in the buffer down to buffer[0]
        for(int i = d_ptr + request_size, k = 0;
                k < sizeof(buffer) - (d_ptr + request_size);
                i++, k++){
            buffer[k] = buffer[i];
        }

	// Move buffer pointers respectively
        h_ptr -= d_ptr + request_size;
        d_ptr = 0;

	// Block until the next request, and store the ammount of data asked for
        chan_httpc :> request_size;
    }

    conn.event = XTCP_ALREADY_HANDLED;
}
```

These are the main parts for providing MP3 data from a web-stream to
the MP3 decoder.



## mp3_decoder

The setup for this is simple, as mp3 decoder is treated as a black
box. I run a task for managing the I/O of the decoder, which forwards
requests to the HTTP and I2S components.

See the [`lib_mp3` README](../../README.md).

## I2S

This is primarily formed of a single distributable task which shares a
set of fifo buffers. One per channel.

```xc
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
```

This forms a 1.5k buffer for PCM data to the I2S component.

There are appropriate functions pushing and poping to this
structure. See [fifo.xc](./src/fifo.xc).

Importantly there is a function `is_fifo_full(fifo_t &fifo, int
channel)` which my be polled by tasks wishing to write into the fifo.

```xc
while(is_fifo_full(data, channel)) delay_microseconds(10);

// Fifo now has some space
add_to_fifo(data, channel, sample);
```

