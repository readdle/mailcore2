#ifndef MAILCORE_CIMAP_SESSION_H
#define MAILCORE_CIMAP_SESSION_H

#include <stdint.h>
#include <time.h>
#include <stdbool.h>

#include <dispatch/dispatch.h>

#include "CBase.h"
#include "CIndexSet.h"
#include "CArray.h"
#include "MailCoreString.h"
#include "CIMAPNamespace.h"
#include "CIMAPBaseOperation.h"
#include "CIMAPAppendMessageOperation.h"
#include "CIMAPFetchContentOperation.h"
#include "CIMAPFetchMessagesOperation.h"
#include "CIMAPSearchOperation.h"
#include "CIMAPSearchExpression.h"
#include "CIMAPCopyMessagesOperation.h"
#include "CIMAPFolderInfoOperation.h"
#include "CIMAPFolderStatusOperation.h"
#include "CMessageConstants.h"
#include "CIMAPAsyncConnection.h"
#include "CIMAPIdleOperation.h"
#include "CIMAPFetchFoldersOperation.h"
#include "CIMAPCapabilityOperation.h"
#include "CIMAPCheckAccountOperation.h"
#include "CIMAPCustomCommandOperation.h"
#include "CIMAPFetchContentToFileOperation.h"
#include "CIMAPFetchNamespaceOperation.h"
#include "CIMAPMoveMessagesOperation.h"
#include "CIMAPFetchParsedContentOperation.h"
#include "CIMAPMessageRenderingOperation.h"
#include "CIMAPQuotaOperation.h"
#include "CIMAPMessage.h"
#include "CIMAPIdentity.h"
#include "CIMAPIdentityOperation.h"

#ifdef __cplusplus

namespace mailcore {
    class IMAPAsyncSession;
}

class CIMAPCallbackBridge;

