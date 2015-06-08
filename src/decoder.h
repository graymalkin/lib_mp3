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
 * $Id: decoder.h,v 1.1 2008/08/08 10:55:01 sulei Exp $
 */

# ifndef LIBMAD_DECODER_H
# define LIBMAD_DECODER_H

# include "stream.h"
# include "frame.h"
# include "synth.h"

typedef struct {
    struct mad_stream stream;
    struct mad_frame frame;
    struct mad_synth synth;
} sync_struct;


struct mad_decoder {

  int options;

  sync_struct *sync;

  void *cb_data;

  enum mad_flow (*input_func)(void *, struct mad_stream *);
  enum mad_flow (*header_func)(void *, struct mad_header const *);
  enum mad_flow (*filter_func)(void *,
                               struct mad_stream const *, struct mad_frame *);
  enum mad_flow (*output_func)(void *,
                               struct mad_header const *, struct mad_pcm *);
  enum mad_flow (*error_func)(void *, struct mad_stream *, struct mad_frame *);
  enum mad_flow (*message_func)(void *, void *, unsigned int *);

};
void mad_decoder_init(struct mad_decoder *, void *,
                      enum mad_flow (*)(void *, struct mad_stream *),
                      enum mad_flow (*)(void *, struct mad_header const *),
                      enum mad_flow (*)(void *,
                                        struct mad_stream const *,
                                        struct mad_frame *),
                      enum mad_flow (*)(void *,
                                        struct mad_header const *,
                                        struct mad_pcm *),
                      enum mad_flow (*)(void *,
                                        struct mad_stream *,
                                        struct mad_frame *),
                      enum mad_flow (*)(void *, void *, unsigned int *));
int mad_decoder_finish(struct mad_decoder *);


# define mad_decoder_options(decoder, opts)  \
    ((void) ((decoder)->options = (opts)))

int mad_decoder_run(struct mad_decoder *);
int mad_decoder_message(struct mad_decoder *, void *, unsigned int *);

# endif
