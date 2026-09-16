#ifndef mailcore2_MCBasicLock_h
#define mailcore2_MCBasicLock_h

#ifdef _MSC_VER

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#define MCB_LOCK_TYPE SRWLOCK
#define MCB_LOCK_INITIAL_VALUE SRWLOCK_INIT
#define MCB_LOCK_INIT(l) InitializeSRWLock(l)
#define MCB_LOCK_DESTROY(l)
#define MCB_LOCK(l) AcquireSRWLockExclusive(l)
#define MCB_UNLOCK(l) ReleaseSRWLockExclusive(l)

#define MCB_COND_TYPE CONDITION_VARIABLE
#define MCB_COND_INIT(c) InitializeConditionVariable(c)
#define MCB_COND_DESTROY(c)
/* 0 = the lock is held exclusively, which is how MCB_LOCK takes it. */
#define MCB_COND_WAIT(c, l) SleepConditionVariableSRW(c, l, INFINITE, 0)
#define MCB_COND_BROADCAST(c) WakeAllConditionVariable(c)

#else

#include <pthread.h>

#define MCB_LOCK_TYPE pthread_mutex_t
#define MCB_LOCK_INITIAL_VALUE PTHREAD_MUTEX_INITIALIZER
#define MCB_LOCK_INIT(l) pthread_mutex_init(l, NULL)
#define MCB_LOCK_DESTROY(l) pthread_mutex_destroy(l)
#define MCB_LOCK(l) pthread_mutex_lock(l)
#define MCB_UNLOCK(l) pthread_mutex_unlock(l)

#define MCB_COND_TYPE pthread_cond_t
#define MCB_COND_INIT(c) pthread_cond_init(c, NULL)
#define MCB_COND_DESTROY(c) pthread_cond_destroy(c)
#define MCB_COND_WAIT(c, l) pthread_cond_wait(c, l)
#define MCB_COND_BROADCAST(c) pthread_cond_broadcast(c)

#endif

#endif /* mailcore2_MCBasicLock_h */
