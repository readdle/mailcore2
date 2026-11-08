#include "MCWin32.h" // should be included first.

#include "MCDefines.h"
#include "MCLog.h"

#include <stdarg.h>
#include <string.h>
#include <stdio.h>
#ifndef _MSC_VER
#include <time.h>
#include <unistd.h>
#include <sys/time.h>
#include <pthread.h>
#endif

#if __APPLE__
#include <execinfo.h>
#endif

#include <stdlib.h>

#if defined(ANDROID) || defined(__ANDROID__)
#include <android/log.h>
#endif

static pid_t sPid = -1;
int MCLogEnabled = 0;
int MCLogVerboseEnabled = 1;

INITIALIZE(Log)
{
    sPid = getpid();
}

static MCLogger externalLogger = NULL;

void setMCLogger(MCLogger logger) {
    externalLogger = logger;
}

static void logInternalv(FILE * file,
    const char * user, const char * filename, unsigned int line,
    int dumpStack, const char * format, va_list argp);

void MCLogInternal(const char * user,
    const char * filename, 
    unsigned int line, 
    int dumpStack, 
    const char * format, ...)
{
    va_list argp;
    
    va_start(argp, format);
    logInternalv(stderr, user, filename, line, dumpStack, format, argp);
    va_end(argp);
}

static void logInternalv(FILE * file,
    const char * user, const char * filename, unsigned int line,
    int dumpStack, const char * format, va_list argp)
{
    if (!MCLogEnabled)
        return;
    
    while (1) {
        const char * p = strchr(filename, '/');
        if (p == NULL) {
            break;
        }
        filename = p + 1;
    }
    
    struct timeval tv;
    struct tm tm_value;
    
    if (externalLogger != NULL) {
        char * message;
        vasprintf(&message, format, argp);
        externalLogger(filename, line, message);
        free(message);
        return;
    }

#if defined(ANDROID) || defined(__ANDROID__)
    __android_log_vprint(ANDROID_LOG_INFO, filename, format, argp);
#else

    gettimeofday(&tv, NULL);
    time_t timevalue_sec = tv.tv_sec;
    localtime_r(&timevalue_sec, &tm_value);
    fprintf(file, "%04u-%02u-%02u %02u:%02u:%02u.%03u ", tm_value.tm_year + 1900, tm_value.tm_mon + 1, tm_value.tm_mday, tm_value.tm_hour, tm_value.tm_min, tm_value.tm_sec, (int) (tv.tv_usec / 1000));

#ifdef __MACH__   
    if (pthread_main_np()) {
#else
    if (0) {
#endif
        fprintf(file, "[%i:main] %s:%u: ", sPid, filename, line);
    }
    else {
        unsigned long threadValue;
#ifdef _WIN32
		threadValue = GetCurrentThreadId();
#else
		pthread_t thread_id = pthread_self();
#ifdef _MACH_PORT_T
        threadValue = pthread_mach_thread_np(thread_id);
#else
        threadValue = (unsigned long) thread_id;
#endif

#endif /* _WIN32 */

        fprintf(file, "[%i:%lx] %s:%u: ", sPid, threadValue, filename, line);
    }
    vfprintf(file, format, argp);
    fprintf(file, "\n");
    
    if (dumpStack) {
#if __APPLE__
        void * frame[128];
        int frameCount;
        int i;
    
        fprintf(file, "    ");
        frameCount = backtrace(frame, 128);
        for(i = 0 ; i < frameCount ; i ++) {
            fprintf(file, " %p", frame[i]);
        }
        fprintf(file, "\n");
#endif
        // TODO: other platforms implemented needed.
    }
#endif
}
