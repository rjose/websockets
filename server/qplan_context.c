#include "qplan_context.h"

extern void err_abort(int status, const char *message);


void lock_main(QPlanContext *ctx)
{
        if (pthread_mutex_lock(ctx->main_mutex) != 0)
                err_abort(-1, "Problem locking main mutex");
}

void unlock_main(QPlanContext *ctx)
{
        if (pthread_mutex_unlock(ctx->main_mutex) != 0)
                err_abort(-1, "Problem unlocking main mutex");
}

