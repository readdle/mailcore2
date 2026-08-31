//
//  MCIMAPAccount.h
//  mailcore2
//
//  Created by DINH Viêt Hoà on 1/17/13.
//  Copyright (c) 2013 MailCore. All rights reserved.
//

#ifndef MAILCORE_MCIMAPACCOUNT_H

#define MAILCORE_MCIMAPACCOUNT_H

#include <MailCore/MCBaseTypes.h>
#include <MailCore/MCMessageConstants.h>

#ifdef __cplusplus

namespace mailcore {
    
    class IMAPOperation;
    class IMAPFetchFoldersOperation;
    class IMAPAppendMessageOperation;
    class IMAPCopyMessagesOperation;
    class IMAPMoveMessagesOperation;
    class IMAPFetchMessagesOperation;
    class IMAPFetchContentOperation;
    class IMAPFetchContentToFileOperation;
    class IMAPFetchParsedContentOperation;
    class IMAPIdleOperation;
    class IMAPFolderInfoOperation;
    class IMAPFolderStatusOperation;
    class IMAPNamespace;
    class IMAPSearchOperation;
    class IMAPSearchExpression;
    class IMAPFetchNamespaceOperation;
    class IMAPIdentityOperation;
    class IMAPAsyncConnection;
    class IMAPCapabilityOperation;
    class IMAPQuotaOperation;
    class IMAPMessageRenderingOperation;
    class IMAPMessage;
    class IMAPSession;
    class IMAPIdentity;
    class OperationQueueCallback;
    class IMAPCustomCommandOperation;
    class IMAPCheckAccountOperation;
    
    class MAILCORE_EXPORT IMAPAsyncSession : public Object {
    public:
        IMAPAsyncSession();
        virtual ~IMAPAsyncSession();
        
        virtual void setHostname(String * hostname);
        virtual String * hostname();
        
        virtual void setPort(unsigned int port);
        virtual unsigned int port();
        
        virtual void setUsername(String * username);
        virtual String * username();
        
        virtual void setPassword(String * password);
        virtual String * password();
        
        // To authenticate using OAuth2, username and oauth2token should be set.
        // auth type to use is AuthTypeOAuth2.
        virtual void setOAuth2Token(String * token);
        virtual String * OAuth2Token();
        
        virtual void setAuthType(AuthType authType);
        virtual AuthType authType();
        
        virtual void setConnectionType(ConnectionType connectionType);
        virtual ConnectionType connectionType();
        
        virtual void setTimeout(time_t timeout);
        virtual time_t timeout();
        
        virtual void setCheckCertificateEnabled(bool enabled);
        virtual bool isCheckCertificateEnabled();
        
        virtual void setVoIPEnabled(bool enabled);
        virtual bool isVoIPEnabled();
        
        virtual void setQResyncCompatible(bool compatible);
        virtual bool isQResyncCompatible();

        virtual void setDefaultNamespace(IMAPNamespace * ns);
        virtual IMAPNamespace * defaultNamespace();
        
        virtual void setAllowsFolderConcurrentAccessEnabled(bool enabled);
        virtual bool allowsFolderConcurrentAccessEnabled();
        
        virtual void setMaximumConnections(unsigned int maxConnections);
        virtual unsigned int maximumConnections();

        // How long an idle connection stays open once its queue drains, in seconds.
        // Applied to connections created after the change.
        virtual void setAutomaticDisconnectDelay(time_t delay);
        virtual time_t automaticDisconnectDelay();

        /*! Reserves a connection for exclusive use: the regular per-operation selection stops
         seeing it, so only operations explicitly pointed at it (IMAPOperation::setSession) run
         there, and the idle auto-disconnect stands down until release. Exclusivity is
         forward-only: operations already queued on the connection still run ahead of the lease
         holder's (selection prefers an idle or new connection, so a backlog is only possible
         with the pool at its limit). Returns NULL when every connection is already reserved -
         the pool has nothing left to hand out exclusively. While the pool is at its limit and
         fully reserved, regular operations fall back to sharing the least busy reserved
         connection, so size maximumConnections against the number of simultaneous leases.
         Reservation state is as unsynchronized as the rest of the session selection: call
         acquireConnection/releaseConnection on the session's dispatch queue (where operations
         start), or serialize them with it externally. */
        virtual IMAPAsyncConnection * acquireConnection(String * folder);
        /*! Returns a reserved connection to the shared pool and re-arms its idle
         auto-disconnect. With disconnect, tears the socket down first (the connection object
         stays pooled and reconnects on next use) - for servers that pin a mailbox snapshot per
         connection, and mandatory after interruptCurrentCommand, since a cancelled stream does
         not recover. Idempotent: releasing a connection that is not reserved does nothing.
         Same threading contract as acquireConnection. */
        virtual void releaseConnection(IMAPAsyncConnection * connection, bool disconnect);
        
