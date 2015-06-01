/*
 * http_stream.xc
 *
 *  Created on: 11 May 2015
 *      Author: simonc
 */

#include <print.h>
#include <stdlib.h>
#include <string.h>
#include <xtcp.h>

#include "http_stream.h"

#define DEBUGGING 1
#if(DEBUGGING)
#define DBG(x) x
#else
#define DBG(x) ;
#endif

connection_type_t xtag_tcp_connections[MAX_TCP_CONNECTIONS];
// 790 packet size * max of 6 packets before MAD will consume them
char buffer[8940];
int d_ptr = 0;
int h_ptr = 0;
int seen_header = 0;
int request_size = 0;
int data_total = 0;

#define LOCAL
#ifdef LOCAL
char * HTTP_REQUEST = "GET /music.mp3 HTTP/1.1\r\n"
        "Host: localhost\r\n"
        "Connection: keep-alive\r\n"
        "\r\n";
xtcp_ipaddr_t host = {192,168,0,1};
int service_port = 80;
#else
char * HTTP_REQUEST = "GET /7/251/142684/v1/gnl.akacast.akamaistream.net/dradio_mp3_dlf_s HTTP/1.1\r\n"
        "Host: 127.0.0.1\r\n"
        "\r\n";
xtcp_ipaddr_t host = {192,168,0,1};
int service_port = 8032;
#endif

void handle_http_event(chanend c_xtcp, xtcp_connection_t &conn, chanend chan_httpc)
{
    switch ((int)conn.event)
    {
        case XTCP_IFUP:
        {
            DBG(printstrln("XTCP_IFUP");)
            if_up(c_xtcp);
            xtcp_connect(c_xtcp, service_port, host, XTCP_PROTOCOL_TCP);

            // Clear the buffer.
            memset(buffer, 0, sizeof(buffer));
            break;
        }

        case XTCP_IFDOWN:
        {
            DBG(printstrln("XTCP_IFDOWN");)
            break;
        }

        case XTCP_ALREADY_HANDLED:
        {
            DBG(printstrln("XTCP_ALREADY_HANDLED");)
            return;
        }

        case XTCP_NEW_CONNECTION:
        {
            DBG(printstrln("XTCP_NEW_CONNECTION");)
            accept_connection(c_xtcp, conn);
            create_request(c_xtcp, conn);
            xtcp_init_send(c_xtcp, conn);
            break;
        }

        case XTCP_SENT_DATA:
        {
            DBG(printstrln("XTCP_SENT_DATA");)
            tcp_send(c_xtcp, conn);
            break;
        }

#pragma fallthrough
        case XTCP_PUSH_DATA:
            DBG(printstrln("XTCP_PUSH_DATA");)
        case XTCP_REQUEST_DATA:
        {
            DBG(printstrln("XTCP_REQUEST_DATA");)
            tcp_send(c_xtcp, conn);
            break;
        }

        case XTCP_RESEND_DATA:
        {
            DBG(printstrln("XTCP_RESEND_DATA");)
            tcp_send(c_xtcp, conn);
            break;
        }

        case XTCP_RECV_DATA:
        {
            DBG(printstrln("XTCP_RECV_DATA");)
            recv_data(c_xtcp, conn, chan_httpc);
            break;
        }

        case XTCP_TIMED_OUT:
        {
            DBG(printstrln("XTCP_TIMED_OUT");)
            // Close connection and try again!
            xtcp_close(c_xtcp, conn);

            if_up(c_xtcp);
            xtcp_connect(c_xtcp, service_port, host, XTCP_PROTOCOL_TCP);
            break;
        }

        case XTCP_ABORTED:
        {
            DBG(printstrln("XTCP_ABORTED");)
            // Close connection and try again!
            xtcp_close(c_xtcp, conn);

            if_up(c_xtcp);
            xtcp_connect(c_xtcp, service_port, host, XTCP_PROTOCOL_TCP);
            break;
        }

        case XTCP_CLOSED:
        {
            DBG(printstrln("XTCP_CLOSED");)
            request_size = h_ptr - d_ptr;
            chan_httpc <: request_size;

            for(int i = 0; i < request_size; i++)
                chan_httpc <: buffer[d_ptr + i];

            for(int i = d_ptr + request_size, k = 0;
                    k < sizeof(buffer) - (d_ptr + request_size);
                    i++, k++){
                buffer[k] = buffer[i];
            }

            h_ptr -= d_ptr + request_size;
            d_ptr = 0;

            if_up(c_xtcp);
            xtcp_connect(c_xtcp, service_port, host, XTCP_PROTOCOL_TCP);
            break;
        }

        default:
            return;
    }
    conn.event = XTCP_ALREADY_HANDLED;

}

