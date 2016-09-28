import Foundation

/**
 The class is used to get folder metadata (like UIDVALIDITY, UIDNEXT, etc).
 @see IMAPFolderStatus
 */
class ImapFolderStatusOperation : ImapBaseOperation {
    
    typealias CompletionBlock = (Error?, ImapFolderStatus?) -> Void
    
    private var operation: CIMAPFolderStatusOperation;
    private var completionBlock : CompletionBlock?;
    
    init(operation:CIMAPFolderStatusOperation) {
        self.operation = operation
        super.init(baseOperation: operation.baseOperation);
    }
    
    deinit {
        completionBlock = nil;
    }
    
    /**
     Starts the asynchronous operation.
     
     @param completionBlock Called when the operation is finished.
     
     - On success `error` will be nil and `status` will contain the status metadata
     
     - On failure, `error` will be set with `MCOErrorDomain` as domain and an
     error code available in `MCOConstants.h`, `status` will be nil
     */
    public func start(completionBlock: CompletionBlock?) {
        self.completionBlock = completionBlock;
        start();
    }
    
    override func cancel() {
        completionBlock = nil;
        super.cancel();
    }
    
    override func operationCompleted() {
        if (completionBlock == nil) {
            return;
        }
        
        let errorCode = error();
        if errorCode == ErrorNone {
            completionBlock!(nil, ImapFolderStatus(status: operation.status(operation)));
        }
        else {
            completionBlock!(MailCoreError(code: errorCode), nil);
        }
        completionBlock = nil;
    }
}
