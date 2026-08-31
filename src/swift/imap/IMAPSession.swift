import Foundation
import Dispatch
import CMailCore

/**
 This is the main IMAP class from which all operations are created
 
 After calling a method that returns an operation you must call start: on the instance
 to begin the operation.
 */
public class MCOIMAPSession: NSObjectCompat {
	
	internal var session:CIMAPAsyncSession;

	public override init() {
 		session = CIMAPAsyncSession_new(MCOConnectionLoggerLog, MCOConnectionLoggerRelease);
	}
    
    deinit {
        session.release()
    }
    
    /** This is the hostname of the IMAP server to connect to. */
    public var hostname: String? {
        get {
            return mailCoreAutoreleasePool {
                session.hostname.string()
            }
        }
        set {
            mailCoreAutoreleasePool {
                session.hostname = newValue?.mailCoreString() ?? MailCoreString()
            }
        }
    }
    
    /** This is the port of the IMAP server to connect to. */
    public var port: UInt32 {
        get { return session.port; }
        set { session.port = newValue }
    }
    
    /** This is the username of the account. */
    public var username: String? {
        get {
            return mailCoreAutoreleasePool {
                session.username.string()
            }
        }
        set {
            mailCoreAutoreleasePool {
                session.username = newValue?.mailCoreString() ?? MailCoreString()
            }
        }
    }
    
    /** This is the password of the account. */
    public var password: String? {
        get {
            return mailCoreAutoreleasePool {
                session.password.string()
            }
        }
        set {
            mailCoreAutoreleasePool {
                session.password = newValue?.mailCoreString() ?? MailCoreString()
            }
        }
    }
    
    /** This is the OAuth2 token. */
    public var OAuth2Token: String? {
        get {
            return mailCoreAutoreleasePool {
                session.OAuth2Token.string()
            }
        }
        set {
            mailCoreAutoreleasePool {
                session.OAuth2Token = newValue?.mailCoreString() ?? MailCoreString()
            }
        }
    }
    
    /**
     This is the authentication type to use to connect.
     `MCOAuthTypeSASLNone` means that it uses the clear-text is used (and is the default).
     @warning *Important*: Over an encrypted connection like TLS, the password will still be secure
     */
    public var authType: MCOAuthType {
        get { return MCOAuthType(cAuthType: session.authType) }
        set { session.authType = newValue.toCAuthType() }
    }
    
    /**
     This is the encryption type to use.
     See MCOConnectionType for more information.
     */
    public var connectionType: ConnectionType {
        get { return session.connectionType }
        set { session.connectionType = newValue }
    }
    
    /** This is the timeout of the connection. */
    public var timeout: TimeInterval {
        get { return Double(session.timeout) }
        set { session.timeout = time_t(newValue) }
    }
    
    /** When set to YES, the connection will fail if the certificate is incorrect. */
    public var isCheckCertificateEnabled: Bool {
        get { return session.isCheckCertificateEnabled }
        set { session.isCheckCertificateEnabled = newValue }
    }
    
    /** The default namespace. */
    public var defaultNamespace: MCOIMAPNamespace? {
        get {
            return mailCoreAutoreleasePool {
                createMCOObject(from: session.defaultNamespace.toCObject())
            }
        }
        set {
            mailCoreAutoreleasePool {
                session.defaultNamespace = newValue?.nativeInstance ?? CIMAPNamespace()
            }
        }
    }
    
    /**
     When set to YES, the session is allowed open to open several connections to the same folder.
     @warning Some older IMAP servers don't like this
     */
    public var allowsFolderConcurrentAccessEnabled: Bool {
        get { return session.allowsFolderConcurrentAccessEnabled }
        set { session.allowsFolderConcurrentAccessEnabled = newValue }
    }
    
    /**
     Maximum number of connections to the server allowed.
     */
    public var maximumConnections: UInt32 {
        get { return session.maximumConnections }
        set { session.maximumConnections = newValue }
    }

    /**
     How long an idle connection stays open once its operation queue drains, in seconds.
     Defaults to 30. Applies to connections created after the change.
     */
    public var automaticDisconnectDelay: TimeInterval {
        get { return Double(session.automaticDisconnectDelay) }
        set { session.automaticDisconnectDelay = time_t(newValue) }
    }

    /**
     Reserves one connection of the pool for exclusive use: the regular per-operation selection
     stops seeing it, so new commands run on it only when explicitly pointed at it with
     MCOIMAPBaseOperation.setConnection(_:), and the idle auto-disconnect defers instead of
     firing. Exclusivity is forward-only: operations already queued on the connection still run
     ahead of the lease holder's (selection prefers an idle or new connection, so a backlog is
     only possible with the pool at its limit).

     Returns nil when every connection is already reserved - callers must then fall back to the
     shared pool. The reverse degradation exists too: while the pool is at its limit and fully
     reserved, regular operations share the least busy reserved connection, so size
     maximumConnections against the number of simultaneous leases. Every acquired connection
     must be handed back with releaseConnection(_:disconnect:): a leaked lease permanently
     shrinks the pool.
     */
    public func acquireConnection(folder: String?) -> MCOIMAPAsyncConnection? {
        return mailCoreAutoreleasePool {
            let connection = session.acquireConnection(folder?.mailCoreString() ?? MailCoreString())
            guard connection.instance != nil else {
                return nil
            }
            return MCOIMAPAsyncConnection(connection: connection)
        }
    }

