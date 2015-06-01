/*
 * libmad - MPEG audio decoder library
 * Copyright (C) 2000-2004 Underbit Technologies, Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
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
 * $Id: decoder.c,v 1.2 2008/08/20 17:56:34 sulei Exp $
 */

#include "mp3.h"

# ifdef HAVE_FCNTL_H
#  include <fcntl.h>
# endif

# include <stdlib.h>

# ifdef HAVE_ERRNO_H
#  include <errno.h>
# endif

# include "stream.h"
# include "frame.h"
# include "decoder.h"
# include "fixed.h"

#ifdef DEBUG_DECODER
#define dprintstr(s) myprintstr(s)
#else
#define dprintstr(s) {;}
#endif

/*
 * NAME:	decoder->init()
 * DESCRIPTION:	initialize a decoder object with callback routines
 */
void mad_decoder_init(struct mad_decoder *decoder, void *data,
        enum mad_flow (*input_func)(void *, struct mad_stream *),
        enum mad_flow (*header_func)(void *, struct mad_header const *),
        enum mad_flow (*filter_func)(void *, struct mad_stream const *,
                struct mad_frame *),
        enum mad_flow (*output_func)(void *, struct mad_header const *,
                struct mad_pcm *),
        enum mad_flow (*error_func)(void *, struct mad_stream *,
                struct mad_frame *),
        enum mad_flow (*message_func)(void *, void *, unsigned int *)) {

    decoder->options = 0;

    decoder->sync = 0;

    decoder->cb_data = data;

    decoder->input_func = input_func;
    decoder->header_func = header_func;
    decoder->filter_func = filter_func;
    decoder->output_func = output_func;
    decoder->error_func = error_func;
    decoder->message_func = message_func;
}

int mad_decoder_finish(struct mad_decoder *decoder) {
    return 0;
}

#pragma stackfunction 10 //words
static
int run_sync(struct mad_decoder *decoder) {
    enum mad_flow (*error_func)(void *, struct mad_stream *, struct mad_frame *);
    enum mad_flow (*input_func)(void *, struct mad_stream *);
    enum mad_flow (*output_func)(void *, struct mad_header const *,
            struct mad_pcm *);
    enum mad_flow (*header_func)(void *, struct mad_header const *);
    enum mad_flow (*filter_func)(void *, struct mad_stream const *,
            struct mad_frame *);

    void *error_data;
    struct DATA *data;
    struct mad_stream *stream;
    struct mad_frame *frame;
    struct mad_synth *synth;

    int result = 0;

    if (decoder->input_func == 0)
        return 0;

    if (decoder->error_func == 0)
        return 0;

    if (decoder->output_func == 0)
        return 0;

    error_func = decoder->error_func;
    input_func = decoder->input_func;
    output_func = decoder->output_func;
    header_func = decoder->header_func;
    filter_func = decoder->filter_func;

    error_data = decoder->cb_data;

    data = decoder->cb_data;

    stream = &decoder->sync->stream;
    frame = &decoder->sync->frame;
    synth = &decoder->sync->synth;

    mad_stream_init(stream);
    mad_frame_init(frame);
    mad_synth_init(synth);

    mad_stream_options(stream, decoder->options);

    do {

        dprintstr("decoder: input_func\n");
        switch (input_func(decoder->cb_data, stream)) {
        case MAD_FLOW_STOP:
            goto done;
        case MAD_FLOW_BREAK:
            goto fail;
        case MAD_FLOW_IGNORE:
            continue;
        case MAD_FLOW_CONTINUE:
            break;
        }

        while (1) {

            if (decoder->header_func) {
                dprintstr("decoder: mad_header_decode\n");

                if (mad_header_decode(&frame->header, stream) == -1) {
                    if (!MAD_RECOVERABLE(stream->error))
                        break;

                    switch (error_func(error_data, stream, frame)) {
                    case MAD_FLOW_STOP:
                        goto done;
                    case MAD_FLOW_BREAK:
                        goto fail;
                    case MAD_FLOW_IGNORE:
                    case MAD_FLOW_CONTINUE:
                    default:
                        continue;
                    }
                }

                dprintstr("decoder: header_func\n");

                switch (header_func(decoder->cb_data, &frame->header)) {
                case MAD_FLOW_STOP:
                    goto done;
                case MAD_FLOW_BREAK:
                    goto fail;
                case MAD_FLOW_IGNORE:
                    continue;
                case MAD_FLOW_CONTINUE:
                    break;
                }
            }

            dprintstr("decoder: mad_frame_decode\n");

//scavanging few KBs by using the PCM buffer as a scratch board for III_decode, which consequentially makes it's stack smaller...
#ifdef SAMPLES_16_BITS
            if (mad_frame_decode(frame, stream, (mad_fixed_t**)(&synth->pcm.scaled_samples)) == -1) {
#else
            if (mad_frame_decode(frame, stream, (mad_fixed_t**)&synth->pcm.samples) == -1) {
#endif
                dprintstr("decoder: mad_frame_decode returned -1.\n");
                if (!MAD_RECOVERABLE(stream->error))
                    break;

                dprintstr("decoder: a recoverable error!.\n");

                switch (error_func(error_data, stream, frame)) {
                case MAD_FLOW_STOP:
                    goto done;
                case MAD_FLOW_BREAK:
                    goto fail;
                case MAD_FLOW_IGNORE:
                    break;
                case MAD_FLOW_CONTINUE:
                default:
                    continue;
                }
            }

            if (decoder->filter_func) {
                dprintstr("decoder: filter_func\n");

                switch (filter_func(decoder->cb_data, stream, frame)) {
                case MAD_FLOW_STOP:
                    goto done;
                case MAD_FLOW_BREAK:
                    goto fail;
                case MAD_FLOW_IGNORE:
                    continue;
                case MAD_FLOW_CONTINUE:
                    break;
                }
            }

            dprintstr("decoder: mad_synth_frame\n");

            mad_synth_frame(synth, frame);

            switch (output_func(decoder->cb_data, &frame->header, &synth->pcm)) {
            case MAD_FLOW_STOP:
                goto done;
            case MAD_FLOW_BREAK:
                goto fail;
            case MAD_FLOW_IGNORE:
            case MAD_FLOW_CONTINUE:
                break;
            }

        }
    } while (stream->error == MAD_ERROR_BUFLEN);

    fail: result = -1;

    done: mad_synth_finish(synth);
    mad_frame_finish(frame);
    mad_stream_finish(stream);

    dprintstr("decoder: run_sync finished\n");

    return result;
}

#ifndef DYNAMIC_MEMORY
static sync_struct global_sync;
#endif

/*
 * NAME:	decoder->run()
 * DESCRIPTION:	run the decoder
 */
 #pragma stackfunction 1000 //words
int mad_decoder_run(struct mad_decoder *decoder) {
    int result;
#ifdef DYNAMIC_MEMORY
    decoder->sync = malloc(sizeof(sync_struct));
#else
    decoder->sync = (&global_sync);
#endif
    if (decoder->sync == 0)
        return -1;

    result = run_sync(decoder);
#ifdef DYNAMIC_MEMORY
    free(decoder->sync);
#endif
    decoder->sync = 0;

    return result;
}

enum mad_flow header_func(void *data, struct mad_header const *header) {
    return MAD_FLOW_BREAK;
}
enum mad_flow filter_func(void *data, struct mad_stream const *stream,
        struct mad_frame *frame) {
    return MAD_FLOW_BREAK;
}
enum mad_flow message_func(void *d1, void *d2, unsigned int *m) {
    return MAD_FLOW_BREAK;
}
