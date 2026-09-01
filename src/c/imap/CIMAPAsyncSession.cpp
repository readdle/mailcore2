#include <MailCore/MCAsync.h>
#include <MailCore/MCOperationQueueCallback.h>

#include "CIMAPAsyncSession.h"
#include "CIMAPAsyncConnection.h"
#include "CIMAPAppendMessageOperation.h"
#include "CIMAPCopyMessagesOperation.h"
#include "CIMAPFetchContentOperation.h"
#include "CIMAPFolderInfoOperation.h"
#include "CIMAPFolderStatusOperation.h"
#include "CIMAPSearchOperation.h"

#include "CBase+Private.h"

#define nativeType mailcore::IMAPAsyncSession
#define structName CIMAPAsyncSession

C_SYNTHESIZE_STRING(setHostname, hostname)
C_SYNTHESIZE_SCALAR(unsigned int, unsigned int, setPort, port)
C_SYNTHESIZE_STRING(setUsername, username)
C_SYNTHESIZE_STRING(setPassword, password)
C_SYNTHESIZE_ENUM(ConnectionType, mailcore::ConnectionType, setConnectionType, connectionType)
C_SYNTHESIZE_SCALAR(time_t, time_t, setTimeout, timeout)
C_SYNTHESIZE_SCALAR(time_t, time_t, setAutomaticDisconnectDelay, automaticDisconnectDelay)
C_SYNTHESIZE_BOOL(setCheckCertificateEnabled, isCheckCertificateEnabled)
C_SYNTHESIZE_STRING(setOAuth2Token, OAuth2Token)
C_SYNTHESIZE_ENUM(CAuthType, mailcore::AuthType, setAuthType, authType)
C_SYNTHESIZE_SCALAR(unsigned int, unsigned int, setMaximumConnections, maximumConnections)
C_SYNTHESIZE_BOOL(setAllowsFolderConcurrentAccessEnabled, allowsFolderConcurrentAccessEnabled)
C_SYNTHESIZE_MAILCORE_OBJ(CIMAPNamespace, CIMAPNamespace_new, setDefaultNamespace, defaultNamespace)
C_SYNTHESIZE_MAILCORE_OBJ(CIMAPIdentity, CIMAPIdentity_new, setClientIdentity, clientIdentity)
C_SYNTHESIZE_SCALAR(dispatch_queue_t, dispatch_queue_t, setDispatchQueue, dispatchQueue)
C_SYNTHESIZE_BOOL(setQResyncCompatible, isQResyncCompatible)
C_SYNTHESIZE_BOOL(setVoIPEnabled, isVoIPEnabled)

class CIMAPCallbackBridge : public mailcore::Object, public mailcore::ConnectionLogger, public mailcore::OperationQueueCallback {
public:
    CIMAPCallbackBridge(CConnectionLogger logger, CConnectionLoggerRelease releaseLoggerBlock)
    {
        this->mLogger = logger;
        this->mReleaseBlock = releaseLoggerBlock;
    }
    
    virtual void log(void * sender, mailcore::ConnectionLogType logType, mailcore::Data *data)
    {
        if (mcoLogger != NULL) {
            mLogger(sender, static_cast<ConnectionLogType>((int)logType), CData_new(data), mcoLogger);
        }
    }
    
    virtual void queueStartRunning()
    {
        if (mQueueRunningChangeBlock != NULL) {
            mQueueRunningChangeBlock();
        }
    }
    
    virtual void queueStoppedRunning()
    {
        if (mQueueRunningChangeBlock != NULL) {
            mQueueRunningChangeBlock();
        }
    }
    
    void releaseSwiftLogger() {
        this->mReleaseBlock(this->mcoLogger);
        this->mcoLogger = NULL;
    }
    
    CConnectionLogger mLogger = NULL;
    CConnectionLoggerRelease mReleaseBlock = NULL;
    void* mcoLogger = NULL;
    OperationQueueRunningChangeBlock mQueueRunningChangeBlock = NULL;
};

void CIMAPAsyncSession_setConnectionLogger(struct CIMAPAsyncSession self, void* mcoLogger) {
    self._callback->releaseSwiftLogger();
    self._callback->mcoLogger = mcoLogger;
    if (mcoLogger != NULL) {
        self.instance->setConnectionLogger(self._callback);
    }
    else {
        self.instance->setConnectionLogger(NULL);
    }
}

