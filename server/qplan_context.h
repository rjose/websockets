#ifndef QPLAN_CONTEXT_H
#define QPLAN_CONTEXT_H

#include "pthread.h"
#include "lua.h"


/* ----------------------------------------------------------------------------
 * Data structure
 */

/*
 * This provides access to the main lua state within the app. Any operation on
 * the lua state needs "main_mutex" to be locked first.
 */
typedef struct QPlanContext_ {
        lua_State *main_lua_state;
        pthread_mutex_t *main_mutex;
} QPlanContext;


/* ----------------------------------------------------------------------------
 * API
 */

void lock_main(QPlanContext *ctx);

void unlock_main(QPlanContext *ctx);

#endif
