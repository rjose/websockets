#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include <openssl/sha.h>

#include "ws.h"
#include "base64.h"

#define MAX_HANDSHAKE_RESPONSE_LEN 300
#define MAX_WEBSOCKET_KEY_LEN 40
#define SEC_WEBSOCKET_KEY "Sec-WebSocket-Key"
#define SEC_WEBSOCKET_KEY_LEN 17
#define BUF_LENGTH 200

#define SHORT_MESSAGE_LEN 125
#define MED_MESSAGE_LEN 0xFFFF 
#define MED_MESSAGE_KEY 126
#define LONG_MESSAGE_KEY 127
#define NUM_MED_LEN_BYTES 2
#define NUM_LONG_LEN_BYTES 8
#define MASK_LEN 4

/* Byte 0 of websocket frame */
#define WS_FRAME_FIN 0x80
#define WS_FRAME_OP_CONT 0x00
#define WS_FRAME_OP_TEXT 0x01
#define WS_FRAME_OP_BIN 0x02
#define WS_FRAME_OP_CLOSE 0x08
#define WS_FRAME_OP_PING 0x09
#define WS_FRAME_OP_PONG 0x0A

/* Byte 1 of websocket frame */
#define WS_FRAME_MASK 0x80

#define MAXLINE 1000

/* ============================================================================ 
 * Static declarations
 */
static void err_abort(int, const char *);
static int get_ws_key(char *, size_t, const char *);
static uint8_t toggle_mask(uint8_t, size_t, const uint8_t [4]);
static int ws_extend_frame_buf(WebsocketFrame *frame, size_t more_len);
static int ws_init_frame(WebsocketFrame *frame);
static int ws_update_read_state(WebsocketFrame *frame);
static int ws_append_bytes(WebsocketFrame *frame, uint8_t *src, size_t n);

static char ws_magic_string[] = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";


// TODO: Move this to a util file
static void err_abort(int status, const char *message)
{
        fprintf(stderr, message);
        exit(status);
}

/*
 * We're basically checking to see if the required fields are present.
 */
int ws_is_handshake(const char* req_str)
{
        /* Look for "Upgrade: websocket" */ 
        if (strcasestr(req_str, "Upgrade: websocket") == NULL)
                return 0;

        /* Look for "Connection: Upgrade" */
        if (strcasestr(req_str, "Connection: upgrade") == NULL)
                return 0;

        /* Look for "Sec-WebSocket-Key:" */
        if (strcasestr(req_str, "Sec-WebSocket-Key:") == NULL)
                return 0;

        return 1;
}

static int get_ws_key(char *dst, size_t n, const char *req_str)
{
        int i;
        const char *start_key;
        const char *val;

        start_key = strcasestr(req_str, SEC_WEBSOCKET_KEY);
        if (start_key == NULL)
                return -1;

        val = start_key + SEC_WEBSOCKET_KEY_LEN + 2; /* 2 for the colon and space */
        for (i = 0; i < n-1 && *val != '\r'; i++)
                *dst++ = *val++;
        *dst = '\0';

        return 0;
}

/*
 * This generates a response string appropriate for completing the websocket handshake.
 *
 * NOTE: We're assuming req_str is a valid handshake string.
 *
 * NOTE: This function allocates memory for the response, so the caller must
 * free it when done.
 *
 */
