#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <err.h>

#include <pthread.h>

#include "lua.h"
#include "lauxlib.h"

#include "tcp_io.h"
#include "web.h"

extern void err_abort(int status, const char *message);


#define SA struct sockaddr
#define LISTENQ 1024
#define MAXLINE 1024

static void *handle_request_routine(void *);


// TODO: Allow port to be configured
/*
 * This will be run in a thread and listens for web requests. Each request is
 * handled in its own thread via handle_request_routine.
 */
void *web_routine(void *arg)
{
        QPlanContext *ctx = (QPlanContext *)arg;
        WebHandlerContext *handler_context;

	int listenfd, connfd;
	socklen_t clilen;
	struct sockaddr_in cliaddr, servaddr;
        pthread_t tid;
        int option = 1;
        int status;

	listenfd = socket(AF_INET, SOCK_STREAM, 0);

	/* Reuse port so we don't have to wait before the program can be
	 * restarted because of the TIME_WAIT state. */
        if ( setsockopt(listenfd,
                        SOL_SOCKET,
                        SO_REUSEADDR,
                        &option, sizeof(option)) != 0)
                err(1, "setsockopt failed");

	bzero(&servaddr, sizeof(servaddr));
	servaddr.sin_family = AF_INET;
	servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
	servaddr.sin_port = htons(8888);

	if (bind(listenfd, (SA*) &servaddr, sizeof(servaddr)) < 0)
		err(1, "Problem binding to descriptor:%d", listenfd);

	if (listen(listenfd, LISTENQ) < 0)
		err(1, "Problem listening to descriptor: %d", listenfd);

        /*
         * Listen for connections
         */
        clilen = sizeof(cliaddr);
        while(1) {
		connfd = accept(listenfd, (SA*) &cliaddr, &clilen);

                /*
                 * Set up handler context
                 */
                handler_context = (WebHandlerContext *)malloc(sizeof(WebHandlerContext));
                if (handler_context == NULL)
                        err_abort(-1, "Unable to allocate memory");
                handler_context->context = ctx;
                handler_context->connfd = connfd;

                status = pthread_create(&tid, NULL, handle_request_routine,
                                                       (void *)handler_context);
                if (status != 0)
                        err_abort(status, "Create web thread");

                if (pthread_detach(tid) != 0)
                        err_abort(-1, "Couldn't detach thread");
        }

        return NULL;
}


/*
 * Every web request is handled in its own thread. In general, this requires
 * access to the main lua state. The web routing and handling code is written in
 * lua and is also in the main lua state within the "web" module.
 */
static void *handle_request_routine(void *arg)
{
        WebHandlerContext *req_context = (WebHandlerContext *)arg;
        char *request_string;
	char buf[MAXLINE];
        int connfd = req_context->connfd;
        int cur_len;
        int str_capacity;
        int req_len = 0;
        lua_State *L_main = req_context->context->main_lua_state;
        int i;
        size_t res_len;
        const char *tmp;
        char *res_str;
        int error;

        if ((request_string = malloc(sizeof(char) * MAXLINE)) == NULL)
                err_abort(-1, "Couldn't allocate memory");
        str_capacity = MAXLINE;

        /*
         * Read in request
         */
	while ((cur_len = my_readline(connfd, buf, MAXLINE)) > 0) {
		if (strcmp(buf, "\r\n") == 0)
			break;

                /*
                 * Build request string
                 */
                if ((req_len + cur_len) >= str_capacity) {
                        if ((request_string = realloc(request_string,
                            sizeof(char) * (str_capacity + MAXLINE))) == NULL)
                                err_abort(-1, "Couldn't realloc memory");

                        str_capacity += MAXLINE;
                }
                for (i = 0; i < cur_len; i++)
                        request_string[req_len++] = buf[i];
	}
        request_string[req_len] = '\0';

        /*
         * Call request handler
         */
        lock_main(req_context->context);
        lua_getglobal(L_main, "WebUI"); // This is set when requiring qplan.lua
        lua_pushstring(L_main, "handle_request");
        lua_gettable(L_main, -2);
        lua_pushlstring(L_main, request_string, req_len);
        error = lua_pcall(L_main, 1, 1, 0);
        if (error) {
                fprintf(stderr, "%s\n", lua_tostring(L_main, -1));
                lua_pop(L_main, 1);
                goto error;
        }

        /* Copy result string */
        tmp = lua_tolstring(L_main, -1, &res_len);
        if ((res_str = (char *)malloc(sizeof(char)*res_len)) == NULL)
                err_abort(-1, "Couldn't allocate memory");
        strncpy(res_str, tmp, res_len);
        lua_pop(L_main, 1);
        my_writen(connfd, res_str, res_len);

error:
        unlock_main(req_context->context);
        close(connfd);
        free(request_string);
        free(req_context);
        return NULL;
}