C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPIdentity, serverIdentity)
C_SYNTHESIZE_FUNC_WITH_SCALAR(bool, isIdleEnabled)
C_SYNTHESIZE_FUNC_WITH_SCALAR(bool, isOperationQueueRunning)
C_SYNTHESIZE_FUNC_WITH_VOID(cancelAllOperations)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPAsyncConnection, acquireConnection, MailCoreString)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPBaseOperation, subscribeFolderOperation, MailCoreString)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPBaseOperation, unsubscribeFolderOperation, MailCoreString)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPBaseOperation, renameFolderOperation, MailCoreString, MailCoreString)

C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPFetchFoldersOperation, fetchSubscribedFoldersOperation)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPFetchNamespaceOperation, fetchNamespaceOperation)

CIMAPFetchContentToFileOperation CIMAPAsyncSession_fetchMessageAttachmentToFileOperation(struct CIMAPAsyncSession self, MailCoreString folder, uint32_t uid, MailCoreString partID, Encoding encoding, MailCoreString filename, bool urgent){
    return CIMAPFetchContentToFileOperation_new(self.instance->fetchMessageAttachmentToFileByUIDOperation(folder.instance, uid, partID.instance, ((mailcore::Encoding) encoding), filename.instance, urgent));
}

CIMAPCustomCommandOperation CIMAPAsyncSession_customCommandOperation(struct CIMAPAsyncSession self, MailCoreString command) {
    return CIMAPCustomCommandOperation_new(self.instance->customCommand(command.instance, false));
}

void CIMAPAsyncSession_releaseConnection(struct CIMAPAsyncSession self, CIMAPAsyncConnection connection, bool disconnect) {
    self.instance->releaseConnection(connection.instance, disconnect);
}

C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPBaseOperation, connectOperation)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPBaseOperation, disconnectOperation)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPBaseOperation, noopOperation)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPCheckAccountOperation, checkAccountOperation)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPCapabilityOperation, capabilityOperation)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPFetchFoldersOperation, fetchAllFoldersOperation)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPBaseOperation, expungeOperation, MailCoreString)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPBaseOperation, createFolderOperation, MailCoreString)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPBaseOperation, deleteFolderOperation, MailCoreString)

CIMAPBaseOperation CIMAPAsyncSession_storeFlagsByUIDOperation(CIMAPAsyncSession self, MailCoreString folder, CIndexSet set, IMAPStoreFlagsRequestKind kind, CMessageFlag flags, CArray customFlags){
    mailcore::IMAPOperation *imapOperation = self.instance->storeFlagsByUIDOperation(folder.instance, 
        set.instance, static_cast<mailcore::IMAPStoreFlagsRequestKind>(kind), static_cast<mailcore::MessageFlag>(flags), customFlags.instance);
    return CIMAPBaseOperation_new(imapOperation);
}

CIMAPBaseOperation CIMAPAsyncSession_storeFlagsByNumberOperation(struct CIMAPAsyncSession self, MailCoreString folder, CIndexSet numbers, IMAPStoreFlagsRequestKind kind, CMessageFlag flags, CArray customFlags) {
    mailcore::IMAPOperation *imapOperation = self.instance->storeFlagsByNumberOperation(folder.instance,
        numbers.instance, static_cast<mailcore::IMAPStoreFlagsRequestKind>(kind), static_cast<mailcore::MessageFlag>(flags), customFlags.instance);
    return CIMAPBaseOperation_new(imapOperation);
}

CIMAPBaseOperation CIMAPAsyncSession_storeLabelsByUIDOperation(struct CIMAPAsyncSession self, MailCoreString folder, CIndexSet uids, IMAPStoreFlagsRequestKind kind, CArray labels) {
    mailcore::IMAPOperation *imapOperation = self.instance->storeLabelsByUIDOperation(folder.instance,
        uids.instance, static_cast<mailcore::IMAPStoreFlagsRequestKind>(kind), labels.instance);
    return CIMAPBaseOperation_new(imapOperation);
}

CIMAPBaseOperation CIMAPAsyncSession_storeLabelsByNumberOperation(struct CIMAPAsyncSession self, MailCoreString folder, CIndexSet numbers, IMAPStoreFlagsRequestKind kind, CArray labels) {
    mailcore::IMAPOperation *imapOperation = self.instance->storeLabelsByNumberOperation(folder.instance,
        numbers.instance, static_cast<mailcore::IMAPStoreFlagsRequestKind>(kind), labels.instance);
    return CIMAPBaseOperation_new(imapOperation);
}

