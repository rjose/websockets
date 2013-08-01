#include <stdio.h>
#include <stdlib.h>

#include "lua.h"
#include "lauxlib.h"

#include "qplan_context.h"
#include "repl.h"

#define MAXLINE 1024

extern void err_abort(int status, const char *message);



// TODO: Hook up readline support
/*
 * This is the primary interaction UI for the app.
 */
void *repl_routine(void *arg)
{
        char buf[MAXLINE];
        int error;
        QPlanContext *ctx = (QPlanContext *)arg;

        lua_State *L = ctx->main_lua_state;

        /*
         * REPL
         */
        // TODO: Hook readline up again
        printf("qplan> ");
        while (fgets(buf, sizeof(buf), stdin) != NULL) {
                lock_main(ctx);
                error = luaL_loadstring(L, buf) || lua_pcall(L, 0, 0, 0);

                if (error) {
                        fprintf(stderr, "%s\n", lua_tostring(L, -1));
                        lua_pop(L, 1);
                }
                unlock_main(ctx);
                printf("qplan> ");
        }

        return NULL;
}