const char *ws_complete_handshake(const char *req_str)
{
        char buf[BUF_LENGTH];
        char websocket_key[MAX_WEBSOCKET_KEY_LEN];
	uint8_t sha_digest[SHA_DIGEST_LENGTH];
        char *websocket_accept = NULL;
        static char response_template[] = 
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                "Sec-WebSocket-Accept: %s\r\n"
                "\r\n";
        char *result;
        
        /*
         * Allocate space for result
         */
        result = calloc(MAX_HANDSHAKE_RESPONSE_LEN, sizeof(char));
        if (result == NULL) {
                err_abort(-1, "Can't allocate memory in ws_complete_handshake");
        }

	/* Compute websocket accept value */
        if (get_ws_key(websocket_key, MAX_WEBSOCKET_KEY_LEN, req_str) != 0)
                goto error;

	strncpy(buf, websocket_key, BUF_LENGTH/2);
	strncat(buf, ws_magic_string, BUF_LENGTH/2);
        SHA_CTX ctx;
        SHA1_Init(&ctx);
        SHA1_Update(&ctx, buf, strlen(buf));
        SHA1_Final(sha_digest, &ctx);

        if (base64_encode(&websocket_accept, sha_digest,
                                                  SHA_DIGEST_LENGTH) != 0)
                goto error;

        /*
         * Construct response and return
         */
        snprintf(result, MAX_HANDSHAKE_RESPONSE_LEN, response_template, websocket_accept);
        free(websocket_accept);
        return result;

error:
        if (result != NULL)
                free(result);

        if (websocket_accept != NULL)
                free(websocket_accept);
        return NULL;
}

static uint8_t toggle_mask(uint8_t c, size_t index, const uint8_t mask[4])
{
        uint8_t result = c;
        if (mask)
                result = c ^ mask[index % 4];

        return result;
}


/*
 * NOTE: This function will always set the FIN bit to 1. If you want to send
 * fragments, set this to 0 once you get the frame back.
 */
size_t ws_make_text_frame(const char *message, const uint8_t mask[4], uint8_t **frame_p)
{
        uint64_t i;
        uint64_t message_len;
        size_t mask_len;
        size_t num_len_bytes; /* Number of extended payload len bytes */
        uint8_t byte0, byte1;     /* First two bytes of the frame */
        uint64_t tmp;
        size_t frame_len;
        uint8_t *result = NULL;

        /* We know this is a text frame */
        byte0 = WS_FRAME_OP_TEXT;
        byte0 |= WS_FRAME_FIN;

        /* If a mask is specified, set the mask bit */
        byte1 = mask ? WS_FRAME_MASK : 0;

        /*
         * Figure out the length of the frame and then allocate memory. This
         * involves figuring out if we need a mask, if we need extra length
         * bytes, and how big the message is.
         */
        mask_len = mask ? 4 : 0;
        message_len = strlen(message);
        if (message_len <= SHORT_MESSAGE_LEN) {
                num_len_bytes = 0;
                byte1 |= message_len;
        }
        else if (message_len > SHORT_MESSAGE_LEN &&
                                               message_len <= MED_MESSAGE_LEN) {
                num_len_bytes = 2;
                byte1 |= MED_MESSAGE_KEY;
        }
        else {
                num_len_bytes = 8;
                byte1 |= LONG_MESSAGE_KEY;
        }
        frame_len = 2 + num_len_bytes + mask_len + message_len;
        if ((result = (uint8_t *)malloc(frame_len)) == NULL)
                err_abort(-1, "Can't allocate memory for ws_make_text_frame");

        /*
         * Write data into the frame. First, we'll write the first 2 bytes
         * that we've constructed. After this comes the extended payload
         * length (if needed). After that is the mask (if needed). Finally, we
         * write our message.
         */
        result[0] = byte0;
        result[1] = byte1;

        /* Write extended length */
        tmp = message_len;
        for (i = num_len_bytes; i > 0; i--) {
                result[2 + i - 1] = tmp & 0xFF;
                tmp >>= 8;
        }
        
        /* Write mask */
        if (mask)
                for (i = 0; i < mask_len; i++)
                        result[2 + num_len_bytes + i] = mask[i];

        /* Write message */
        for (i = 0; i < message_len; i++) {
                result[2 + num_len_bytes + mask_len + i] =
                                       toggle_mask(message[i], i, mask);
        }

        /*
         * Return results
         */
        *frame_p = result;

        return frame_len;
}

