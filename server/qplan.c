#include <err.h>
#include <errno.h>
#include <pthread.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "qplan_context.h"
#include "repl.h"
#include "web.h"

// TODO: Move this to a util file
void err_abort(int status, const char *message)
{
	fprintf(stderr, message);
	exit(status);
}

static lua_State *init_lua_state();


int main(int argc, char *argv[])
{
	void *thread_result;
	long status;
        pthread_t repl_thread_id;
        pthread_t web_thread_id;
        pthread_mutex_t main_mutex = PTHREAD_MUTEX_INITIALIZER;
        lua_State *L_main;

        L_main = init_lua_state();


        /*
         * Set up context and spin up threads
         */
        QPlanContext qplan_context;
        qplan_context.main_lua_state = L_main;
        qplan_context.main_mutex = &main_mutex;

	/* Create REPL thread */
	status = pthread_create(&repl_thread_id, NULL, repl_routine, (void *)&qplan_context);
	if (status != 0)
		err_abort(status, "Create repl thread");

        /* Create web server thread */
	status = pthread_create(&web_thread_id, NULL, web_routine, (void *)&qplan_context);
	if (status != 0)
		err_abort(status, "Create web thread");
	status = pthread_detach(web_thread_id);
	if (status != 0)
		err_abort(status, "Problem detaching web thread");


	/* Join REPL thread */
	status = pthread_join(repl_thread_id, &thread_result);
	if (status != 0)
		err_abort(status, "Join thread");

        /*
         * Clean up
         */
        lua_close(L_main);
	printf("We are most successfully done!\n");
	return 0;
}


static lua_State *init_lua_state()
{
        lua_State *result = luaL_newstate();
        luaL_openlibs(result);

        /* Load qplan functionality */
        lua_getglobal(result, "require");
        lua_pushstring(result, "app.qplan");
        if (lua_pcall(result, 1, 1, 0) != LUA_OK)
                luaL_error(result, "Problem requiring qplan.lua: %s",
                                lua_tostring(result, -1));

        // TODO: Init the data from someplace
#if 0
        /* Load version specified from commandline */
        lua_getglobal(result, "qplan_init");
        lua_pushnumber(result, version);
        if (lua_pcall(result, 1, 0, 0) != LUA_OK)
                luaL_error(result, "Problem calling lua function: %s",
                                lua_tostring(result, -1));
#endif
        return result;
}
