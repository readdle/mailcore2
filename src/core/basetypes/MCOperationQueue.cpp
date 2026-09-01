#include "MCOperationQueue.h"

#include <libetpan/libetpan.h>

#include "MCOperation.h"
#include "MCOperationCallback.h"
#include "MCOperationQueueCallback.h"
#include "MCMainThread.h"
#include "MCUtils.h"
#include "MCArray.h"
#include "MCLog.h"
#include "MCAutoreleasePool.h"
#if defined(__ANDROID) || defined(ANDROID)
#include "MCMainThreadAndroid.h"
#endif
#include "MCAssert.h"

#ifdef _MSC_VER
#include <process.h>
#endif

using namespace mailcore;

OperationQueue::OperationQueue()
{
    mOperations = new Array();
    mStarted = false;
	MCB_LOCK_INIT(&mLock);
    mWaiting = false;
    mOperationSem = mailsem_new();
    mStartSem = mailsem_new();
    mStopSem = mailsem_new();
    mWaitingFinishedSem = mailsem_new();
    mQuitting = false;
    mRunningOperation = NULL;
    mCallback = NULL;
#if MC_HAS_GCD
    mDispatchQueue = getMainQueue();
#endif
    _pendingCheckRunning = false;
}

OperationQueue::~OperationQueue()
{
#if MC_HAS_GCD
    if (mDispatchQueue != NULL) {
        dispatch_release(mDispatchQueue);
    }
#endif
    MC_SAFE_RELEASE(mOperations);
    MCB_LOCK_DESTROY(&mLock);
    mailsem_free(mOperationSem);
    mailsem_free(mStartSem);
    mailsem_free(mStopSem);
    mailsem_free(mWaitingFinishedSem);
}

void OperationQueue::addOperation(Operation * op)
{
	MCB_LOCK(&mLock);
    mOperations->addObject(op);
	MCB_UNLOCK(&mLock);
    mailsem_up(mOperationSem);
    startThread();
}

bool OperationQueue::interruptRunningOperation(Operation * op)
{
    bool interrupted = false;

    // interrupt() runs with the lock held on purpose: releasing it first would let the operation
    // finish and the next one start before the interruption lands, which is precisely the mistake
    // this method exists to prevent. It is safe as long as interrupt() implementations stay
    // non-blocking and never reach back into this queue.
    MCB_LOCK(&mLock);
    if ((op != NULL) && (mRunningOperation == op)) {
        op->interrupt();
        interrupted = true;
    }
    MCB_UNLOCK(&mLock);

    return interrupted;
}

void OperationQueue::cancelAllOperations()
{
	MCB_LOCK(&mLock);
    for (unsigned int i = 0 ; i < mOperations->count() ; i ++) {
        Operation * op = (Operation *) mOperations->objectAtIndex(i);
        op->cancel();
    }
	MCB_UNLOCK(&mLock);
}

void OperationQueue::runOperationsOnThread(OperationQueue * queue)
{
    queue->runOperations();
}

void OperationQueue::runOperations()
{
//#if defined(__ANDROID) || defined(ANDROID)
//    androidSetupThread();
//#endif

    MCLog("start thread");
    mailsem_up(mStartSem);
    
    while (true) {
        Operation * op = NULL;
        bool needsCheckRunning = false;
        bool quitting;
        
        AutoreleasePool * pool = new AutoreleasePool();
        
        mailsem_down(mOperationSem);
        
		MCB_LOCK(&mLock);
        if (mOperations->count() > 0) {
            op = (Operation *) mOperations->objectAtIndex(0);
        }
        quitting = mQuitting;
        MCB_UNLOCK(&mLock);

        //MCLog("quitting %i %p", mQuitting, op);
        if ((op == NULL) && quitting) {
            MCLog("stopping %p", this);
            mailsem_up(mStopSem);
            
            retain(); // (2)
#if MC_HAS_GCD
            performMethodOnDispatchQueue((Object::Method) &OperationQueue::stoppedOnMainThread, NULL, mDispatchQueue, true);
#else
            performMethodOnMainThread((Object::Method) &OperationQueue::stoppedOnMainThread, NULL, true);
#endif
            
            pool->release();
            break;
        }

        MCAssert(op != NULL);
        performOnCallbackThread(op, (Object::Method) &OperationQueue::beforeMain, op, true);
        
        // Published only around main(): a cancelled operation whose main() is skipped never counts
        // as running, so nobody can mistake an idle connection for a busy one.
        if (!op->isCancelled() || op->shouldRunWhenCancelled()) {
            MCB_LOCK(&mLock);
            mRunningOperation = op;
            MCB_UNLOCK(&mLock);

            op->main();
        }
        
        op->retain()->autorelease();
        
		MCB_LOCK(&mLock);
        mRunningOperation = NULL;
        mOperations->removeObjectAtIndex(0);
        if (mOperations->count() == 0) {
            if (mWaiting) {
                mailsem_up(mWaitingFinishedSem);
            }
            needsCheckRunning = true;
        }
		MCB_UNLOCK(&mLock);
        
        if (!op->isCancelled()) {
            performOnCallbackThread(op, (Object::Method) &OperationQueue::callbackOnMainThread, op, true);
        }
        
        if (needsCheckRunning) {
            retain(); // (1)
            //MCLog("check running %p", this);
#if MC_HAS_GCD
            performMethodOnDispatchQueue((Object::Method) &OperationQueue::checkRunningOnMainThread, this, mDispatchQueue);
#else
            performMethodOnMainThread((Object::Method) &OperationQueue::checkRunningOnMainThread, this);
#endif
        }
        
        pool->release();
    }
    MCLog("cleanup thread %p", this);
#if defined(_MSC_VER)
	AutoreleasePool::destroyAutoreleasePoolStack();
#endif

//#if defined(__ANDROID) || defined(ANDROID)
//    androidUnsetupThread();
//#endif
}