size_t ws_make_close_frame(uint8_t **frame_p)
{
        uint8_t byte0, byte1;     /* First two bytes of the frame */
        uint8_t *result = NULL;

        byte0 = WS_FRAME_OP_CLOSE;
        byte0 |= WS_FRAME_FIN;

        byte1 = 0;

        if ((result = (uint8_t *)malloc(2)) == NULL)
                err_abort(-1, "Can't allocate memory for ws_make_close_frame");

        result[0] = byte0;
        result[1] = byte1;

        /*
         * Return result
         */
        *frame_p = result;

        return 2;
}

size_t ws_make_ping_frame(uint8_t **frame_p)
{
        uint8_t byte0, byte1;     /* First two bytes of the frame */
        uint8_t *result = NULL;

        byte0 = WS_FRAME_OP_PING;
        byte0 |= WS_FRAME_FIN;

        byte1 = 0;

        if ((result = (uint8_t *)malloc(2)) == NULL)
                err_abort(-1, "Can't allocate memory for ws_make_close_frame");

        result[0] = byte0;
        result[1] = byte1;

        /*
         * Return result
         */
        *frame_p = result;
        return 2;
}

size_t ws_make_pong_frame(uint8_t **frame_p)
{
        uint8_t byte0, byte1;     /* First two bytes of the frame */
        uint8_t *result = NULL;

        byte0 = WS_FRAME_OP_PONG;
        byte0 |= WS_FRAME_FIN;

        byte1 = 0;

        if ((result = (uint8_t *)malloc(2)) == NULL)
                err_abort(-1, "Can't allocate memory for ws_make_close_frame");

        result[0] = byte0;
        result[1] = byte1;

        /*
         * Return result
         */
        *frame_p = result;
        return 2;
}


/* ============================================================================ 
 * Reading websocket frames
 * ------------------------
 *
 * When we're reading websocket frames in from a socket connection, we have to
 * be careful not to read only the number of bytes that are part of the frame.
 * To do this, we set up a little state machine. We update the number of bytes
 * to read using "ws_update_read_state" and "ws_append_bytes". When
 * "ws_update_read_state" returns 0, we have a valid websocket frame.
 *
 * If the websocket frame has a message in it, we can use "ws_extract_message"
 * to retrieve it.
 *
 * NOTE: This frees any memory in the buffer
 */

static char *append_message(char *dst, char *src)
{
        size_t src_len;
        size_t dst_len;

        if (src == NULL)
                return dst;

        if (dst == NULL)
                return src;

        src_len = strlen(src);
        dst_len = strlen(dst);
        if ((dst=(char *)realloc(dst, dst_len + src_len + 1)) == NULL)
                err_abort(-1, "Can't realloc in append_message");

        strncpy(dst+dst_len, src, src_len);
        free(src);

        return dst;
}

enum WebsocketFrameType ws_read_next_message(int connfd, ws_read_bytes_fp read_bytes,
                                                                 char **message)
{
        WebsocketFrame frame;
        enum WebsocketFrameType result;
        char *frame_message = NULL;
	char buf[MAXLINE+1];
        int num_to_read;
        int num_read;
        char *tmp = NULL;

        /*
         * This reads frames in and combines any fragments together
         */
        frame.buf = NULL;
        while (1) {
                /*
                 * Read a frame in
                 */
                ws_init_frame(&frame);
                do {
                        num_to_read = frame.num_to_read;
                        if (num_to_read > MAXLINE)
                                num_to_read = MAXLINE;

                        if (num_to_read == 0)
                                continue;

                        if ((num_read = read_bytes(connfd, buf, num_to_read)) < 0) {
                                result = WS_FT_ERROR;
                                goto error;
                        }

                        ws_append_bytes(&frame, (uint8_t *)buf, num_read);
                }
                while (ws_update_read_state(&frame) == 1);

                /*
                 * Handle frame
                 */
                if (ws_is_text_frame(frame.buf)) {
                        result = WS_FT_TEXT;
                        tmp = (char *) ws_extract_message(frame.buf);

                        /* NOTE: append_message will free tmp if needed */
                        frame_message = append_message(frame_message, tmp);
                }
                else if (ws_is_ping_frame(frame.buf))
                        result = WS_FT_PING;
                else if (ws_is_pong_frame(frame.buf))
                        result = WS_FT_PONG;
                else if (ws_is_close_frame(frame.buf))
                        result = WS_FT_CLOSE;
                else {
                        result = WS_FT_ERROR;
                        fprintf(stderr, "Unknown websocket frame type\n");
                }

                /*
                 * If this is the final fragment, we're done; otherwise,
                 * continue collecting frames.
                 */
                if (ws_is_final(frame.buf)) {
                        *message = frame_message;
                        break;
                }
        }

error:
        free(frame.buf);
        return result;
}


