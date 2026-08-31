//
//  IMAPAsyncConnection.cc
//  mailcore2
//
//  Created by DINH Viêt Hoà on 1/12/13.
//  Copyright (c) 2013 MailCore. All rights reserved.
//

#include "MCIMAPAsyncConnection.h"

#include "MCIMAP.h"
#include "MCIMAPFolderInfoOperation.h"
#include "MCIMAPFolderStatusOperation.h"
#include "MCIMAPFetchFoldersOperation.h"
#include "MCIMAPRenameFolderOperation.h"
#include "MCIMAPDeleteFolderOperation.h"
#include "MCIMAPCreateFolderOperation.h"
#include "MCIMAPSubscribeFolderOperation.h"
#include "MCIMAPExpungeOperation.h"
#include "MCIMAPAppendMessageOperation.h"
#include "MCIMAPCopyMessagesOperation.h"
#include "MCIMAPFetchMessagesOperation.h"
#include "MCIMAPFetchContentOperation.h"
#include "MCIMAPFetchContentToFileOperation.h"
#include "MCIMAPFetchParsedContentOperation.h"
#include "MCIMAPStoreFlagsOperation.h"
#include "MCIMAPStoreLabelsOperation.h"
#include "MCIMAPSearchOperation.h"
#include "MCIMAPConnectOperation.h"
#include "MCIMAPCheckAccountOperation.h"
#include "MCIMAPFetchNamespaceOperation.h"
#include "MCIMAPIdleOperation.h"
#include "MCIMAPIdentityOperation.h"
#include "MCIMAPCapabilityOperation.h"
#include "MCIMAPQuotaOperation.h"
#include "MCOperationQueueCallback.h"
#include "MCIMAPDisconnectOperation.h"
#include "MCIMAPNoopOperation.h"
#include "MCIMAPAsyncSession.h"
#include "MCConnectionLogger.h"
#include "MCIMAPMessageRenderingOperation.h"
#include "MCIMAPCustomCommandOperation.h"
#include "MCIMAPIdentity.h"

using namespace mailcore;

namespace mailcore {

    class IMAPOperationQueueCallback : public Object, public OperationQueueCallback {
    public:
        IMAPOperationQueueCallback(IMAPAsyncConnection * connection) {
            mConnection = connection;
        }

        virtual ~IMAPOperationQueueCallback() {
        }

        virtual void queueStartRunning() {
            mConnection->setQueueRunning(true);
            if (mConnection->owner()) {
                mConnection->owner()->operationRunningStateChanged();
            }
            mConnection->queueStartRunning();
        }

        virtual void queueStoppedRunning() {
            mConnection->setQueueRunning(false);
            mConnection->tryAutomaticDisconnect();
            if (mConnection->owner()) {
                mConnection->owner()->operationRunningStateChanged();
            }
            mConnection->queueStoppedRunning();
        }

    private:
        IMAPAsyncConnection * mConnection;
    };

    class IMAPConnectionLogger : public Object, public ConnectionLogger {
    public:
        IMAPConnectionLogger(IMAPAsyncConnection * connection) {
            mConnection = connection;
        }

        virtual ~IMAPConnectionLogger() {
        }

        virtual void log(void * sender, ConnectionLogType logType, Data * buffer)
        {
            mConnection->logConnection(logType, buffer);
        }

    private:
        IMAPAsyncConnection * mConnection;
    };

}

IMAPAsyncConnection::IMAPAsyncConnection()
{
    mSession = new IMAPSession();
    mQueue = new OperationQueue();
    mDefaultNamespace = NULL;
    mClientIdentity = new IMAPIdentity();
    mLastFolder = NULL;
    mQueueCallback = new IMAPOperationQueueCallback(this);
    mQueue->setCallback(mQueueCallback);
    mOwner = NULL;
    mConnectionLogger = NULL;
    MCB_LOCK_INIT(&mConnectionLoggerLock);
    mInternalLogger = new IMAPConnectionLogger(this);
    mAutomaticConfigurationEnabled = true;
    mQueueRunning = false;
    mScheduledAutomaticDisconnect = false;
    mReserved = false;
    mAutomaticDisconnectDelay = 30;
}

IMAPAsyncConnection::~IMAPAsyncConnection()
{
#if MC_HAS_GCD
    cancelDelayedPerformMethodOnDispatchQueue((Object::Method) &IMAPAsyncConnection::tryAutomaticDisconnectAfterDelay, NULL, dispatchQueue());
#else
    cancelDelayedPerformMethod((Object::Method) &IMAPAsyncConnection::tryAutomaticDisconnectAfterDelay, NULL);
#endif
    MCB_LOCK_DESTROY(&mConnectionLoggerLock);
    MC_SAFE_RELEASE(mInternalLogger);
    MC_SAFE_RELEASE(mQueueCallback);
    MC_SAFE_RELEASE(mLastFolder);
    MC_SAFE_RELEASE(mClientIdentity);
    MC_SAFE_RELEASE(mDefaultNamespace);
    MC_SAFE_RELEASE(mQueue);
    MC_SAFE_RELEASE(mSession);
}