void OperationQueue::performOnCallbackThread(Operation * op, Method method, void * context, bool waitUntilDone)
{
#if MC_HAS_GCD
    dispatch_queue_t queue = op->callbackDispatchQueue();
    if (queue == NULL) {
        queue = getMainQueue();
    }
    performMethodOnDispatchQueue(method, context, queue, waitUntilDone);
#else
    performMethodOnMainThread(method, context, waitUntilDone);
#endif
}

void OperationQueue::beforeMain(Operation * op)
{
    op->beforeMain();
}

void OperationQueue::callbackOnMainThread(Operation * op)
{
    op->afterMain();
    
    if (op->isCancelled())
        return;
    
    if (op->callback() != NULL) {
        op->callback()->operationFinished(op);
    }
}

void OperationQueue::checkRunningOnMainThread(void * context)
{
    retain(); // (4)
    if (_pendingCheckRunning) {
#if MC_HAS_GCD
        cancelDelayedPerformMethodOnDispatchQueue((Object::Method) &OperationQueue::checkRunningAfterDelay, NULL, mDispatchQueue);
#else
        cancelDelayedPerformMethod((Object::Method) &OperationQueue::checkRunningAfterDelay, NULL);
#endif
        release(); // (4)
    }
    _pendingCheckRunning = true;
    
#if MC_HAS_GCD
    performMethodOnDispatchQueueAfterDelay((Object::Method) &OperationQueue::checkRunningAfterDelay, NULL, mDispatchQueue, 1);
#else
    performMethodAfterDelay((Object::Method) &OperationQueue::checkRunningAfterDelay, NULL, 1);
#endif

    release(); // (1)
}

void OperationQueue::checkRunningAfterDelay(void * context)
{
    _pendingCheckRunning = false;
	MCB_LOCK(&mLock);
    if (!mQuitting) {
        if (mOperations->count() == 0) {
            MCLog("trying to quit %p", this);
            mailsem_up(mOperationSem);
            mQuitting = true;
        }
    }
	MCB_UNLOCK(&mLock);
    
    // Number of operations can't be changed because it runs on main thread.
    // And addOperation() should also be called from main thread.
    
    release(); // (4)
}

void OperationQueue::stoppedOnMainThread(void * context)
{
    MCLog("thread stopped %p", this);
    mailsem_down(mStopSem);
    mStarted = false;
    
    if (mCallback) {
        mCallback->queueStoppedRunning();
    }
    
    if (mOperations->count() > 0) {
        //Operations have been added while thread was quitting, so restart automatically
        startThread();
    }

    release(); // (2)

    release(); // (3)
}

void OperationQueue::startThread()
{
    if (mStarted)
        return;
    
    if (mCallback) {
        mCallback->queueStartRunning();
    }
    
    retain(); // (3)
    mQuitting = false;
    mStarted = true;
#ifdef _MSC_VER
	_beginthread(reinterpret_cast<_beginthread_proc_type>(OperationQueue::runOperationsOnThread), 0, this);
#else
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    pthread_create(&mThreadID, &attr, (void * (*)(void *)) OperationQueue::runOperationsOnThread, this);
    pthread_attr_destroy(&attr);
#endif
    mailsem_down(mStartSem);
}

unsigned int OperationQueue::count()
{
    unsigned int count;
    
	MCB_LOCK(&mLock);
    count = mOperations->count();
	MCB_UNLOCK(&mLock);
    
    return count;
}

void OperationQueue::setCallback(OperationQueueCallback * callback)
{
    mCallback = callback;
}

OperationQueueCallback * OperationQueue::callback()
{
    return mCallback;
}

#if 0
void OperationQueue::waitUntilAllOperationsAreFinished()
{
    bool waiting = false;
    
    pthread_mutex_lock(&mLock);
    if (mOperations->count() > 0) {
        mWaiting = true;
        waiting = true;
    }
    pthread_mutex_unlock(&mLock);
    
    if (waiting) {
        sem_wait(&mWaitingFinishedSem);
    }
    mWaiting = false;
}
#endif

#if MC_HAS_GCD
void OperationQueue::setDispatchQueue(dispatch_queue_t dispatchQueue)
{
    if (mDispatchQueue != NULL) {
        dispatch_release(mDispatchQueue);
    }
    mDispatchQueue = dispatchQueue;
    if (mDispatchQueue != NULL) {
        dispatch_retain(mDispatchQueue);
    }
}

dispatch_queue_t OperationQueue::dispatchQueue()
{
    return mDispatchQueue;
}
#endif