        virtual void setConnectionLogger(ConnectionLogger * logger);
        virtual ConnectionLogger * connectionLogger();
        
#if MC_HAS_GCD
        virtual void setDispatchQueue(dispatch_queue_t dispatchQueue);
        virtual dispatch_queue_t dispatchQueue();
#endif
        
        virtual void setOperationQueueCallback(OperationQueueCallback * callback);
        virtual OperationQueueCallback * operationQueueCallback();
        virtual bool isOperationQueueRunning();
        virtual void cancelAllOperations();
        
        virtual IMAPIdentity * serverIdentity();
        virtual IMAPIdentity * clientIdentity();
        virtual void setClientIdentity(IMAPIdentity * clientIdentity);

        virtual String * gmailUserDisplayName() DEPRECATED_ATTRIBUTE;

        virtual bool isIdleEnabled();
        
        virtual IMAPFolderInfoOperation * folderInfoOperation(String * folder);
        virtual IMAPFolderStatusOperation * folderStatusOperation(String * folder);
        
        virtual IMAPFetchFoldersOperation * fetchSubscribedFoldersOperation();
        virtual IMAPFetchFoldersOperation * fetchAllFoldersOperation();
        
        virtual IMAPOperation * renameFolderOperation(String * folder, String * otherName);
        virtual IMAPOperation * deleteFolderOperation(String * folder);
        virtual IMAPOperation * createFolderOperation(String * folder);
        
        virtual IMAPOperation * subscribeFolderOperation(String * folder);
        virtual IMAPOperation * unsubscribeFolderOperation(String * folder);
        
        virtual IMAPAppendMessageOperation * appendMessageOperation(String * folder, Data * messageData, MessageFlag flags, Array * customFlags = NULL);
        virtual IMAPAppendMessageOperation * appendMessageOperation(String * folder, String * messagePath, MessageFlag flags, Array * customFlags = NULL);

        virtual IMAPCopyMessagesOperation * copyMessagesOperation(String * folder, IndexSet * uids, String * destFolder);
        virtual IMAPMoveMessagesOperation * moveMessagesOperation(String * folder, IndexSet * uids, String * destFolder);
        
        virtual IMAPOperation * expungeOperation(String * folder);
        
        virtual IMAPFetchMessagesOperation * fetchMessagesByUIDOperation(String * folder, IMAPMessagesRequestKind requestKind,
                                                                         IndexSet * indexes);
        virtual IMAPFetchMessagesOperation * fetchMessagesByNumberOperation(String * folder, IMAPMessagesRequestKind requestKind,
                                                                            IndexSet * indexes);
        virtual IMAPFetchMessagesOperation * syncMessagesByUIDOperation(String * folder, IMAPMessagesRequestKind requestKind,
                                                                        IndexSet * indexes, uint64_t modSeq);
        
        virtual IMAPFetchContentOperation * fetchMessageByUIDOperation(String * folder, uint32_t uid, bool urgent = false);
        virtual IMAPFetchContentOperation * fetchMessageAttachmentByUIDOperation(String * folder, uint32_t uid, String * partID,
                                                                                 Encoding encoding, bool urgent = false);

        virtual IMAPFetchContentToFileOperation * fetchMessageAttachmentToFileByUIDOperation(
                                                                                 String * folder, uint32_t uid, String * partID,
                                                                                 Encoding encoding,
                                                                                 String * filename,
                                                                                 bool urgent = false);

        virtual IMAPFetchContentOperation * fetchMessageByNumberOperation(String * folder, uint32_t number, bool urgent = false);
        virtual IMAPCustomCommandOperation * customCommand(String *command, bool urgent);
        virtual IMAPFetchContentOperation * fetchMessageAttachmentByNumberOperation(String * folder, uint32_t number, String * partID,
                                                                                    Encoding encoding, bool urgent = false);
        
        virtual IMAPFetchParsedContentOperation * fetchParsedMessageByUIDOperation(String * folder, uint32_t uid, bool urgent = false);
        virtual IMAPFetchParsedContentOperation * fetchParsedMessageByNumberOperation(String * folder, uint32_t number, bool urgent = false);