void IMAPAsyncConnection::setHostname(String * hostname)
{
    mSession->setHostname(hostname);
}

String * IMAPAsyncConnection::hostname()
{
    return mSession->hostname();
}

void IMAPAsyncConnection::setPort(unsigned int port)
{
    mSession->setPort(port);
}

unsigned int IMAPAsyncConnection::port()
{
    return mSession->port();
}

void IMAPAsyncConnection::setUsername(String * username)
{
    mSession->setUsername(username);
}

String * IMAPAsyncConnection::username()
{
    return mSession->username();
}

void IMAPAsyncConnection::setPassword(String * password)
{
    mSession->setPassword(password);
}

String * IMAPAsyncConnection::password()
{
    return mSession->password();
}

void IMAPAsyncConnection::setOAuth2Token(String * token)
{
    mSession->setOAuth2Token(token);
}

String * IMAPAsyncConnection::OAuth2Token()
{
    return mSession->OAuth2Token();
}

void IMAPAsyncConnection::setAuthType(AuthType authType)
{
    mSession->setAuthType(authType);
}

AuthType IMAPAsyncConnection::authType()
{
    return mSession->authType();
}

void IMAPAsyncConnection::setConnectionType(ConnectionType connectionType)
{
    mSession->setConnectionType(connectionType);
}

ConnectionType IMAPAsyncConnection::connectionType()
{
    return mSession->connectionType();
}

void IMAPAsyncConnection::setTimeout(time_t timeout)
{
    mSession->setTimeout(timeout);
}

time_t IMAPAsyncConnection::timeout()
{
    return mSession->timeout();
}

void IMAPAsyncConnection::setCheckCertificateEnabled(bool enabled)
{
    mSession->setCheckCertificateEnabled(enabled);
}

bool IMAPAsyncConnection::isCheckCertificateEnabled()
{
    return mSession->isCheckCertificateEnabled();
}

void IMAPAsyncConnection::setVoIPEnabled(bool enabled)
{
    mSession->setVoIPEnabled(enabled);
}

bool IMAPAsyncConnection::isVoIPEnabled()
{
    return mSession->isVoIPEnabled();
}

void IMAPAsyncConnection::setQResyncCompatible(bool compatible)
{
    mSession->setQResyncCompatible(compatible);
}

bool IMAPAsyncConnection::isQResyncCompatible()
{
    return mSession->isQResyncCompatible();
}

void IMAPAsyncConnection::setDefaultNamespace(IMAPNamespace * ns)
{
    mSession->setDefaultNamespace(ns);
    MC_SAFE_REPLACE_RETAIN(IMAPNamespace, mDefaultNamespace, ns);
}

IMAPNamespace * IMAPAsyncConnection::defaultNamespace()
{
    return mDefaultNamespace;
}

void IMAPAsyncConnection::setClientIdentity(IMAPIdentity * identity)
{
    MC_SAFE_REPLACE_COPY(IMAPIdentity, mClientIdentity, identity);
    mSession->clientIdentity()->removeAllInfos();
    if (identity != NULL) {
        mc_foreacharray(String, key, identity->allInfoKeys()) {
            mSession->clientIdentity()->setInfoForKey(key, identity->infoForKey(key));
        }
    }
}

IMAPIdentity * IMAPAsyncConnection::clientIdentity()
{
    return mClientIdentity;
}

IMAPOperation * IMAPAsyncConnection::disconnectOperation()
{
    IMAPDisconnectOperation * op = new IMAPDisconnectOperation();
    op->setSession(this);
    op->autorelease();
    return op;
}

IMAPSession * IMAPAsyncConnection::session()
{
    return mSession;
}

unsigned int IMAPAsyncConnection::operationsCount()
{
    return mQueue->count();
}

void IMAPAsyncConnection::cancelAllOperations()
{
    mQueue->cancelAllOperations();
}

void IMAPAsyncConnection::setReserved(bool reserved)
{
    mReserved = reserved;
}

bool IMAPAsyncConnection::isReserved()
{
    return mReserved;
}

void IMAPAsyncConnection::setAutomaticDisconnectDelay(time_t delay)
{
    mAutomaticDisconnectDelay = delay;
}

time_t IMAPAsyncConnection::automaticDisconnectDelay()
{
    return mAutomaticDisconnectDelay;
}

bool IMAPAsyncConnection::interruptCurrentCommand(IMAPOperation * operation)
{
    // Only for the operation the queue is executing right now - its command is the one holding this
    // connection. A queued operation holds nothing yet, and one that has already finished no longer
    // owns the stream, so cancelling on its behalf would cut somebody else's command. The queue
    // settles that question and interrupts under its own lock.
    //
    // Deliberately not scheduled through mQueue as an operation: the point is to unblock the
    // operation the queue is running, and a queued request would wait behind that very operation.
    return mQueue->interruptRunningOperation(operation);
}