void recv_data(chanend c_xtcp, xtcp_connection_t &conn, chanend chan_httpc)
{
    if(!request_size)
        chan_httpc :> request_size;
    int len = xtcp_recvi(c_xtcp, buffer, h_ptr);
    int header_len = 0;
    // Move the end ptr on by length
    h_ptr += len;
    data_total += len;

    if(!seen_header){
        int i;
        for(i = d_ptr; i < d_ptr + len; i++){
            if(buffer[i]   == '\r' && buffer[i+1] == '\n' &&
               buffer[i+2] == '\r' && buffer[i+3] == '\n')
                break;
            else
                DBG(printchar(buffer[i]);)
        }
        seen_header = 1;
        header_len = i + 4;
        // Skip the data pointer past the HTTP header, as the MP3 decoder doesn't want that.
        d_ptr += header_len;
        data_total -= header_len;
    }

    while((h_ptr - d_ptr) > request_size)
    {
        DBG(printstr("Bytes in buffer: "); printintln(h_ptr - d_ptr);)
        chan_httpc <: request_size;
        for(int i = 0; i < request_size; i++){
            chan_httpc <: buffer[d_ptr + i];
        }

        for(int i = d_ptr + request_size, k = 0;
                k < sizeof(buffer) - (d_ptr + request_size);
                i++, k++){
            buffer[k] = buffer[i];
        }

        h_ptr -= d_ptr + request_size;
        d_ptr = 0;
        chan_httpc :> request_size;
    }

    DBG(printintln(data_total);)
    conn.event = XTCP_ALREADY_HANDLED;
}

void accept_connection(chanend c_xtcp, xtcp_connection_t &conn)
{
    for(int i = 0; i < MAX_TCP_CONNECTIONS; i++)
    {
        if(!xtag_tcp_connections[i].active)
        {
            xtag_tcp_connections[i].active = 1;
            xtag_tcp_connections[i].conn_id = conn.id;
            xtag_tcp_connections[i].dptr = NULL;
            xtcp_set_connection_appstate(c_xtcp, conn, (xtcp_appstate_t)&xtag_tcp_connections[i]);
            conn.appstate = (xtcp_appstate_t)&xtag_tcp_connections[i];

            conn.event = XTCP_ALREADY_HANDLED;
            seen_header = 0;
            // Successfully found a free connection slot, return.
            return;
        }
    }
}

void create_request(chanend c_xtcp, xtcp_connection_t &conn)
{
    if(!conn.appstate)
        accept_connection(c_xtcp, conn);
    unsafe {
        // App state now contains a pointer to a connection_type_t struct.
        //  This will require some casting...
        ((connection_type_t *)conn.appstate)->dptr = HTTP_REQUEST;
        ((connection_type_t *)conn.appstate)->dlen = strlen(HTTP_REQUEST);
        DBG(printintln(((connection_type_t *)conn.appstate)->dlen);)
    }
}

void tcp_send(chanend tcp_svr, xtcp_connection_t &conn)
{
    unsafe {
#define hs ((connection_type_t *)conn.appstate)
        if (conn.event == XTCP_RESEND_DATA) {
            xtcp_send(tcp_svr, (char *)hs->prev_dptr, (hs->dptr - hs->prev_dptr));
            return;
        }

        DBG(printstr("hs->dlen: "); printintln(hs->dlen);)

        // Check if we have no data to send
        if (hs->dlen == 0 || hs->dptr == NULL) {
          // Terminates the send process
          xtcp_complete_send(tcp_svr);
          // Reset the data pointer for the next send
          hs->dptr = NULL;
        }
        // We need to send some new data
        else {
            int len = hs->dlen;
            if (len > conn.mss)
                len = conn.mss;

            xtcp_send(tcp_svr, (char *)hs->dptr, len);

            hs->prev_dptr = hs->dptr;
            hs->dptr += len;
            hs->dlen -= len;
        }
#undef hs
    }
}

void if_up(chanend c_xtcp) {
    xtcp_ipconfig_t ipconfig;
    xtcp_get_ipconfig(c_xtcp, ipconfig);

#if IPV6
    unsigned short a;
    unsigned int i;
    int f;
    xtcp_ipaddr_t *addr = &ipconfig.ipaddr;
    printstr("IPV6 Address = [");
    for(i = 0, f = 0; i < sizeof(xtcp_ipaddr_t); i += 2) {
      a = (addr->u8[i] << 8) + addr->u8[i + 1];
      if(a == 0 && f >= 0) {
        if(f++ == 0) {
          printstr("::");
         }
      } else {
          if(f > 0) {
            f = -1;
          } else if(i > 0) {
              printstr(":");
          }
        printhex(a);
      }
    }
    printstrln("]");
#else
    printstr("IP Address: ");
    printint(ipconfig.ipaddr[0]); printstr(".");
    printint(ipconfig.ipaddr[1]); printstr(".");
    printint(ipconfig.ipaddr[2]); printstr(".");
    printint(ipconfig.ipaddr[3]); printstr("\n");
#endif

}
