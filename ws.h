#ifndef WS_H
#define WS_H

#include <stdint.h>

typedef ssize_t (*ws_read_bytes_fp)(int fd, char *ptr, size_t maxlen);

/* ============================================================================ 
 * Data structures
 */
enum WebsocketFrameType {
        WS_FT_ERROR = -1,
        WS_FT_TEXT,
        WS_FT_CLOSE,
        WS_FT_PING,
        WS_FT_PONG
};

enum WebsocketReadState {
        WSF_START,
        WSF_READ_MED_LEN,
        WSF_READ_LONG_LEN,
        WSF_READ
};

typedef struct WebsocketFrame_ {
        uint8_t *buf;
        size_t buf_len;
        size_t num_read;
        size_t num_to_read;
        enum WebsocketReadState read_state;
} WebsocketFrame;


/* ============================================================================ 
 * Public API
 */

/* 
 * Websocket handshake
 * -------------------
 */
int ws_is_handshake(const char* req_str);
const char *ws_complete_handshake(const char *req_str);

/* 
 * Writing websocket frames
 * ------------------------
 */
size_t ws_make_text_frame(const char *message, const uint8_t mask[4],
                                                         uint8_t **frame_p);
size_t ws_make_close_frame(uint8_t **frame_p);
size_t ws_make_ping_frame(uint8_t **frame_p);
size_t ws_make_pong_frame(uint8_t **frame_p);


/* 
 * Reading websocket frames
 * ------------------------
 */
enum WebsocketFrameType ws_read_next_message(int fd,
                                    ws_read_bytes_fp read_bytes, char **message);

// TODO: Make these static functions
int ws_init_frame(WebsocketFrame *frame);
int ws_update_read_state(WebsocketFrame *frame);
int ws_append_bytes(WebsocketFrame *frame, uint8_t *src, size_t n);

const uint8_t *ws_extract_message(const uint8_t *frame);

/*
 * Understanding websocket frames
 * ------------------------------
 */
int ws_is_close_frame(const uint8_t* frame_str);
int ws_is_ping_frame(const uint8_t* frame_str);
int ws_is_pong_frame(const uint8_t* frame_str);
int ws_is_text_frame(const uint8_t* frame_str);
int ws_is_final(const uint8_t* frame_str);

#endif