    /**
     Returns an acquired connection to the shared pool.

     With disconnect, the socket is torn down first (the connection object stays pooled and
     reconnects on next use) - for servers that pin a mailbox snapshot per connection, and
     mandatory after interruptCurrentCommand(), since a cancelled stream does not recover.
     */
    public func releaseConnection(_ connection: MCOIMAPAsyncConnection, disconnect: Bool) {
        mailCoreAutoreleasePool {
            session.releaseConnection(connection.connection, disconnect)
        }
    }

    /**
     Sets logger callback. The network traffic will be sent to this block.
     
     [session setConnectionLogger:^(void * connectionID, MCOConnectionLogType type, NSData * data) {
     NSLog(@"%@", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
     // ...
     }];
     */
    public func setConnectionLogger(_ newValue: MCOConnectionLogger?) {
        if let newValue = newValue {
            self.session.setConnectionLogger(newValue.getRetainedPointer())
        }
        else {
            self.session.setConnectionLogger(nil)
        }
    }
    
    /** This property provides some hints to MCOIMAPSession about where it's called from.
     It will make MCOIMAPSession safe. It will also set all the callbacks of operations to run on this given queue.
     Defaults to the main queue.
     This property should be used only if there's performance issue using MCOIMAPSession in the main thread. */
    public var dispatchQueue: DispatchQueue? {
        get {
            return DispatchQueue.queueFromWrapped(session.dispatchQueue())
        }
        set {
            session.setDispatchQueue(newValue?.wrapped)
        }
    }
    
    public var isVoIPEnabled: Bool {
        get { return session.isVoIPEnabled }
        set { session.isVoIPEnabled = newValue }
    }
    
    public var isIdleEnabled: Bool {
        get { return session.isIdleEnabled }
    }
    
    public var isOperationQueueRunning: Bool {
        get { return session.isOperationQueueRunning }
    }
    
    public var qResyncCompatible: Bool {
        get { return session.isQResyncCompatible }
        set { session.isQResyncCompatible = newValue }
    }

    /**
     Cancel all operations
     */
    public func cancelAllOperations() {
        return mailCoreAutoreleasePool {
            session.cancelAllOperations()
        }
    }
    
    /**
     Returns an operation that gets the list of subscribed folders.
     
     MCOIMAPFetchFoldersOperation * op = [session fetchSubscribedFoldersOperation];
     [op start:^(NSError * __nullable error, NSArray * folders) {
     ...
     }];
     */
    