CIMAPAppendMessageOperation CIMAPAsyncSession_appendMessageOperation(CIMAPAsyncSession self, MailCoreString folder, MailCoreString messagePath, CMessageFlag flags, CArray array){
    mailcore::IMAPAppendMessageOperation *imapOperation = self.instance->appendMessageOperation(folder.instance, messagePath.instance, static_cast<mailcore::MessageFlag>(flags), array.instance);
    return CIMAPAppendMessageOperation_new(imapOperation);
}

CIMAPAppendMessageOperation CIMAPAsyncSession_appendMessageOperationWithData(CIMAPAsyncSession self, MailCoreString folder, CData messageData, CMessageFlag flags, CArray array){
    mailcore::IMAPAppendMessageOperation *imapOperation = self.instance->appendMessageOperation(folder.instance,
                                                                                                messageData.instance,
                                                                                                static_cast<mailcore::MessageFlag>(flags), array.instance);
    return CIMAPAppendMessageOperation_new(imapOperation);
}

CIMAPFetchMessagesOperation CIMAPAsyncSession_fetchMessagesByNumberOperation(CIMAPAsyncSession self, MailCoreString folder, CIMAPMessagesRequestKind kind, CIndexSet numbers){
    mailcore::IMAPFetchMessagesOperation *imapOperation = self.instance->fetchMessagesByNumberOperation(folder.instance,
        static_cast<mailcore::IMAPMessagesRequestKind>(kind), numbers.instance);
    return CIMAPFetchMessagesOperation_new(imapOperation);
}

CIMAPFetchMessagesOperation CIMAPAsyncSession_fetchMessagesByUIDOperation(CIMAPAsyncSession self, MailCoreString folder, CIMAPMessagesRequestKind kind, CIndexSet uids){
    mailcore::IMAPFetchMessagesOperation *imapOperation = self.instance->fetchMessagesByUIDOperation(folder.instance,
        static_cast<mailcore::IMAPMessagesRequestKind>(kind), uids.instance);
    return CIMAPFetchMessagesOperation_new(imapOperation);
}

CIMAPFetchMessagesOperation CIMAPAsyncSession_syncMessagesByUIDOperation(CIMAPAsyncSession self, MailCoreString folder, CIMAPMessagesRequestKind kind, CIndexSet uids, uint64_t modSeq){
    mailcore::IMAPFetchMessagesOperation *imapOperation = self.instance->syncMessagesByUIDOperation(folder.instance,
        static_cast<mailcore::IMAPMessagesRequestKind>(kind), uids.instance, modSeq);
    return CIMAPFetchMessagesOperation_new(imapOperation);
}

CIMAPFetchContentOperation CIMAPAsyncSession_fetchMessageByUIDOperation(CIMAPAsyncSession self, MailCoreString folder, uint32_t uid, bool urgent){
    mailcore::IMAPFetchContentOperation *imapOperation = self.instance->fetchMessageByUIDOperation(folder.instance, uid, urgent);
    return CIMAPFetchContentOperation_new(imapOperation);
}

CIMAPFetchContentOperation CIMAPAsyncSession_fetchMessageByNumberOperation(struct CIMAPAsyncSession self, MailCoreString folder, uint32_t uid, bool urgent) {
    mailcore::IMAPFetchContentOperation *imapOperation = self.instance->fetchMessageByNumberOperation(folder.instance, uid, urgent);
    return CIMAPFetchContentOperation_new(imapOperation);
}

CIMAPFetchContentOperation CIMAPAsyncSession_fetchMessageAttachmentByUIDOperation(CIMAPAsyncSession self, MailCoreString folder, uint32_t uid, MailCoreString partID, Encoding encoding, bool urgent){
    mailcore::IMAPFetchContentOperation *imapOperation = self.instance->fetchMessageAttachmentByUIDOperation(folder.instance,
        uid, partID.instance, static_cast<mailcore::Encoding>(encoding), urgent);
    return CIMAPFetchContentOperation_new(imapOperation);
}

