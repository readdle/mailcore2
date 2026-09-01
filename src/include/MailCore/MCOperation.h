#ifndef MAILCORE_MCOPERATION_H

#define MAILCORE_MCOPERATION_H

#include <MailCore/MCObject.h>
#include <MailCore/MCBasicLock.h>

#ifdef __cplusplus

namespace mailcore {
    
    class OperationCallback;
    
    class MAILCORE_EXPORT Operation : public Object {
    public:
        Operation();
        virtual ~Operation();
        
        virtual void setCallback(OperationCallback * callback);
        virtual OperationCallback * callback();
        
        virtual void cancel();

        /** Aborts whatever this operation is doing right now. Called by the queue, and only while
         this operation is the one it is executing - so an implementation may assume it owns the
         resource it is about to break. Does nothing by default. */
        virtual void interrupt();

        virtual bool isCancelled();
        
        // Will be called on main thread.
        virtual void beforeMain();
        
        virtual void main();
        
        // Will be called on main thread.
        virtual void afterMain();
        
        virtual void start();
        
#if MC_HAS_GCD
        virtual void setCallbackDispatchQueue(dispatch_queue_t callbackDispatchQueue);
        virtual dispatch_queue_t callbackDispatchQueue();
#endif
        void performMethodOnCallbackThread(Method method, void * context, bool waitUntilDone = false);
        
        virtual bool shouldRunWhenCancelled();
        virtual void setShouldRunWhenCancelled(bool shouldRunWhenCancelled);
        
    private:
        OperationCallback * mCallback;
        bool mCancelled;
        bool mShouldRunWhenCancelled;
		MCB_LOCK_TYPE mLock;
#if MC_HAS_GCD
        dispatch_queue_t mCallbackDispatchQueue;
#endif
        
    };
    
}

#endif

#endif