void IMAPAsyncConnection::runOperation(IMAPOperation * operation)
{
    if (mScheduledAutomaticDisconnect) {
#if MC_HAS_GCD
        cancelDelayedPerformMethodOnDispatchQueue((Object::Method) &IMAPAsyncConnection::tryAutomaticDisconnectAfterDelay, NULL, dispatchQueue());
#else
        cancelDelayedPerformMethod((Object::Method) &IMAPAsyncConnection::tryAutomaticDisconnectAfterDelay, NULL);
#endif
        mOwner->release();
        mScheduledAutomaticDisconnect = false;
    }
    mQueue->addOperation(operation);
}

void IMAPAsyncConnection::tryAutomaticDisconnect()
{
    // It's safe since no thread is running when this function is called.
    if (mSession->isDisconnected()) {
        return;
    }

    bool scheduledAutomaticDisconnect = mScheduledAutomaticDisconnect;
    if (scheduledAutomaticDisconnect) {
#if MC_HAS_GCD
        cancelDelayedPerformMethodOnDispatchQueue((Object::Method) &IMAPAsyncConnection::tryAutomaticDisconnectAfterDelay, NULL, dispatchQueue());
#else
        cancelDelayedPerformMethod((Object::Method) &IMAPAsyncConnection::tryAutomaticDisconnectAfterDelay, NULL);
#endif
    }

    mOwner->retain();
    mScheduledAutomaticDisconnect = true;
#if MC_HAS_GCD
    performMethodOnDispatchQueueAfterDelay((Object::Method) &IMAPAsyncConnection::tryAutomaticDisconnectAfterDelay, NULL, dispatchQueue(), (double) mAutomaticDisconnectDelay);
#else
    performMethodAfterDelay((Object::Method) &IMAPAsyncConnection::tryAutomaticDisconnectAfterDelay, NULL, (double) mAutomaticDisconnectDelay);
#endif

    if (scheduledAutomaticDisconnect) {
        mOwner->release();
    }
}

void IMAPAsyncConnection::tryAutomaticDisconnectAfterDelay(void * context)
{
    mScheduledAutomaticDisconnect = false;

    if (mReserved) {
        // A lease holder is between commands. Leave its connection alone and check again after
        // the next delay: the timer keeps deferring until the connection is released.
        tryAutomaticDisconnect();
        mOwner->release();
        return;
    }

    IMAPOperation * op = disconnectOperation();
    op->start();

    mOwner->release();
}

void IMAPAsyncConnection::queueStartRunning()
{
    this->retain();
    mOwner->retain();
}

void IMAPAsyncConnection::queueStoppedRunning()
{
    mOwner->release();
    this->release();
}

void IMAPAsyncConnection::setLastFolder(String * folder)
{
    MC_SAFE_REPLACE_COPY(String, mLastFolder, folder);
}

String * IMAPAsyncConnection::lastFolder()
{
    return mLastFolder;
}

void IMAPAsyncConnection::setOwner(IMAPAsyncSession * owner)
{
    mOwner = owner;
}

IMAPAsyncSession * IMAPAsyncConnection::owner()
{
    return mOwner;
}

void IMAPAsyncConnection::setConnectionLogger(ConnectionLogger * logger)
{
    MCB_LOCK(&mConnectionLoggerLock);
    mConnectionLogger = logger;
    MCB_UNLOCK(&mConnectionLoggerLock);
    if (logger != NULL) {
        mSession->setConnectionLogger(mInternalLogger);
    }
    else {
        mSession->setConnectionLogger(NULL);
    }
}

ConnectionLogger * IMAPAsyncConnection::connectionLogger()
{
    ConnectionLogger * result;

    MCB_LOCK(&mConnectionLoggerLock);
    result = mConnectionLogger;
    MCB_UNLOCK(&mConnectionLoggerLock);

    return result;
}

void IMAPAsyncConnection::logConnection(ConnectionLogType logType, Data * buffer)
{
    MCB_LOCK(&mConnectionLoggerLock);
    if (mConnectionLogger != NULL) {
        mConnectionLogger->log(this, logType, buffer);
    }
    MCB_UNLOCK(&mConnectionLoggerLock);
}

void IMAPAsyncConnection::setAutomaticConfigurationEnabled(bool enabled)
{
    mAutomaticConfigurationEnabled = enabled;
    mSession->setAutomaticConfigurationEnabled(enabled);
}

bool IMAPAsyncConnection::isAutomaticConfigurationEnabled()
{
    return mAutomaticConfigurationEnabled;
}

bool IMAPAsyncConnection::isQueueRunning()
{
    return mQueueRunning;
}

void IMAPAsyncConnection::setQueueRunning(bool running)
{
    mQueueRunning = running;
}

#if MC_HAS_GCD
void IMAPAsyncConnection::setDispatchQueue(dispatch_queue_t dispatchQueue)
{
    mQueue->setDispatchQueue(dispatchQueue);
}

dispatch_queue_t IMAPAsyncConnection::dispatchQueue()
{
    return mQueue->dispatchQueue();
}
#endif