extern "C" {
#endif
    
    typedef void (*MCOConnectionLoggerReleaseBlock)(const void* logger);
    
    typedef struct CIMAPAsyncSession {
#ifdef __cplusplus
        mailcore::IMAPAsyncSession*     instance;
        CIMAPCallbackBridge*            _callback;
#else
        void*                           instance;
        void*                           _callback;
#endif
    } CIMAPAsyncSession;
    
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, MailCoreString, hostname, setHostname)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, unsigned int, port, setPort)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, MailCoreString, username, setUsername)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, MailCoreString, password, setPassword)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, ConnectionType, connectionType, setConnectionType)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, time_t, timeout, setTimeout)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, bool, isCheckCertificateEnabled, setCheckCertificateEnabled)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, MailCoreString, OAuth2Token, setOAuth2Token)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, CAuthType, authType, setAuthType)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, unsigned int, maximumConnections, setMaximumConnections)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, time_t, automaticDisconnectDelay, setAutomaticDisconnectDelay)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, bool, allowsFolderConcurrentAccessEnabled, setAllowsFolderConcurrentAccessEnabled)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, CIMAPNamespace, defaultNamespace, setDefaultNamespace)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, CIMAPIdentity, clientIdentity, setClientIdentity)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, CIMAPIdentity, serverIdentity, setServerIdentity)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, bool, isQResyncCompatible, setQResyncCompatible)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CIMAPAsyncSession, bool, isVoIPEnabled, setVoIPEnabled)
    
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, dispatch_queue_t, dispatchQueue)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, void, setDispatchQueue, dispatch_queue_t)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, void, setConnectionLogger, void*)
    
    C_SYNTHESIZE_READONLY_PROPERTY_DEFINITION(CIMAPAsyncSession, bool, isIdleEnabled)
    C_SYNTHESIZE_READONLY_PROPERTY_DEFINITION(CIMAPAsyncSession, bool, isOperationQueueRunning)
    
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, void, cancelAllOperations)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPAsyncConnection, acquireConnection, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, void, releaseConnection, CIMAPAsyncConnection, bool)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, connectOperation)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, disconnectOperation)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, noopOperation)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, expungeOperation, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, createFolderOperation, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, renameFolderOperation, MailCoreString, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, deleteFolderOperation, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, storeFlagsByUIDOperation, MailCoreString, CIndexSet, IMAPStoreFlagsRequestKind, CMessageFlag, CArray)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, storeFlagsByNumberOperation, MailCoreString, CIndexSet, IMAPStoreFlagsRequestKind, CMessageFlag, CArray)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, storeLabelsByUIDOperation, MailCoreString, CIndexSet, IMAPStoreFlagsRequestKind, CArray)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, storeLabelsByNumberOperation, MailCoreString, CIndexSet, IMAPStoreFlagsRequestKind, CArray)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, subscribeFolderOperation, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPBaseOperation, unsubscribeFolderOperation, MailCoreString)


    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchFoldersOperation, fetchSubscribedFoldersOperation)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchContentToFileOperation, fetchMessageAttachmentToFileOperation, MailCoreString, uint32_t, MailCoreString, Encoding, MailCoreString, bool)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchNamespaceOperation, fetchNamespaceOperation)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPCustomCommandOperation, customCommandOperation, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPCheckAccountOperation, checkAccountOperation)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPCapabilityOperation, capabilityOperation)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchFoldersOperation, fetchAllFoldersOperation)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPAppendMessageOperation, appendMessageOperation, MailCoreString, MailCoreString, CMessageFlag, CArray)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPAppendMessageOperation, appendMessageOperationWithData, MailCoreString, CData, CMessageFlag, CArray)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchMessagesOperation, fetchMessagesByNumberOperation, MailCoreString, CIMAPMessagesRequestKind, CIndexSet)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchMessagesOperation, fetchMessagesByUIDOperation, MailCoreString, CIMAPMessagesRequestKind, CIndexSet)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchMessagesOperation, syncMessagesByUIDOperation, MailCoreString, CIMAPMessagesRequestKind, CIndexSet, uint64_t)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchContentOperation, fetchMessageByUIDOperation, MailCoreString, uint32_t, bool)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchContentOperation, fetchMessageByNumberOperation, MailCoreString, uint32_t, bool)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchContentOperation, fetchMessageAttachmentByUIDOperation, MailCoreString, uint32_t, MailCoreString, Encoding, bool)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchContentOperation, fetchMessageAttachmentByNumberOperation, MailCoreString, uint32_t, MailCoreString, Encoding, bool)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPSearchOperation, searchOperationWithExpression, MailCoreString, CIMAPSearchExpression)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPSearchOperation, searchOperation, MailCoreString, IMAPSearchKind, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPCopyMessagesOperation, copyMessagesOperation, MailCoreString, CIndexSet, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFolderInfoOperation, folderInfoOperation, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFolderStatusOperation, folderStatusOperation, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPIdleOperation, idleOperation, MailCoreString, uint32_t)
    
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPMoveMessagesOperation, moveMessagesOperation, MailCoreString, CIndexSet, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchParsedContentOperation, fetchParsedMessageOperationByUIDOperation, MailCoreString, uint32_t, bool)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPFetchParsedContentOperation, fetchParsedMessageOperationByNumberOperation, MailCoreString, uint32_t, bool)
    
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPMessageRenderingOperation, htmlRenderingOperation, CIMAPMessage, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPMessageRenderingOperation, htmlBodyRenderingOperation, CIMAPMessage, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPMessageRenderingOperation, plainTextRenderingOperation, CIMAPMessage, MailCoreString)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPMessageRenderingOperation, plainTextBodyRenderingOperation, CIMAPMessage, MailCoreString, bool)

    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPQuotaOperation, quotaOperation)
    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncSession, CIMAPIdentityOperation, identityOperationWithClientIdentity, CIMAPIdentity)


    CMAILCORE_EXPORT CIMAPAsyncSession  CIMAPAsyncSession_new(CConnectionLogger logger, CConnectionLoggerRelease releaseLoggerBlock);

    CMAILCORE_EXPORT void               CIMAPAsyncSession_release(CIMAPAsyncSession self)
                                        CF_SWIFT_NAME(CIMAPAsyncSession.release(self:));

#ifdef __cplusplus
}
#endif

#endif