        virtual IMAPOperation * storeFlagsByUIDOperation(String * folder, IndexSet * uids, IMAPStoreFlagsRequestKind kind, MessageFlag flags, Array * customFlags = NULL);
        virtual IMAPOperation * storeFlagsByNumberOperation(String * folder, IndexSet * numbers, IMAPStoreFlagsRequestKind kind, MessageFlag flags, Array * customFlags = NULL);
        virtual IMAPOperation * storeLabelsByUIDOperation(String * folder, IndexSet * uids, IMAPStoreFlagsRequestKind kind, Array * labels);
        virtual IMAPOperation * storeLabelsByNumberOperation(String * folder, IndexSet * numbers, IMAPStoreFlagsRequestKind kind, Array * labels);
        
        virtual IMAPSearchOperation * searchOperation(String * folder, IMAPSearchKind kind, String * searchString);
        virtual IMAPSearchOperation * searchOperation(String * folder, IMAPSearchExpression * expression);
        
        virtual IMAPIdleOperation * idleOperation(String * folder, uint32_t lastKnownUID);
        
        virtual IMAPFetchNamespaceOperation * fetchNamespaceOperation();
        
        virtual IMAPIdentityOperation * identityOperation(IMAPIdentity * identity);
        
        virtual IMAPOperation * connectOperation();
        virtual IMAPCheckAccountOperation * checkAccountOperation();
        virtual IMAPOperation * disconnectOperation();
        
        virtual IMAPCapabilityOperation * capabilityOperation();
        virtual IMAPQuotaOperation * quotaOperation();
        
        virtual IMAPOperation * noopOperation();
        
        virtual IMAPMessageRenderingOperation * htmlRenderingOperation(IMAPMessage * message, String * folder);
        virtual IMAPMessageRenderingOperation * htmlBodyRenderingOperation(IMAPMessage * message, String * folder);
        virtual IMAPMessageRenderingOperation * plainTextRenderingOperation(IMAPMessage * message, String * folder);
        virtual IMAPMessageRenderingOperation * plainTextBodyRenderingOperation(IMAPMessage * message, String * folder, bool stripWhitespace);
        
    public: // private
        virtual void automaticConfigurationDone(IMAPSession * session);
        virtual void operationRunningStateChanged();
        virtual IMAPAsyncConnection * sessionForFolder(String * folder, bool urgent = false);
        
    private:
        Array * mSessions;
        
        String * mHostname;
        unsigned int mPort;
        String * mUsername;
        String * mPassword;
        String * mOAuth2Token;
        AuthType mAuthType;
        ConnectionType mConnectionType;
        bool mCheckCertificateEnabled;
        bool mVoIPEnabled;
        bool mQResyncCompatible;
        IMAPNamespace * mDefaultNamespace;
        time_t mTimeout;
        bool mAllowsFolderConcurrentAccessEnabled;
        unsigned int mMaximumConnections;
        time_t mAutomaticDisconnectDelay;
        ConnectionLogger * mConnectionLogger;
        bool mAutomaticConfigurationDone;
        IMAPIdentity * mServerIdentity;
        IMAPIdentity * mClientIdentity;
        bool mQueueRunning;
        OperationQueueCallback * mOperationQueueCallback;
#if MC_HAS_GCD
        dispatch_queue_t mDispatchQueue;
#endif
        String * mGmailUserDisplayName;
        bool mIdleEnabled;

        /*! Create new IMAP session */
        virtual IMAPAsyncConnection * session();
        /*! Returns a new or an existing session, it is best suited to run the IMAP command
         in the specified folder. */
        virtual IMAPAsyncConnection * matchingSessionForFolder(String * folder);
        /*! Returns a session with minimum operation queue among already created ones.
         If @param filterByFolder is true, then function filters sessions with
         predicate ( lastFolder() EQUALS TO @param folder ). In case of param folder is NULL
         the function would search a session among non-selected ones.
         Reserved sessions are skipped unless @param includeReserved is true. */
        virtual IMAPAsyncConnection * sessionWithMinQueue(bool filterByFolder, String * folder, bool includeReserved = false);
        /*! Returns existant or new session with empty operation queue, if it can.
         Otherwise, returns the session with the minimum size of the operation queue. */
        virtual IMAPAsyncConnection * availableSession();
        virtual IMAPMessageRenderingOperation * renderingOperation(IMAPMessage * message,
                                                                   String * folder,
                                                                   IMAPMessageRenderingType type);
    };
    
}

#endif

#endif
