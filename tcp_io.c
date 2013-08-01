#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

#include <err.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <pthread.h>

#define SA struct sockaddr
#define MAXLINE 1024
#define LISTENQ 1024

static pthread_key_t rl_key;
static pthread_once_t rl_once = PTHREAD_ONCE_INIT;

typedef struct {
	int rl_cnt;
	char *rl_bufptr;
	char rl_buf[MAXLINE];
} Rline;

/*
 * Static declarations 
 */ 
static ssize_t writen(int, const void *, size_t);
static void readline_destructor(void *);
static void readline_once();
static ssize_t my_read(Rline *, int, char *);

/*
 * Implementation
 */

static ssize_t						/* Write "n" bytes to a descriptor. */
writen(int fd, const void *vptr, size_t n)
{
	size_t		nleft;
	ssize_t		nwritten;
	const char	*ptr;

	ptr = vptr;
	nleft = n;
	while (nleft > 0) {
		if ( (nwritten = write(fd, ptr, nleft)) <= 0) {
			if (nwritten < 0 && errno == EINTR)
				nwritten = 0;		/* and call write() again */
			else
				return(-1);			/* error */
		}

		nleft -= nwritten;
		ptr   += nwritten;
	}
	return(n);
}
/* end writen */

void
my_writen(int fd, const void *ptr, size_t nbytes)
{
	if (writen(fd, ptr, nbytes) != nbytes)
		err(1, "writen error");
}


static void
readline_destructor(void *ptr)
{
	free(ptr);
}

static void
readline_once()
{
	if (pthread_key_create(&rl_key, readline_destructor) != 0)
		err(1, "Problem creating pthread key");
}

static ssize_t
my_read(Rline *tsd, int fd, char *ptr)
{
	if (tsd->rl_cnt <= 0) {
again:
		if ( (tsd->rl_cnt = read(fd, tsd->rl_buf, MAXLINE)) < 0 ) {
			if (errno == EINTR)
				goto again;
			return -1;
		}
		else if (tsd->rl_cnt == 0)
			return 0;
		tsd->rl_bufptr = tsd->rl_buf; 	/* Reset rl_bufptr to beginning */
	}

	tsd->rl_cnt--;
	*ptr = *tsd->rl_bufptr++;
	return 1;
}

ssize_t
my_readline(int fd, void *vptr, size_t maxlen)
{
	size_t n, rc;
	char c, *ptr;
	Rline *tsd;

	if ( pthread_once(&rl_once, readline_once) != 0)
		err(1, "Problem with pthread_once");
	if ( (tsd = pthread_getspecific(rl_key)) == NULL ) {
		tsd = calloc(1, sizeof(Rline));
		if (tsd == NULL)
			err(1, "Problem with calloc");
		if ( pthread_setspecific(rl_key, tsd) != 0)
			err(1, "Problem with pthread_setspecific");
	}
	ptr = vptr;
	for (n=1; n < maxlen; n++) {
		if ( (rc = my_read(tsd, fd, &c)) == 1) {
			*ptr++ = c;
			if (c == '\n')
				break;
		}
		else if (rc == 0) { 	/* Got EOF */
			*ptr = 0;
			return (n - 1);
		}
		else
			return -1;
	}

	*ptr = 0;
	return n;
}
