/*
 * http_stream.h
 *
 *  Created on: 11 May 2015
 *      Author: simonc
 */

#ifndef HTTP_STREAM_H_
#define HTTP_STREAM_H_

#define MAX_TCP_CONNECTIONS 10

typedef struct connection_type_t {
    int active;              //< Whether this state structure is being used
                             //  for a connection
    int conn_id;             //< The connection id
    char * unsafe dptr;      //< Pointer to the remaining data to send
    int dlen;                //< The length of remaining data to send
    char * unsafe prev_dptr; //< Pointer to the previously sent item of data
} connection_type_t;

void handle_http_event(chanend c_xtcp, xtcp_connection_t &conn, chanend chan_httpc);
void recv_data(chanend c_xtcp, xtcp_connection_t &conn, chanend chan_httpc);
void create_request(chanend c_xtcp, xtcp_connection_t &conn);
void tcp_send(chanend tcp_svr, xtcp_connection_t &conn);
void accept_connection(chanend c_xtcp, xtcp_connection_t &conn);
void if_up(chanend c_xtcp);

#endif /* HTTP_STREAM_H_ */