static int ws_init_frame(WebsocketFrame *frame)
{
        free(frame->buf);
        frame->buf = NULL;
        frame->buf_len = 0;
        frame->num_to_read = 2;
        frame->num_read = 0;
        frame->read_state = WSF_START;

        ws_extend_frame_buf(frame, frame->num_to_read);
        return 0;
}

/*
 * Returns 1 if there's still more to read; 0 if no more to read; -1 if
 * something went wrong (which probably means we should close the websocket
 * connection).
 *
 * This function is idempotent.
 */
static int ws_update_read_state(WebsocketFrame *frame)
{
        size_t i;
        uint8_t byte1;
        size_t message_len;
        int mask_len;
        int num_len_bytes;

        /* If there's more to read, then come back when it's done */
        if (frame->num_to_read > 0)
                return 1;

        /* 
         * At this point, all the reading we were planning to do is done. Now we
         * have to figure out what (if anything) to do next. 
         */


        /* If we're done reading the message, we're done with this frame. */
        if (frame->read_state == WSF_READ)
                return 0;


        /*
         * If we're at the beginning, we need to check to see if there's a mask
         * to read and if there are any more length bytes to read. If it's just
         * a short message, we know exactly what's left to read for the frame. 
         */
        if (frame->read_state == WSF_START) {
                byte1 = frame->buf[1];
                mask_len = (byte1 & WS_FRAME_MASK) ? 4 : 0;
                message_len = byte1 & ~WS_FRAME_MASK;

                if (message_len <= SHORT_MESSAGE_LEN) {
                       frame->num_to_read = message_len + mask_len;
                       frame->read_state = WSF_READ;
                }
                else if (message_len == MED_MESSAGE_KEY) {
                        frame->num_to_read = NUM_MED_LEN_BYTES + mask_len;
                        frame->read_state = WSF_READ_MED_LEN;
                }
                else if (message_len == LONG_MESSAGE_KEY) {
                        frame->num_to_read = NUM_LONG_LEN_BYTES + mask_len;
                        frame->read_state = WSF_READ_LONG_LEN;
                }
                else {
                        return -1;
                }
                ws_extend_frame_buf(frame, frame->num_to_read);
                return 1;
        }

        /*
         * If we're not ready the medium or long length bytes, I'm not sure how
         * we got here.
         */
        if (frame->read_state != WSF_READ_MED_LEN &&
                        frame->read_state != WSF_READ_LONG_LEN)
                return -1;

        /*
         * At this point, we can figure out how long the rest of the frame is
         * for the medium and long messages. Once this is done, we can extend
         * the frame buffer to the right length and go into WSF_READ mode.
         */
        if (frame->read_state == WSF_READ_MED_LEN)
                num_len_bytes = NUM_MED_LEN_BYTES;
        else
                num_len_bytes = NUM_LONG_LEN_BYTES;

        message_len = 0;
        for (i = 0; i < num_len_bytes; i++) {
                message_len <<= 8;
                message_len += frame->buf[2 + i];
        }

        byte1 = frame->buf[1];
        mask_len = (byte1 & WS_FRAME_MASK) ? 4 : 0;

        frame->num_to_read = message_len + mask_len;
        frame->read_state = WSF_READ;
        ws_extend_frame_buf(frame, frame->num_to_read);
        return 1;
}