    public func fetchSubscribedFoldersOperation() -> MCOIMAPFetchFoldersOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchFoldersOperation.init(operation: session.fetchSubscribedFoldersOperation())
        }
    }
    
    /**
     Creates an operation for renaming a folder
     
     MCOIMAPOperation * op = [session renameFolderOperation:@"my documents" otherName:@"Documents"];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     
     */
    public func renameFolderOperation(folder: String, otherName: String) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation.init(operation: session.renameFolderOperation(folder.mailCoreString(), otherName.mailCoreString()))
        }
    }

    /**
     Returns an operation to disconnect the session.
     It will disconnect all the sockets created by the session.
     
     MCOIMAPOperation * op = [session disconnectOperation];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func disconnectOperation() -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation(operation: session.disconnectOperation())
        }
    }
    
    /**
     Returns an operation that will connect to the given IMAP server without authenticating.
     Useful for checking initial server capabilities.
     
     MCOIMAPOperation * op = [session connectOperation];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func connectOperation() -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation.init(operation: session.connectOperation())
        }
    }

    /**
     Returns an operation that will perform a No-Op operation on the given IMAP server.
     
     MCOIMAPOperation * op = [session noopOperation];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func noopOperation() -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation(operation: session.noopOperation())
        }
    }

    /**
     Returns an operation that will check whether the IMAP account is valid.
     
     MCOIMAPOperation * op = [session checkAccountOperation];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func checkAccountOperation() -> MCOIMAPCheckAccountOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPCheckAccountOperation(checkAccountOperation: session.checkAccountOperation())
        }
    }

    /**
     Returns an operation to request capabilities of the server.
     See MCOIMAPCapability for the list of capabilities.
     
     canIdle = NO;
     MCOIMAPCapabilityOperation * op = [session capabilityOperation];
     [op start:^(NSError * __nullable error, MCOIndexSet * capabilities) {
     if ([capabilities containsIndex:MCOIMAPCapabilityIdle]) {
     canIdle = YES;
     }
     }];
     */
    public func capabilityOperation() -> MCOIMAPCapabilityOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPCapabilityOperation(operation: session.capabilityOperation())
        }
    }
    
    public func quotaOperation() -> MCOIMAPQuotaOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPQuotaOperation(operation: session.quotaOperation())
        }
    }
    
    /**
     Returns an operation that gets all folders
     
     MCOIMAPFetchFoldersOperation * op = [session fetchAllFoldersOperation];
     [op start:^(NSError * __nullable error, NSArray *folders) {
     ...
     }];
     */
    public func fetchAllFoldersOperation() -> MCOIMAPFetchFoldersOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchFoldersOperation(operation: session.fetchAllFoldersOperation())
        }
    }
    
    /**
     Returns an operation to expunge a folder.
     
     MCOIMAPOperation * op = [session expungeOperation:@"INBOX"];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func expungeOperation(folder:String) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation(operation: session.expungeOperation(folder.mailCoreString()))
        }
    }

    /**
     Returns an operation that creates a new folder
     
     MCOIMAPOperation * op = [session createFolderOperation:@"holidays 2013"];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func createFolderOperation(folder:String) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation(operation: session.createFolderOperation(folder.mailCoreString()))
        }
    }
    
    /**
     Returns an operation to subscribe to a folder.
     
     MCOIMAPOperation * op = [session createFolderOperation:@"holidays 2013"];
     [op start:^(NSError * __nullable error) {
     if (error != nil)
     return;
     MCOIMAPOperation * op = [session subscribeFolderOperation:@"holidays 2013"];
     ...
     }];
     */
    public func subscribeFolderOperation(folder: String) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation.init(operation: session.subscribeFolderOperation(folder.mailCoreString()))
        }
    }
    
    /**
     Returns an operation to unsubscribe from a folder.
     
     MCOIMAPOperation * op = [session unsubscribeFolderOperation:@"holidays 2009"];
     [op start:^(NSError * __nullable error) {
     if (error != nil)
     return;
     MCOIMAPOperation * op = [session deleteFolderOperation:@"holidays 2009"]
     ...
     }];
     */
    public func unsubscribeFolderOperation(folder: String) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation.init(operation: session.unsubscribeFolderOperation(folder.mailCoreString()))
        }
    }

    /**
     Returns an operation to unsubscribe from a folder.
     
     MCOIMAPOperation * op = [session unsubscribeFolderOperation:@"holidays 2009"];
     [op start:^(NSError * __nullable error) {
     if (error != nil)
     return;
     MCOIMAPOperation * op = [session deleteFolderOperation:@"holidays 2009"]
     ...
     }];
     */
    public func deleteFolderOperation(folder:String) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation(operation: session.deleteFolderOperation(folder.mailCoreString()))
        }
    }

    public func storeFlagsByUIDOperation(folder:String, uids:MCOIndexSet, kind:IMAPStoreFlagsRequestKind, flags:MCOMessageFlag, customFlags:Array<String>) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation(operation: session.storeFlagsByUIDOperation(folder.mailCoreString(), uids.cast(), kind, flags.toCMessageFlag(), customFlags.mailCoreArray()))
        }
    }
    
    /**
     Returns an operation to change flags of messages.
     
     For example: Adds the seen flag to the message with UID 456.
     
     MCOIMAPOperation * op = [session storeFlagsOperationWithFolder:@"INBOX"
     uids:[MCOIndexSet indexSetWithIndex:456]
     kind:MCOIMAPStoreFlagsRequestKindAdd
     flags:MCOMessageFlagSeen];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func storeFlagsOperation(folder: String, uids: MCOIndexSet, kind: IMAPStoreFlagsRequestKind, flags: MCOMessageFlag) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation.init(operation: session.storeFlagsByUIDOperation(folder.mailCoreString(), uids.nativeInstance, kind, flags.toCMessageFlag(), CArray()))
        }
    }
    
    /**
     Returns an operation to change flags of messages, using IMAP sequence number.
     
     For example: Adds the seen flag to the message with the sequence number number 42.
     
     MCOIMAPOperation * op = [session storeFlagsOperationWithFolder:@"INBOX"
     numbers:[MCOIndexSet indexSetWithIndex:42]
     kind:MCOIMAPStoreFlagsRequestKindAdd
     flags:MCOMessageFlagSeen];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func storeFlagsOperation(folder: String, numbers: MCOIndexSet, kind: IMAPStoreFlagsRequestKind, flags: MCOMessageFlag) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation.init(operation: session.storeFlagsByNumberOperation(folder.mailCoreString(), numbers.nativeInstance, kind, flags.toCMessageFlag(), CArray()))
        }
    }
    
    /**
     Returns an operation to change flags and custom flags of messages.
     
     For example: Adds the seen flag and $CNS-Greeting-On flag to the message with UID 456.
     
     MCOIMAPOperation * op = [session storeFlagsOperationWithFolder:@"INBOX"
     uids:[MCOIndexSet indexSetWithIndex:456]
     kind:MCOIMAPStoreFlagsRequestKindAdd
     flags:MCOMessageFlagSeen
     customFlags:@["$CNS-Greeting-On"]];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func storeFlagsOperation(folder: String, uids: MCOIndexSet, kind: IMAPStoreFlagsRequestKind, flags: MCOMessageFlag, customFlags: Array<String>) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation.init(operation: session.storeFlagsByUIDOperation(folder.mailCoreString(), uids.nativeInstance, kind, flags.toCMessageFlag(), customFlags.mailCoreArray()))
        }
    }
    
    /**
     Returns an operation to change flags and custom flags of messages, using IMAP sequence number.
     
     For example: Adds the seen flag and $CNS-Greeting-On flag to the message with the sequence number 42.
     
     MCOIMAPOperation * op = [session storeFlagsOperationWithFolder:@"INBOX"
     numbers:[MCOIndexSet indexSetWithIndex:42]
     kind:MCOIMAPStoreFlagsRequestKindAdd
     flags:MCOMessageFlagSeen
     customFlags:@["$CNS-Greeting-On"]];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func storeFlagsOperation(folder: String, numbers: MCOIndexSet, kind: IMAPStoreFlagsRequestKind, flags: MCOMessageFlag, customFlags: Array<String>) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation.init(operation: session.storeFlagsByNumberOperation(folder.mailCoreString(), numbers.nativeInstance, kind, flags.toCMessageFlag(), customFlags.mailCoreArray()))
        }
    }
    
    /**
     Returns an operation to change labels of messages. Intended for Gmail
     
     For example: Adds the label "Home" flag to the message with UID 42.
     
     MCOIMAPOperation * op = [session storeLabelsOperationWithFolder:@"INBOX"
     numbers:[MCOIndexSet indexSetWithIndex:42]
     kind:MCOIMAPStoreFlagsRequestKindAdd
     labels:[NSArray arrayWithObject:@"Home"]];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func storeLabelsOperation(folder: String, numbers: MCOIndexSet, kind: IMAPStoreFlagsRequestKind, labels: Array<String>) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation.init(operation: session.storeLabelsByNumberOperation(folder.mailCoreString(), numbers.nativeInstance, kind, labels.mailCoreArray()))
        }
    }
    
    /**
     Returns an operation to change labels of messages. Intended for Gmail
     
     For example: Adds the label "Home" flag to the message with UID 456.
     
     MCOIMAPOperation * op = [session storeLabelsOperationWithFolder:@"INBOX"
     uids:[MCOIndexSet indexSetWithIndex:456]
     kind:MCOIMAPStoreFlagsRequestKindAdd
     labels:[NSArray arrayWithObject:@"Home"]];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func storeLabelsOperation(folder: String, uids: MCOIndexSet, kind: IMAPStoreFlagsRequestKind, labels: Array<String>) -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation.init(operation: session.storeLabelsByUIDOperation(folder.mailCoreString(), uids.nativeInstance, kind, labels.mailCoreArray()))
        }
    }
    
    /**
     Returns an operation to add a message to a folder.
     
     MCOIMAPOperation * op = [session appendMessageOperationWithFolder:@"Sent Mail" messageData:rfc822Data flags:MCOMessageFlagNone];
     [op start:^(NSError * __nullable error, uint32_t createdUID) {
     if (error == nil) {
     NSLog(@"created message with UID %lu", (unsigned long) createdUID);
     }
     }];
     */
    public func appendMessageOperation(folder: String, messageData: Data, flags: MCOMessageFlag) -> MCOIMAPAppendMessageOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPAppendMessageOperation.init(operation: session.appendMessageOperationWithData(folder.mailCoreString(), messageData.mailCoreData(), flags.toCMessageFlag(), CArray()))
        }
    }
    
    /**
     Returns an operation to add a message with custom flags to a folder.
     
     MCOIMAPOperation * op = [session appendMessageOperationWithFolder:@"Sent Mail" messageData:rfc822Data flags:MCOMessageFlagNone customFlags:@[@"$CNS-Greeting-On"]];
     [op start:^(NSError * __nullable error, uint32_t createdUID) {
     if (error == nil) {
     NSLog(@"created message with UID %lu", (unsigned long) createdUID);
     }
     }];
     */
    public func appendMessageOperation(folder: String, messageData: Data, flags: MCOMessageFlag, customFlags:Array<String>) -> MCOIMAPAppendMessageOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPAppendMessageOperation.init(operation: session.appendMessageOperationWithData(folder.mailCoreString(), messageData.mailCoreData(), flags.toCMessageFlag(), customFlags.mailCoreArray()))
        }
    }

    /**
     Returns an operation to add a message to a folder.
     
     MCOIMAPOperation * op = [session appendMessageOperationWithFolder:@"Sent Mail" messageData:rfc822Data flags:MCOMessageFlagNone];
     [op start:^(NSError * __nullable error, uint32_t createdUID) {
     if (error == nil) {
     NSLog(@"created message with UID %lu", (unsigned long) createdUID);
     }
     }];
     */
    public func appendMessageOperation(folder:String, contentsAtPath path:String, flags:MCOMessageFlag, customFlags:Array<String>) -> MCOIMAPAppendMessageOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPAppendMessageOperation(operation: session.appendMessageOperation(folder.mailCoreString(), path.mailCoreString(), flags.toCMessageFlag(), customFlags.mailCoreArray()))
        }
    }

    /**
     Returns an operation to fetch messages by (sequence) number.
     For example: show 50 most recent uids.
     NSString *folder = @"INBOX";
     MCOIMAPFolderInfoOperation *folderInfo = [session folderInfoOperation:folder];
     
     [folderInfo start:^(NSError *error, MCOIMAPFolderInfo *info) {
     int numberOfMessages = 50;
     numberOfMessages -= 1;
     MCOIndexSet *numbers = [MCOIndexSet indexSetWithRange:MCORangeMake([info messageCount] - numberOfMessages, numberOfMessages)];
     
     MCOIMAPFetchMessagesOperation *fetchOperation = [session fetchMessagesByNumberOperationWithFolder:folder
     requestKind:MCOIMAPMessagesRequestKindUid
     numbers:numbers];
     
     [fetchOperation start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
     for (MCOIMAPMessage * message in messages) {
     NSLog(@"%u", [message uid]);
     }
     }];
     }];
     */
    public func fetchMessagesByNumber(folder:String, kind:MCOIMAPMessagesRequestKind, numbers:MCOIndexSet) -> MCOIMAPFetchMessagesOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchMessagesOperation(operation: session.fetchMessagesByNumberOperation(folder.mailCoreString(), kind.toCIMAPMessagesRequestKind(), numbers.cast()));
        }
    }

    /**
     Returns an operation to fetch messages by (sequence) number.
     For example: show 50 most recent uids.
     NSString *folder = @"INBOX";
     MCOIMAPFolderInfoOperation *folderInfo = [session folderInfoOperation:folder];
     
     [folderInfo start:^(NSError *error, MCOIMAPFolderInfo *info) {
     int numberOfMessages = 50;
     numberOfMessages -= 1;
     MCOIndexSet *numbers = [MCOIndexSet indexSetWithRange:MCORangeMake([info messageCount] - numberOfMessages, numberOfMessages)];
     
     MCOIMAPFetchMessagesOperation *fetchOperation = [session fetchMessagesByNumberOperationWithFolder:folder
     requestKind:MCOIMAPMessagesRequestKindUid
     numbers:numbers];
     
     [fetchOperation start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
     for (MCOIMAPMessage * message in messages) {
     NSLog(@"%u", [message uid]);
     }
     }];
     }];
     */
    public func fetchMessagesByUid(folder:String, kind:MCOIMAPMessagesRequestKind, uids:MCOIndexSet) -> MCOIMAPFetchMessagesOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchMessagesOperation(operation: session.fetchMessagesByUIDOperation(folder.mailCoreString(), kind.toCIMAPMessagesRequestKind(), uids.cast()));
        }
    }

    /**
     Returns an operation to sync the last changes related to the given message list given a modSeq.
     
     MCOIMAPFetchMessagesOperation * op = [session syncMessagesByUIDWithFolder:@"INBOX"
     requestKind:MCOIMAPMessagesRequestKindUID
     uids:MCORangeMake(1, UINT64_MAX)
     modSeq:lastModSeq];
     [op start:^(NSError * __nullable error, NSArray * messages, MCOIndexSet * vanishedMessages) {
     NSLog(@"added or modified messages: %@", messages);
     NSLog(@"deleted messages: %@", vanishedMessages);
     }];
     
     @warn *Important*: This is only for servers that support Conditional Store. See [RFC4551](http://tools.ietf.org/html/rfc4551)
     vanishedMessages will be set only for servers that support QRESYNC. See [RFC5162](http://tools.ietf.org/html/rfc5162)
     */
    public func syncMessages(folder:String, kind:MCOIMAPMessagesRequestKind, uids:MCOIndexSet, modSeq:UInt64) -> MCOIMAPFetchMessagesOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchMessagesOperation(operation: session.syncMessagesByUIDOperation(folder.mailCoreString(), kind.toCIMAPMessagesRequestKind(), uids.cast(), modSeq));
        }
    }

    /**
     Returns an operation to fetch the content of a message.
     @param urgent is set to YES, an additional connection to the same folder might be opened to fetch the content.
     
     MCOIMAPFetchContentOperation * op = [session fetchMessageOperationWithFolder:@"INBOX" uid:456 urgent:NO];
     [op start:^(NSError * __nullable error, NSData * messageData) {
     MCOMessageParser * parser = [MCOMessageParser messageParserWithData:messageData]
     ...
     }];
     */
    public func fetchMessageOperation(folder:String, uid:UInt32, urgent:Bool) -> MCOIMAPFetchContentOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchContentOperation(operation: session.fetchMessageByUIDOperation(folder.mailCoreString(), uid, urgent));
        }
    }
    
    /**
     Returns an operation to fetch the content of a message.
     
     MCOIMAPFetchContentOperation * op = [session fetchMessageOperationWithFolder:@"INBOX" uid:456];
     [op start:^(NSError * __nullable error, NSData * messageData) {
     MCOMessageParser * parser = [MCOMessageParser messageParserWithData:messageData]
     ...
     }];
     */
    public func fetchMessageOperation(folder: String, uid: UInt32) -> MCOIMAPFetchContentOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchContentOperation.init(operation: session.fetchMessageByUIDOperation(folder.mailCoreString(), uid, false))
        }
    }
    
    /**
     Returns an operation to fetch the content of a message, using IMAP sequence number.
     @param urgent is set to YES, an additional connection to the same folder might be opened to fetch the content.
     
     MCOIMAPFetchContentOperation * op = [session fetchMessageOperationWithFolder:@"INBOX" number:42 urgent:NO];
     [op start:^(NSError * __nullable error, NSData * messageData) {
     MCOMessageParser * parser = [MCOMessageParser messageParserWithData:messageData]
     ...
     }];
     */
    public func fetchMessageOperation(folder:String, number:UInt32, urgent:Bool) -> MCOIMAPFetchContentOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchContentOperation(operation: session.fetchMessageByUIDOperation(folder.mailCoreString(), number, urgent));
        }
    }
    
    /**
     Returns an operation to fetch the content of a message, using IMAP sequence number.
     
     MCOIMAPFetchContentOperation * op = [session fetchMessageOperationWithFolder:@"INBOX" number:42];
     [op start:^(NSError * __nullable error, NSData * messageData) {
     MCOMessageParser * parser = [MCOMessageParser messageParserWithData:messageData]
     ...
     }];
     */
    public func fetchMessageOperation(folder:String, number:UInt32) -> MCOIMAPFetchContentOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchContentOperation(operation: session.fetchMessageByUIDOperation(folder.mailCoreString(), number, false));
        }
    }

    /**
     Returns an operation to fetch an attachment.
     @param  urgent is set to YES, an additional connection to the same folder might be opened to fetch the content.
     
     MCOIMAPFetchContentOperation * op = [session fetchMessageAttachmentOperationWithFolder:@"INBOX"
     uid:456
     partID:@"1.2"
     encoding:MCOEncodingBase64
     urgent:YES];
     [op start:^(NSError * __nullable error, NSData * partData) {
     ...
     }];
     */
    public func fetchMessageAttachmentOperation(folder:String, uid:UInt32, partId:String, encoding:Encoding, urgent:Bool) -> MCOIMAPFetchContentOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchContentOperation(operation: session.fetchMessageAttachmentByUIDOperation(folder.mailCoreString(),
                                                                                                        uid,
                                                                                                        partId.mailCoreString(),
                                                                                                        encoding,
                                                                                                        urgent))
        }
    }
    
    
    /**
     Returns an operation to fetch an attachment.
     
     Example 1:
     
     MCOIMAPFetchContentOperation * op = [session fetchMessageAttachmentOperationWithFolder:@"INBOX"
     uid:456
     partID:@"1.2"
     encoding:MCOEncodingBase64];
     [op start:^(NSError * __nullable error, NSData * partData) {
     ...
     }];
     
     Example 2:
     
     MCOIMAPFetchContentOperation * op = [session fetchMessageAttachmentOperationWithFolder:@"INBOX"
     uid:[message uid]
     partID:[part partID]
     encoding:[part encoding]];
     [op start:^(NSError * __nullable error, NSData * partData) {
     ...
     }];
     */
    public func fetchMessageAttachmentOperation(folder: String, uid: UInt32, partID: String, encoding: Encoding, urgent: Bool) -> MCOIMAPFetchContentOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchContentOperation.init(operation: session.fetchMessageAttachmentByUIDOperation(folder.mailCoreString(),
                                                                                                             uid,
                                                                                                             partID.mailCoreString(),
                                                                                                             encoding,
                                                                                                             urgent))
        }
    }
    
    /**
     Returns an operation to fetch an attachment.
     @param  urgent is set to YES, an additional connection to the same folder might be opened to fetch the content.
     
     MCOIMAPFetchContentOperation * op = [session fetchMessageAttachmentOperationWithFolder:@"INBOX"
     uid:456
     partID:@"1.2"
     encoding:MCOEncodingBase64
     urgent:YES];
     [op start:^(NSError * __nullable error, NSData * partData) {
     ...
     }];
     */
    public func fetchMessageAttachmentOperation(folder:String, number:UInt32, partId:String, encoding:Encoding, urgent:Bool) -> MCOIMAPFetchContentOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchContentOperation(operation: session.fetchMessageAttachmentByNumberOperation(folder.mailCoreString(),
                                                                                                           number,
                                                                                                           partId.mailCoreString(),
                                                                                                           encoding,
                                                                                                           urgent))
        }
    }
    
    /**
     Returns an operation to fetch an attachment.
     
     Example 1:
     
     MCOIMAPFetchContentOperation * op = [session fetchMessageAttachmentOperationWithFolder:@"INBOX"
     number:42
     partID:@"1.2"
     encoding:MCOEncodingBase64];
     [op start:^(NSError * __nullable error, NSData * partData) {
     ...
     }];
     
     Example 2:
     
     MCOIMAPFetchContentOperation * op = [session fetchMessageAttachmentOperationWithFolder:@"INBOX"
     number:[message sequenceNumber]
     partID:[part partID]
     encoding:[part encoding]];
     [op start:^(NSError * __nullable error, NSData * partData) {
     ...
     }];
     */
    public func fetchMessageAttachmentOperation(folder:String, number:UInt32, partId:String, encoding:Encoding) -> MCOIMAPFetchContentOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchContentOperation(operation: session.fetchMessageAttachmentByNumberOperation(folder.mailCoreString(),
                                                                                                           number,
                                                                                                           partId.mailCoreString(),
                                                                                                           encoding,
                                                                                                           false))
        }
    }

    /**
     Returns an operation to search for messages.
     
     MCOIMAPSearchExpression * expr = [MCOIMAPSearchExpression searchFrom:@"laura@etpan.org"]
     MCOIMAPSearchOperation * op = [session searchExpressionOperationWithFolder:@"INBOX"
     expression:expr];
     [op start:^(NSError * __nullable error, MCOIndexSet * searchResult) {
     ...
     }];
     */
    public func searchExpressionOperation(folder:String, expression: MCOIMAPSearchExpression) -> MCOIMAPSearchOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPSearchOperation(operation: session.searchOperationWithExpression(folder.mailCoreString(), expression.cast()))
        }
    }

    /**
     Returns an operation to search for messages.
     
     MCOIMAPSearchExpression * expr = [MCOIMAPSearchExpression searchFrom:@"laura@etpan.org"]
     MCOIMAPSearchOperation * op = [session searchExpressionOperationWithFolder:@"INBOX"
     expression:expr];
     [op start:^(NSError * __nullable error, MCOIndexSet * searchResult) {
     ...
     }];
     */
    public func searchOperation(folder:String, kind:IMAPSearchKind, searchString:String) -> MCOIMAPSearchOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPSearchOperation(operation: session.searchOperation(folder.mailCoreString(), kind, searchString.mailCoreString()))
        }
    }

    /**
     Returns an operation to copy messages to a folder.
     
     MCOIMAPCopyMessagesOperation * op = [session copyMessagesOperationWithFolder:@"INBOX"
     uids:[MCIndexSet indexSetWithIndex:456]
     destFolder:@"Cocoa"];
     [op start:^(NSError * __nullable error, NSDictionary * uidMapping) {
     NSLog(@"copied to folder with UID mapping %@", uidMapping);
     }];
     */
    public func copyMessagesOperation(folder:String, uids:MCOIndexSet, destFolder:String) -> MCOIMAPCopyMessagesOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPCopyMessagesOperation(operation: session.copyMessagesOperation(folder.mailCoreString(), uids.cast(), destFolder.mailCoreString()))
        }
    }

    /**
     Returns an operation that retrieves folder metadata (like UIDNext)
     
     MCOIMAPFolderInfoOperation * op = [session folderInfoOperation:@"INBOX"];
     [op start:^(NSError *error, MCOIMAPFolderInfo * info) {
     NSLog(@"UIDNEXT: %lu", (unsigned long) [info uidNext]);
     NSLog(@"UIDVALIDITY: %lu", (unsigned long) [info uidValidity]);
     NSLog(@"HIGHESTMODSEQ: %llu", (unsigned long long) [info modSequenceValue]);
     NSLog(@"messages count: %lu", [info messageCount]);
     }];
     */
    public func folderInfoOperation(folder:String) -> MCOIMAPFolderInfoOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFolderInfoOperation(operation: session.folderInfoOperation(folder.mailCoreString()))
        }
    }

    /**
     Returns an operation that retrieves folder status (like UIDNext - Unseen -)
     
     MCOIMAPFolderStatusOperation * op = [session folderStatusOperation:@"INBOX"];
     [op start:^(NSError *error, MCOIMAPFolderStatus * info) {
     NSLog(@"UIDNEXT: %lu", (unsigned long) [info uidNext]);
     NSLog(@"UIDVALIDITY: %lu", (unsigned long) [info uidValidity]);
     NSLog(@"messages count: %lu", [info totalMessages]);
     }];
     */
    public func folderStatusOperation(folder:String) -> MCOIMAPFolderStatusOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFolderStatusOperation(operation: session.folderStatusOperation(folder.mailCoreString()))
        }
    }
    
    /**
     Returns an operation to wait for something to happen in the folder.
     See [RFC2177](http://tools.ietf.org/html/rfc2177) for me info.
     
     MCOIMAPIdleOperation * op = [session idleOperationWithFolder:@"INBOX"
     lastKnownUID:0];
     [op start:^(NSError * __nullable error) {
     ...
     }];
     */
    public func idleOperation(folder:String, lastKnownUID:UInt32) -> MCOIMAPIdleOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPIdleOperation(idleOperation: session.idleOperation(folder.mailCoreString(), lastKnownUID))
        }
    }
    
    /**
     Returns an operation for custom command.
     @param command is the text representation of the command to be send.
     
     
     MCOIMAPCustomCommandOperation * op = [session customCommandOperation:@"ACTIVATE SERVICE"];
     [op start: ^(NSString * __nullable response, NSError * __nullable error) {
     ...
     }];
     */
    public func customCommandOperation(_ command: String) -> MCOIMAPCustomCommandOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPCustomCommandOperation.init(operation: session.customCommandOperation(command.mailCoreString()))
        }
    }
    
    /**
     Returns an operation to fetch an attachment to a file.
     @param  urgent is set to YES, an additional connection to the same folder might be opened to fetch the content.
     MCOOperation will be perform in a memory efficient manner.
     
     MCOIMAPFetchContentToFileOperation * op = [session fetchMessageAttachmentToFileOperationWithFolder:@"INBOX"
     uid:456
     partID:@"1.2"
     encoding:MCOEncodingBase64
     filename:filename
     urgent:YES];
     
     // Optionally, explicitly enable chunked mode
     [op setLoadingByChunksEnabled:YES];
     [op setChunksSize:1024*1024];
     // need in chunked mode for correct progress indication
     [op setEstimatedSize:sizeOfAttachFromBodystructure];
     
     [op start:^(NSError * __nullable error) {
     ...
     }];
     
     */
    func fetchMessageAttachmentToFileOperation(folder: String, uid: UInt32, partID: String, encoding: Encoding, filename:String, urgent: Bool) -> MCOIMAPFetchContentToFileOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchContentToFileOperation(operation: session.fetchMessageAttachmentToFileOperation(folder.mailCoreString(),
                                                                                                               uid,
                                                                                                               partID.mailCoreString(),
                                                                                                               encoding,
                                                                                                               filename.mailCoreString(),
                                                                                                               urgent))
        }
    }
    
    /**
     Returns an operation to fetch the list of namespaces.
     
     MCOIMAPFetchNamespaceOperation * op = [session fetchNamespaceOperation];
     [op start:^(NSError * __nullable error, NSDictionary * namespaces) {
     if (error != nil)
     return;
     MCOIMAPNamespace * ns = [namespace objectForKey:MCOIMAPNamespacePersonal];
     NSString * path = [ns pathForComponents:[NSArray arrayWithObject:]];
     MCOIMAPOperation * createOp = [session createFolderOperation:foobar];
     [createOp start:^(NSError * __nullable error) {
     ...
     }];
     }];
     */
    public func fetchNamespaceOperation() -> MCOIMAPFetchNamespaceOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchNamespaceOperation(operation: session.fetchNamespaceOperation())
        }
    }
    
    /**
     Returns an operation to move messages to a folder.
     
     MCOIMAPMoveMessagesOperation * op = [session moveMessagesOperationWithFolder:@"INBOX"
     uids:[MCIndexSet indexSetWithIndex:456]
     destFolder:@"Cocoa"];
     [op start:^(NSError * __nullable error, NSDictionary * uidMapping) {
     NSLog(@"moved to folder with UID mapping %@", uidMapping);
     }];
     */
    public func moveMessagesOperation(folder: String, uids: MCOIndexSet, destFolder: String) -> MCOIMAPMoveMessagesOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPMoveMessagesOperation.init(operation: session.moveMessagesOperation(folder.mailCoreString(), uids.nativeInstance, destFolder.mailCoreString()))
        }
    }
    
    /**
     Returns an operation to fetch the parsed content of a message.
     @param urgent is set to YES, an additional connection to the same folder might be opened to fetch the content.
     
     MCOIMAPFetchParsedContentOperation * op = [session fetchParsedMessageOperationWithFolder:@"INBOX" uid:456 urgent:NO];
     [op start:^(NSError * __nullable error, MCOMessageParser * parser) {
     
     ...
     }];
     */
    public func fetchParsedMessageOperation(folder: String, uid: UInt32, urgent: Bool) -> MCOIMAPFetchParsedContentOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchParsedContentOperation.init(operation: session.fetchParsedMessageOperationByUIDOperation(folder.mailCoreString(), uid, urgent))
        }
    }
    
    /**
     Returns an operation to fetch the parsed content of a message.
     
     MCOIMAPFetchParsedContentOperation * op = [session fetchParsedMessageOperationWithFolder:@"INBOX" uid:456];
     [op start:^(NSError * __nullable error, MCOMessageParser * parser) {
     
     ...
     }];
     */
    public func fetchParsedMessageOperation(folder: String, uid: UInt32) -> MCOIMAPFetchParsedContentOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchParsedContentOperation.init(operation: session.fetchParsedMessageOperationByUIDOperation(folder.mailCoreString(), uid, false))
        }
    }
    
    /**
     Returns an operation to fetch the parsed content of a message, using IMAP sequence number.
     @param urgent is set to YES, an additional connection to the same folder might be opened to fetch the content.
     
     MCOIMAPFetchParsedContentOperation * op = [session fetchParsedMessageOperationWithFolder:@"INBOX" number:42 urgent:NO];
     [op start:^(NSError * __nullable error, MCOMessageParser * parser) {
     
     ...
     }];
     */
    public func fetchParsedMessageOperation(folder: String, number: UInt32, urgent: Bool) -> MCOIMAPFetchParsedContentOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchParsedContentOperation.init(operation: session.fetchParsedMessageOperationByNumberOperation(folder.mailCoreString(), number, urgent))
        }
    }
    
    /**
     Returns an operation to fetch the parsed content of a message, using IMAP sequence number.
     
     MCOIMAPFetchParsedContentOperation * op = [session fetchParsedMessageOperationWithFolder:@"INBOX" number:42];
     [op start:^(NSError * __nullable error, MCOMessageParser * parser) {
     
     ...
     }];
     */
    public func fetchParsedMessageOperation(folder: String, number: UInt32) -> MCOIMAPFetchParsedContentOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPFetchParsedContentOperation.init(operation: session.fetchParsedMessageOperationByNumberOperation(folder.mailCoreString(), number, false))
        }
    }
    
    /**
     Returns an operation to render the HTML version of a message to be displayed in a web view.
     
     MCOIMAPMessageRenderingOperation * op = [session htmlRenderingOperationWithMessage:msg
     folder:@"INBOX"];
     
     [op start:^(NSString * htmlString, NSError * error) {
     ...
     }];
     */
    public func htmlRenderingOperation(message: MCOIMAPMessage, folder: String) -> MCOIMAPMessageRenderingOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPMessageRenderingOperation.init(operation: session.htmlRenderingOperation(message.nativeInstance, folder.mailCoreString()))
        }
    }
    
    /**
     Returns an operation to render the HTML body of a message to be displayed in a web view.
     
     MCOIMAPMessageRenderingOperation * op = [session htmlBodyRenderingOperationWithMessage:msg
     folder:@"INBOX"];
     
     [op start:^(NSString * htmlString, NSError * error) {
     ...
     }];
     */
    public func htmlBodyRenderingOperation(message: MCOIMAPMessage, folder: String) -> MCOIMAPMessageRenderingOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPMessageRenderingOperation.init(operation: session.htmlBodyRenderingOperation(message.nativeInstance, folder.mailCoreString()))
        }
    }
    
    /**
     Returns an operation to render the plain text version of a message.
     
     MCOIMAPMessageRenderingOperation * op = [session plainTextRenderingOperationWithMessage:msg
     folder:@"INBOX"];
     
     [op start:^(NSString * htmlString, NSError * error) {
     ...
     }];
     */
    public func plainTextRenderingOperation(message: MCOIMAPMessage, folder: String) -> MCOIMAPMessageRenderingOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPMessageRenderingOperation.init(operation: session.plainTextRenderingOperation(message.nativeInstance, folder.mailCoreString()))
        }
    }
    
    /**
     Returns an operation to render the plain text body of a message.
     All end of line will be removed and white spaces cleaned up if requested.
     This method can be used to generate the summary of the message.
     
     MCOIMAPMessageRenderingOperation * op = [session plainTextBodyRenderingOperationWithMessage:msg
     folder:@"INBOX"
     stripWhitespace:YES];
     
     [op start:^(NSString * htmlString, NSError * error) {
     ...
     }];
     */
    public func plainTextBodyRenderingOperationWithMessage(message: MCOIMAPMessage, folder: String, stripWhitespace: Bool) -> MCOIMAPMessageRenderingOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPMessageRenderingOperation.init(operation: session.plainTextBodyRenderingOperation(message.nativeInstance, folder.mailCoreString(), stripWhitespace))
        }
    }
    
    /**
     Returns an operation to render the plain text body of a message.
     All end of line will be removed and white spaces cleaned up.
     This method can be used to generate the summary of the message.
     
     MCOIMAPMessageRenderingOperation * op = [session plainTextBodyRenderingOperationWithMessage:msg
     folder:@"INBOX"];
     
     [op start:^(NSString * htmlString, NSError * error) {
     ...
     }];
     */
    public func plainTextBodyRenderingOperationWithMessage(message: MCOIMAPMessage, folder: String) -> MCOIMAPMessageRenderingOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPMessageRenderingOperation.init(operation: session.plainTextBodyRenderingOperation(message.nativeInstance, folder.mailCoreString(), true))
        }
    }

}
