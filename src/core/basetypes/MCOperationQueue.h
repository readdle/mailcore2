#ifndef MAILCORE_MCOPERATIONQUEUE_H

#define MAILCORE_MCOPERATIONQUEUE_H

#include <MailCore/MCBasicLock.h>
#include <MailCore/MCObject.h>
#include <MailCore/MCLibetpanTypes.h>

#ifdef __cplusplus

namespace mailcore {
    
    class Operation;
    class OperationQueueCallback;
    class Array;
    
    class MAILCORE_EXPORT OperationQueue : public Object {
    public:
        OperationQueue();
        virtual ~OperationQueue();
        
        virtual void addOperation(Operation * op);
        virtual void cancelAllOperations();

        /** Calls interrupt() on `op` if it is the operation whose main() the queue is executing
         right now. The check and the call happen under the queue's lock, so the operation cannot
         finish - and another one cannot take over the resource - in between.
         Lets a caller abort "the command my operation is running" without the risk of aborting
         whatever started after it. Returns whether interrupt() was called - a caller that measures
         the effect needs to tell "there was a command to break" from "there was nothing". */
        virtual bool interruptRunningOperation(Operation * op);
        
        virtual unsigned int count();
        
        virtual void setCallback(OperationQueueCallback * callback);
        virtual OperationQueueCallback * callback();
        
#if MC_HAS_GCD
        virtual void setDispatchQueue(dispatch_queue_t dispatchQueue);
        virtual dispatch_queue_t dispatchQueue();
#endif
        
    private:
        Array * mOperations;
#ifndef _MSC_VER
		pthread_t mThreadID;
#endif
        bool mStarted;
        struct mailsem * mOperationSem;
        struct mailsem * mStartSem;
        struct mailsem * mStopSem;
		MCB_LOCK_TYPE mLock;
        bool mWaiting;
        struct mailsem * mWaitingFinishedSem;
        bool mQuitting;
        Operation * mRunningOperation;
        OperationQueueCallback * mCallback;
#if MC_HAS_GCD
        dispatch_queue_t mDispatchQueue;
#endif
        bool _pendingCheckRunning;
        
        void startThread();
        static void runOperationsOnThread(OperationQueue * queue);
        void runOperations();
        void beforeMain(Operation * op);
        void callbackOnMainThread(Operation * op);
        void checkRunningOnMainThread(void * context);
        void checkRunningAfterDelay(void * context);
        void stoppedOnMainThread(void * context);
        void performOnCallbackThread(Operation * op, Method method, void * context, bool waitUntilDone);
    };
    
}

#endif

#endif