static int ws_extend_frame_buf(WebsocketFrame *frame, size_t more_len)
{
        if ((frame->buf =
             (uint8_t *)realloc(frame->buf, frame->buf_len + more_len)) == NULL)
                err_abort(-1, "Can't realloc in ws_extend_frame_buf");

        frame->buf_len += more_len;
        return 0;
}

/*
 * This function appends bytes read from a socket to a frame that's being read
 * in. The number of bytes to read should have been computed prior to calling
 * this either by "ws_init_frame" or "ws_update_read_state".
 */
static int ws_append_bytes(WebsocketFrame *frame, uint8_t *src, size_t n)
{
        size_t i;
        if (frame->num_read + n > frame->buf_len)
                return -1;

        for (i = 0; i < n; i++) {
                frame->buf[frame->num_read++] = src[i];
                frame->num_to_read--;
        }

        if (frame->num_to_read < 0)
                return -1;

        return 0;
}


const uint8_t *ws_extract_message(const uint8_t *frame)
{
        uint64_t i;
        uint8_t byte0;
        uint8_t byte1;
        uint64_t message_len;
        uint8_t message_start;
        uint8_t *mask;
        uint8_t *result;
        uint8_t num_len_bytes;

        /* Only handling TEXT or BIN frames */
        byte0 = frame[0];
        if (!(byte0 | WS_FRAME_OP_TEXT || byte0 | WS_FRAME_OP_BIN))
                return NULL;

        byte1 = frame[1];

        /*
         * Compute message length
         */
        message_len = byte1 & ~WS_FRAME_MASK;
        if (message_len <= SHORT_MESSAGE_LEN) {
                num_len_bytes = 0;
        }
        else if (message_len == MED_MESSAGE_KEY) {
                num_len_bytes = 2;
                message_len = 0;
        }
        else if (message_len == LONG_MESSAGE_KEY) {
                num_len_bytes = 8;
                message_len = 0;
        }
        else {
                /* Should never get here */
                return NULL;
        }

        /* This only does anything for medium and long messages */
        for (i = 0; i < num_len_bytes; i++) {
                message_len <<= 8;
                message_len += frame[2 + i];
        }

        /*
         * Figure out where message and mask start.
         */
        mask = NULL;
        message_start = 2 + num_len_bytes;
        if (byte1 & WS_FRAME_MASK) {
                mask = (uint8_t *)frame + 2 + num_len_bytes;
                message_start = 2 + num_len_bytes + MASK_LEN;
        }
        
        /*
         * Allocate memory and fill in the message.
         */
        if ((result = (uint8_t *)malloc(message_len + 1)) == NULL)
                err_abort(-1,
                     "Couldn't allocate result for ws_extract_message");

        for (i = 0; i < message_len; i++)
                result[i] = toggle_mask(frame[message_start+i], i, mask);

        /* Add NUL if text frame */
        if (byte0 | WS_FRAME_OP_TEXT)
                result[message_len] = '\0';

        return result;
}


/*
 * Just checks the first byte for the CLOSE bit.
 */
int ws_is_close_frame(const uint8_t* frame_str)
{
        return (frame_str[0] & 0x0f) == WS_FRAME_OP_CLOSE;
}

int ws_is_ping_frame(const uint8_t* frame_str)
{
        return (frame_str[0] & 0x0f) == WS_FRAME_OP_PING;
}

int ws_is_pong_frame(const uint8_t* frame_str)
{
        return (frame_str[0] & 0x0f) == WS_FRAME_OP_PONG;
}

int ws_is_text_frame(const uint8_t* frame_str)
{
        return (frame_str[0] & 0x0f) == WS_FRAME_OP_TEXT;
}

int ws_is_final(const uint8_t* frame_str)
{
        return (frame_str[0] & 0xf0) == WS_FRAME_FIN;
}