CIMAPFetchContentOperation CIMAPAsyncSession_fetchMessageAttachmentByNumberOperation(struct CIMAPAsyncSession self, MailCoreString folder, uint32_t number, MailCoreString partID, Encoding encoding, bool urgent) {
    mailcore::IMAPFetchContentOperation *imapOperation = self.instance->fetchMessageAttachmentByNumberOperation(folder.instance,
        number, partID.instance, static_cast<mailcore::Encoding>(encoding), urgent);
    return CIMAPFetchContentOperation_new(imapOperation);
}

CIMAPSearchOperation CIMAPAsyncSession_searchOperationWithExpression(CIMAPAsyncSession self, MailCoreString folder, CIMAPSearchExpression expr){
    mailcore::IMAPSearchOperation *imapOperation = self.instance->searchOperation(folder.instance, expr.instance);
    return CIMAPSearchOperation_new(imapOperation);
}

CIMAPSearchOperation CIMAPAsyncSession_searchOperation(CIMAPAsyncSession self, MailCoreString folder, IMAPSearchKind kind, MailCoreString str){
    mailcore::IMAPSearchOperation *imapOperation = self.instance->searchOperation(folder.instance, 
        static_cast<mailcore::IMAPSearchKind>(kind), str.instance);
    return CIMAPSearchOperation_new(imapOperation);
}

CIMAPCopyMessagesOperation CIMAPAsyncSession_copyMessagesOperation(CIMAPAsyncSession self, MailCoreString folder, CIndexSet uids,MailCoreString destFolder){
    mailcore::IMAPCopyMessagesOperation *imapOperation = self.instance->copyMessagesOperation(folder.instance, 
        uids.instance, destFolder.instance);
    return CIMAPCopyMessagesOperation_new(imapOperation);
}

C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPFolderInfoOperation, folderInfoOperation, MailCoreString)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPFolderStatusOperation, folderStatusOperation, MailCoreString)

CIMAPIdleOperation CIMAPAsyncSession_idleOperation(struct CIMAPAsyncSession self, MailCoreString folder, uint32_t lastKnownUID){
    return CIMAPIdleOperation_new(self.instance->idleOperation(folder.instance, lastKnownUID));
}

C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPMoveMessagesOperation, moveMessagesOperation, MailCoreString, CIndexSet, MailCoreString)

CIMAPFetchParsedContentOperation CIMAPAsyncSession_fetchParsedMessageOperationByUIDOperation(struct CIMAPAsyncSession self, MailCoreString folder, uint32_t uid, bool urgent) {
    return CIMAPFetchParsedContentOperation_new(self.instance->fetchParsedMessageByUIDOperation(folder.instance, uid));
}

CIMAPFetchParsedContentOperation CIMAPAsyncSession_fetchParsedMessageOperationByNumberOperation(struct CIMAPAsyncSession self, MailCoreString folder, uint32_t number, bool urgent) {
    return CIMAPFetchParsedContentOperation_new(self.instance->fetchParsedMessageByNumberOperation(folder.instance, number));
}

C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPMessageRenderingOperation, htmlRenderingOperation, CIMAPMessage, MailCoreString)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPIdentityOperation, identityOperation, CIMAPIdentity)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPMessageRenderingOperation, htmlBodyRenderingOperation, CIMAPMessage, MailCoreString)
C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPMessageRenderingOperation, plainTextRenderingOperation, CIMAPMessage, MailCoreString)

CIMAPMessageRenderingOperation CIMAPAsyncSession_plainTextBodyRenderingOperation(struct CIMAPAsyncSession self, CIMAPMessage message, MailCoreString folder, bool stripWhitespace) {
    return CIMAPMessageRenderingOperation_new(self.instance->plainTextBodyRenderingOperation(message.instance, folder.instance, stripWhitespace));
}

C_SYNTHESIZE_FUNC_WITH_OBJ(CIMAPQuotaOperation, quotaOperation)

CIMAPAsyncSession CIMAPAsyncSession_new(CConnectionLogger logger, CConnectionLoggerRelease releaseLoggerBlock){
    CIMAPAsyncSession session;
    session.instance = new mailcore::IMAPAsyncSession();
    session._callback = new CIMAPCallbackBridge(logger, releaseLoggerBlock);
    session.instance->setOperationQueueCallback(session._callback);
    return session;
}

void CIMAPAsyncSession_release(CIMAPAsyncSession session){
    session.instance->setConnectionLogger(NULL);
    session.instance->setOperationQueueCallback(NULL);
    session._callback->releaseSwiftLogger();
    C_SAFE_RELEASE(session._callback);
    session.instance->release();
}


