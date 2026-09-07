#include "COperation.h"
#include "CIMAPBaseOperation.h"
#include "CBase+Private.h"
#include <MailCore/MCAsync.h>

#define nativeType mailcore::IMAPOperation
#define structName CIMAPBaseOperation

C_SYNTHESIZE_COBJECT_CAST()

class CIMAPBaseOperationIMAPCallback : public mailcore::IMAPOperationCallback {
public:
    CIMAPBaseOperationIMAPCallback(const void* userInfo, CIMAPProgressBlock itemProgressBlock, CIMAPProgressBlock bodyProgressBlock)
    {
        mUserInfo = userInfo;
        mItemProgressBlock = itemProgressBlock;
        mBodyProgressBlock = bodyProgressBlock;
    }
    
    virtual ~CIMAPBaseOperationIMAPCallback()
    {
        mUserInfo = NULL;
        mItemProgressBlock = NULL;
        mBodyProgressBlock = NULL;
    }
    
    virtual void bodyProgress(mailcore::IMAPOperation * session, unsigned int current, unsigned int maximum) {
        mBodyProgressBlock(mUserInfo, current, maximum);
    }
    
    virtual void itemProgress(mailcore::IMAPOperation * session, unsigned int current, unsigned int maximum) {
        mItemProgressBlock(mUserInfo, current, maximum);
    }
    
private:
    const void* mUserInfo;
    CIMAPProgressBlock mItemProgressBlock;
    CIMAPProgressBlock mBodyProgressBlock;
};

CIMAPBaseOperation CIMAPBaseOperation_new(mailcore::IMAPOperation* operation) {
    CIMAPBaseOperation self;
    self.cOperation = COperation_new(operation);
    self.instance = operation;
    return self;
}

ErrorCode CIMAPBaseOperation_error(struct CIMAPBaseOperation self) {
    return static_cast<ErrorCode>(self.instance->error());
}

C_SYNTHESIZE_FUNC_WITH_SCALAR(bool, interruptCurrentCommand)
C_SYNTHESIZE_FUNC_WITH_VOID(setSession, CIMAPAsyncConnection)

CIMAPBaseOperation CIMAPBaseOperation_setProgressBlocks(struct CIMAPBaseOperation self, CIMAPProgressBlock itemProgressBlock, CIMAPProgressBlock bodyProgressBlock, const void* userInfo) {
    CIMAPBaseOperationIMAPCallback *callback = new CIMAPBaseOperationIMAPCallback(userInfo, itemProgressBlock, bodyProgressBlock);
    self._callback = callback;
    self.instance->setImapCallback(callback);
    return self;
}

void CIMAPBaseOperation_retain(CIMAPBaseOperation operation) {
    operation.instance->retain();
}

void CIMAPBaseOperation_release(CIMAPBaseOperation self) {
    self.instance->setImapCallback(NULL);
    self.instance->release();
    if (self._callback != NULL) {
        delete self._callback;
    }
}

int CIMAPBaseOperation_retainCount(CIMAPBaseOperation self) {
    return self.instance->retainCount();
}
