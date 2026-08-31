//
//  MCIMAPOperation.h
//  mailcore2
//
//  Created by DINH Viêt Hoà on 1/12/13.
//  Copyright (c) 2013 MailCore. All rights reserved.
//

#ifndef MAILCORE_MCIMAPOPERATION_H

#define MAILCORE_MCIMAPOPERATION_H

#include <MailCore/MCBaseTypes.h>
#include <MailCore/MCIMAPProgressCallback.h>

#ifdef __cplusplus

namespace mailcore {
    
    class IMAPAsyncConnection;
    class IMAPAsyncSession;
    class IMAPOperationCallback;
    
    class MAILCORE_EXPORT IMAPOperation : public Operation, public IMAPProgressCallback {
    public:
        IMAPOperation();
        virtual ~IMAPOperation();
        
        virtual void setMainSession(IMAPAsyncSession * session);
        virtual IMAPAsyncSession * mainSession();

        virtual void setSession(IMAPAsyncConnection * session);
        virtual IMAPAsyncConnection * session();
        
        virtual void setFolder(String * folder);
        virtual String * folder();
        
        virtual void setUrgent(bool urgent);
        virtual bool isUrgent();
        
        virtual void setImapCallback(IMAPOperationCallback * callback);
        virtual IMAPOperationCallback * imapCallback();
        
        virtual void beforeMain();
        virtual void afterMain();
        virtual void interrupt();

        /** Aborts this operation's IMAP command if it is the one currently running on its
         connection: the blocked read returns at once instead of waiting out the socket timeout, so
         the operations queued behind it (a disconnect, most importantly) run immediately.
         Does nothing when the operation is not the one running.

         Teardown of this connection only - it is left unusable and reconnects on next use, so call
         it for a command that is being abandoned (cancelled, or given up on), never to hurry up a
         command whose result still matters.
         Returns whether this operation was the one the queue was running at that moment. That may
         include a command that finished just as the interrupt landed: its result is intact, but
         the stream is cancelled all the same. */
        virtual bool interruptCurrentCommand();
        
        virtual void start();
        
        // Result.
        virtual void setError(ErrorCode error);
        virtual ErrorCode error();
        
    private:
        IMAPAsyncSession * mMainSession;
        IMAPAsyncConnection * mSession;
        String * mFolder;
        IMAPOperationCallback * mImapCallback;
        ErrorCode mError;
        bool mUrgent;
        
    private:
        virtual void bodyProgress(IMAPSession * session, unsigned int current, unsigned int maximum);
        virtual void bodyProgressOnMainThread(void * context);
        virtual void itemsProgress(IMAPSession * session, unsigned int current, unsigned int maximum);
        virtual void itemsProgressOnMainThread(void * context);
        
    };
    
}

#endif

#endif
