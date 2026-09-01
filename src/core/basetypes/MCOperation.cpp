#include "MCOperation.h"

using namespace mailcore;

Operation::Operation()
{
    mCallback = NULL;
    mCancelled = false;
    mShouldRunWhenCancelled = false;

	MCB_LOCK_INIT(&mLock);

#if MC_HAS_GCD
    mCallbackDispatchQueue = getMainQueue();
#endif
}

Operation::~Operation()
{
#if MC_HAS_GCD
    if (mCallbackDispatchQueue != NULL) {
        dispatch_release(mCallbackDispatchQueue);
    }
#endif

    MCB_LOCK_DESTROY(&mLock);
}

void Operation::setCallback(OperationCallback * callback)
{
    mCallback = callback;
}

OperationCallback * Operation::callback()
{
    return mCallback;
}

void Operation::cancel()
{
	MCB_LOCK(&mLock);
    mCancelled = true;
	MCB_UNLOCK(&mLock);
}

void Operation::interrupt()
{
    // Nothing to interrupt by default.
}

bool Operation::isCancelled()
{
	MCB_LOCK(&mLock);
    bool value = mCancelled;
	MCB_UNLOCK(&mLock);
    
    return value;
}

bool Operation::shouldRunWhenCancelled()
{
    return mShouldRunWhenCancelled;
}

void Operation::setShouldRunWhenCancelled(bool shouldRunWhenCancelled)
{
    mShouldRunWhenCancelled = shouldRunWhenCancelled;
}

void Operation::beforeMain()
{
}

void Operation::main()
{
}

void Operation::afterMain()
{
}

void Operation::start()
{
}

#if MC_HAS_GCD
void Operation::setCallbackDispatchQueue(dispatch_queue_t callbackDispatchQueue)
{
    if (mCallbackDispatchQueue != NULL) {
        dispatch_release(mCallbackDispatchQueue);
    }
    mCallbackDispatchQueue = callbackDispatchQueue;
    if (mCallbackDispatchQueue != NULL) {
        dispatch_retain(mCallbackDispatchQueue);
    }
}

dispatch_queue_t Operation::callbackDispatchQueue()
{
    return mCallbackDispatchQueue;
}
#endif

void Operation::performMethodOnCallbackThread(Method method, void * context, bool waitUntilDone)
{
#if MC_HAS_GCD
    dispatch_queue_t queue = mCallbackDispatchQueue;
    if (queue == NULL) {
        queue = getMainQueue();
    }
    performMethodOnDispatchQueue(method, context, queue, waitUntilDone);
#else
    performMethodOnMainThread(method, context, waitUntilDone);
#endif
}
