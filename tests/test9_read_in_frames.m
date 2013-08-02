#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "../ws.h"
#include "test_util.h"
#import "Testing.h"


#define BUF_LEN 100


/* ============================================================================
 * Main
 */


static uint8_t input_ping_frame[] = {0x89, 0x00};
static uint8_t input_pong_frame[] = {0x8A, 0x00};
static uint8_t input_close_frame[] = {0x88, 0x00};

static uint8_t *source_bytes;

// TODO: Configure to just read 2 bytes at a time
/*
 * NOTE: source_bytes needs to be set first
 */
static size_t read_bytes(int fd, char *ptr, size_t maxlen)
{
        int i;
        for (i = 0; i < maxlen; i++)
                *ptr++ = *source_bytes++;
        return i;
}

int main()
{
        enum WebsocketFrameType frame_type;
        char *message = NULL;
        int fd = 1;

        START_SET("Read ping, pong, close frame");

        source_bytes = input_ping_frame;
        frame_type = ws_read_next_message(fd, read_bytes, &message);
        pass(frame_type == WS_FT_PING, "Read ping frame");

        source_bytes = input_pong_frame;
        frame_type = ws_read_next_message(fd, read_bytes, &message);
        pass(frame_type == WS_FT_PONG, "Read pong frame");

        source_bytes = input_close_frame;
        frame_type = ws_read_next_message(fd, read_bytes, &message);
        pass(frame_type == WS_FT_CLOSE, "Read close frame");

        END_SET("Read ping, pong, close frame");

        return 0;
}

static void demo_read_bytes()
{
        uint8_t buf[BUF_LEN];
        size_t num_read;

        source_bytes = input_ping_frame;
        num_read = read_bytes(1, buf, 2);
        printf("num_read: %d, byte0: 0x%x\n", num_read, buf[0]);
}
