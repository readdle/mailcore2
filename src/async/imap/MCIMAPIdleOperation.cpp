//
//  IMAPIdleOperation.cc
//  mailcore2
//
//  Created by DINH Viêt Hoà on 1/12/13.
//  Copyright (c) 2013 MailCore. All rights reserved.
//

#include "MCIMAPIdleOperation.h"

#include "MCIMAPSession.h"
#include "MCIMAPAsyncConnection.h"

using namespace mailcore;

IMAPIdleOperation::IMAPIdleOperation()
{
    mLastKnownUid = 0;
    mSetupSuccess = false;
    mInterrupted = false;
    MCB_LOCK_INIT(&mLock);
}

IMAPIdleOperation::~IMAPIdleOperation()
{
    MCB_LOCK_DESTROY(&mLock);
}

void IMAPIdleOperation::setLastKnownUID(uint32_t uid)
{
    mLastKnownUid = uid;
}

uint32_t IMAPIdleOperation::lastKnownUID()
{
    return mLastKnownUid;
}

void IMAPIdleOperation::prepare(void * data)
{
    if (isInterrupted()) {
        setSetupSuccess(false);
        return;
    }

    setSetupSuccess(session()->session()->setupIdle());
}

void IMAPIdleOperation::unprepare(void * data)
{
    if (setupSuccess()) {
        session()->session()->unsetupIdle();
    }
}

bool IMAPIdleOperation::isInterrupted() {
    MCB_LOCK(&mLock);
    bool interrupted = mInterrupted;
    MCB_UNLOCK(&mLock);
    
    return interrupted;
}

void IMAPIdleOperation::setSetupSuccess(bool setupSuccess)
{
    MCB_LOCK(&mLock);
    mSetupSuccess = setupSuccess;
    MCB_UNLOCK(&mLock);
}

bool IMAPIdleOperation::setupSuccess()
{
    MCB_LOCK(&mLock);
    bool setupSuccess = mSetupSuccess;
    MCB_UNLOCK(&mLock);

    return setupSuccess;
}

void IMAPIdleOperation::main()
{
    if (isInterrupted()) {
        return;
    }
    
    ErrorCode error = ErrorNone;
    session()->session()->selectIfNeeded(folder(), &error);
    if (error != ErrorNone) {
        setError(error);
        return;
    }
    
    performMethodOnCallbackThread((Object::Method) &IMAPIdleOperation::prepare, NULL, true);
    
    if (!setupSuccess()) {
        return;
    }
    
    session()->session()->idle(folder(), mLastKnownUid, &error);
    setError(error);
    
    performMethodOnCallbackThread((Object::Method) &IMAPIdleOperation::unprepare, NULL, true);
}

void IMAPIdleOperation::cancel()
{
    IMAPOperation::cancel();
    interruptIdle();
}

void IMAPIdleOperation::interruptIdle()
{
    bool setupSuccess;

    MCB_LOCK(&mLock);
    mInterrupted = true;
    setupSuccess = mSetupSuccess;
    MCB_UNLOCK(&mLock);
    if (setupSuccess && session() != NULL) {
        session()->session()->interruptIdle();
    }
}
