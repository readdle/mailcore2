#ifndef MAILCORE_MESSAGE_CONSTANT
#define MAILCORE_MESSAGE_CONSTANT

#include "CData.h"

#ifdef __cplusplus
extern "C" {
#endif
    
    typedef enum {
        ConnectionTypeClear             = 1 << 0,
        ConnectionTypeStartTLS          = 1 << 1,
        ConnectionTypeTLS               = 1 << 2,
    } ConnectionType;
    
    typedef enum {
        AuthTypeSASLNone          = 0,
        AuthTypeSASLCRAMMD5       = 1 << 0,
        AuthTypeSASLPlain         = 1 << 1,
        AuthTypeSASLGSSAPI        = 1 << 2,
        AuthTypeSASLDIGESTMD5     = 1 << 3,
        AuthTypeSASLLogin         = 1 << 4,
        AuthTypeSASLSRP           = 1 << 5,
        AuthTypeSASLNTLM          = 1 << 6,
        AuthTypeSASLKerberosV4    = 1 << 7,
        AuthTypeXOAuth2           = 1 << 8,
        AuthTypeXOAuth2Outlook    = 1 << 9,
    }CAuthType;
    
    typedef enum {
        IMAPFolderFlagNone        = 0,
        IMAPFolderFlagMarked      = 1 << 0,
        IMAPFolderFlagUnmarked    = 1 << 1,
        IMAPFolderFlagNoSelect    = 1 << 2,
        IMAPFolderFlagNoInferiors = 1 << 3,
        IMAPFolderFlagInbox       = 1 << 4,
        IMAPFolderFlagSentMail    = 1 << 5,
        IMAPFolderFlagStarred     = 1 << 6,
        IMAPFolderFlagAllMail     = 1 << 7,
        IMAPFolderFlagTrash       = 1 << 8,
        IMAPFolderFlagDrafts      = 1 << 9,
        IMAPFolderFlagSpam        = 1 << 10,
        IMAPFolderFlagImportant   = 1 << 11,
        IMAPFolderFlagArchive     = 1 << 12,
        IMAPFolderFlagAll = IMAPFolderFlagAllMail,
        IMAPFolderFlagJunk = IMAPFolderFlagSpam,
        IMAPFolderFlagFlagged = IMAPFolderFlagStarred,
        IMAPFolderFlagFolderTypeMask = IMAPFolderFlagInbox | IMAPFolderFlagSentMail | IMAPFolderFlagStarred | IMAPFolderFlagAllMail |
          IMAPFolderFlagTrash| IMAPFolderFlagDrafts | IMAPFolderFlagSpam | IMAPFolderFlagImportant | IMAPFolderFlagArchive,
    }CIMAPFolderFlag;
    
    typedef enum {
        MessageFlagNone          = 0,
        MessageFlagSeen          = 1 << 0,
        MessageFlagAnswered      = 1 << 1,
        MessageFlagFlagged       = 1 << 2,
        MessageFlagDeleted       = 1 << 3,
        MessageFlagDraft         = 1 << 4,
        MessageFlagMDNSent       = 1 << 5,
        MessageFlagForwarded     = 1 << 6,
        MessageFlagSubmitPending = 1 << 7,
        MessageFlagSubmitted     = 1 << 8,
        MessageFlagMaskAll = MessageFlagSeen | MessageFlagAnswered | MessageFlagFlagged |
        MessageFlagDeleted | MessageFlagDraft | MessageFlagMDNSent | MessageFlagForwarded |
        MessageFlagSubmitPending | MessageFlagSubmitted,
    }CMessageFlag;
    
    typedef enum {
        IMAPMessagesRequestKindUid           = 0, // This is the default and it's always fetched
        IMAPMessagesRequestKindFlags         = 1 << 0,
        IMAPMessagesRequestKindHeaders       = 1 << 1,
        IMAPMessagesRequestKindStructure     = 1 << 2,
        IMAPMessagesRequestKindInternalDate  = 1 << 3,
        IMAPMessagesRequestKindFullHeaders   = 1 << 4,
        IMAPMessagesRequestKindHeaderSubject = 1 << 5,
        IMAPMessagesRequestKindGmailLabels   = 1 << 6,
        IMAPMessagesRequestKindGmailMessageID = 1 << 7,
        IMAPMessagesRequestKindGmailThreadID  = 1 << 8,
        IMAPMessagesRequestKindExtraHeaders  = 1 << 9,
        IMAPMessagesRequestKindSize          = 1 << 10,
    }CIMAPMessagesRequestKind;
    
    typedef enum {
        IMAPFetchRequestTypeUID = 0,
        IMAPFetchRequestTypeSequence = 1
    }IMAPFetchRequestType;
    
    typedef enum {
        IMAPStoreFlagsRequestKindAdd,
        IMAPStoreFlagsRequestKindRemove,
        IMAPStoreFlagsRequestKindSet,
    }IMAPStoreFlagsRequestKind;
    
    typedef enum {
        IMAPWorkaroundGmail = 1 << 0,
        IMAPWorkaroundYahoo = 1 << 1,
        IMAPWorkaroundExchange2003 = 1 << 2,
    }IMAPWorkaround;
    
    typedef enum {
        IMAPCapabilityACL,
        IMAPCapabilityBinary,
        IMAPCapabilityCatenate,
        IMAPCapabilityChildren,
        IMAPCapabilityCompressDeflate,
        IMAPCapabilityCondstore,
        IMAPCapabilityEnable,
        IMAPCapabilityIdle,
        IMAPCapabilityId,
        IMAPCapabilityLiteralPlus,
        IMAPCapabilityMove,
        IMAPCapabilityMultiAppend,
        IMAPCapabilityNamespace,
        IMAPCapabilityQResync,
        IMAPCapabilityQuota,
        IMAPCapabilitySort,
        IMAPCapabilityStartTLS,
        IMAPCapabilityThreadOrderedSubject,
        IMAPCapabilityThreadReferences,
        IMAPCapabilityUIDPlus,
        IMAPCapabilityUnselect,
        IMAPCapabilityXList,
        IMAPCapabilityAuthAnonymous,
        IMAPCapabilityAuthCRAMMD5,
        IMAPCapabilityAuthDigestMD5,
        IMAPCapabilityAuthExternal,
        IMAPCapabilityAuthGSSAPI,
        IMAPCapabilityAuthKerberosV4,
        IMAPCapabilityAuthLogin,
        IMAPCapabilityAuthNTLM,
        IMAPCapabilityAuthOTP,
        IMAPCapabilityAuthPlain,
        IMAPCapabilityAuthSKey,
        IMAPCapabilityAuthSRP,
        IMAPCapabilityXOAuth2,
        IMAPCapabilityXYMHighestModseq,
        IMAPCapabilityGmail,
    }IMAPCapability;
    
    typedef enum {
        POPCapabilityNone,
        POPCapabilityStartTLS,
        POPCapabilityTop,
        POPCapabilityUser,
        POPCapabilityRespCodes,
        POPCapabilityPipelining,
        POPCapabilityUIDL,
        POPCapabilitySASL,
        POPCapabilityAuthAnonymous,
        POPCapabilityAuthCRAMMD5,
        POPCapabilityAuthDigestMD5,
        POPCapabilityAuthExternal,
        POPCapabilityAuthGSSAPI,
        POPCapabilityAuthKerberosV4,
        POPCapabilityAuthLogin,
        POPCapabilityAuthNTLM,
        POPCapabilityAuthOTP,
        POPCapabilityAuthPlain,
        POPCapabilityAuthSKey,
        POPCapabilityAuthSRP,
    }POPCapability;
    
    typedef enum {
        Encoding7Bit = 0,            // should match MAILIMAP_BODY_FLD_ENC_7BIT
        Encoding8Bit = 1,            // should match MAILIMAP_BODY_FLD_ENC_8BIT
        EncodingBinary = 2,          // should match MAILIMAP_BODY_FLD_ENC_BINARY
        EncodingBase64 = 3,          // should match MAILIMAP_BODY_FLD_ENC_BASE64
        EncodingQuotedPrintable = 4, // should match MAILIMAP_BODY_FLD_ENC_QUOTED_PRINTABLE
        EncodingOther = 5,           // should match MAILIMAP_BODY_FLD_ENC_OTHER
        // negative values should be used for other encoding
        EncodingUUEncode = -1
    }Encoding;
    
    typedef enum {
        IMAPSearchKindAll,
        IMAPSearchKindNone,
        IMAPSearchKindFrom,
        IMAPSearchKindTo,
        IMAPSearchKindCc,
        IMAPSearchKindBcc,
        IMAPSearchKindRecipient,   // Recipient is the combination of To, Cc and Bcc
        IMAPSearchKindSubject,
        IMAPSearchKindContent,
        IMAPSearchKindBody,
        IMAPSearchKindUIDs,
        IMAPSearchKindNumbers,
        IMAPSearchKindHeader,
        IMAPSearchKindRead,
        IMAPSearchKindUnread,
        IMAPSearchKindFlagged,
        IMAPSearchKindUnflagged,
        IMAPSearchKindAnswered,
        IMAPSearchKindUnanswered,
        IMAPSearchKindDraft,
        IMAPSearchKindUndraft,
        IMAPSearchKindDeleted,
        IMAPSearchKindSpam,
        IMAPSearchKindBeforeDate,
        IMAPSearchKindOnDate,
        IMAPSearchKindSinceDate,
        IMAPSearchKindBeforeReceivedDate,
        IMAPSearchKindOnReceivedDate,
        IMAPSearchKindSinceReceivedDate,
        IMAPSearchKindSizeLarger,
        IMAPSearchKindSizeSmaller,
        IMAPSearchKindGmailThreadID,
        IMAPSearchKindGmailMessageID,
        IMAPSearchKindGmailRaw,
        IMAPSearchKindOr,
        IMAPSearchKindAnd,
        IMAPSearchKindNot,
    }IMAPSearchKind;
    
    typedef enum {
        ErrorNone, // 0
        ErrorConnection,
        ErrorTLSNotAvailable,
        ErrorParse,
        ErrorCertificate,
        ErrorAuthentication,
        ErrorGmailIMAPNotEnabled,
        ErrorGmailExceededBandwidthLimit,
        ErrorGmailTooManySimultaneousConnections,
        ErrorMobileMeMoved,
        ErrorYahooUnavailable, // 10
        ErrorNonExistantFolder,
        ErrorRename,
        ErrorDelete,
        ErrorCreate,
        ErrorSubscribe,
        ErrorAppend,
        ErrorCopy,
        ErrorExpunge,
        ErrorFetch,
        ErrorIdle, // 20
        ErrorIdentity,
        ErrorNamespace,
        ErrorStore,
        ErrorCapability,
        ErrorStartTLSNotAvailable,
        ErrorSendMessageIllegalAttachment,
        ErrorStorageLimit,
        ErrorSendMessageNotAllowed,
        ErrorNeedsConnectToWebmail,
        ErrorSendMessage, // 30
        ErrorAuthenticationRequired,
        ErrorFetchMessageList,
        ErrorDeleteMessage,
        ErrorInvalidAccount,
        ErrorFile,
        ErrorCompression,
        ErrorNoSender,
        ErrorNoRecipient,
        ErrorNoop,
        ErrorGmailApplicationSpecificPasswordRequired, // 40
        ErrorServerDate,
        ErrorNoValidServerFound,
        ErrorCustomCommand,
        ErrorYahooSendMessageSpamSuspected,
        ErrorYahooSendMessageDailyLimitExceeded,
        ErrorOutlookLoginViaWebBrowser,
        ErrorTiscaliSimplePassword,
        ErrorCanceled,
        ErrorIMAPTooManySimultaneousConnections,
    }ErrorCode;
    
    typedef enum {
        PartTypeSingle,
        PartTypeMessage,
        PartTypeMultipartMixed,
        PartTypeMultipartRelated,
        PartTypeMultipartAlternative,
        PartTypeMultipartSigned,
    }PartType;
    
    typedef enum ConnectionLogType {
        // Received data
        ConnectionLogTypeReceived,
        // Sent data
        ConnectionLogTypeSent,
        // Sent private data
        ConnectionLogTypeSentPrivate,
        // Parse error
        ConnectionLogTypeErrorParse,
        // Error while receiving data - log() is called with a NULL buffer.
        ConnectionLogTypeErrorReceived,
        // Error while sending data - log() is called with a NULL buffer.
        ConnectionLogTypeErrorSent,
    } ConnectionLogType;
    
    /**
     It's called when asynchronous operations stop/start running.
     */
    typedef void (*OperationQueueRunningChangeBlock)(void);
    
    /**
     It's a network traffic logger.
     @param sender is the identifier of the underlaying network socket.
     @param logType is the type of the log.
     @param data is the data related to the log.
     */
    typedef void (*CConnectionLogger)(void* sender, ConnectionLogType logType, CData data, void* logger);
    typedef void (*CConnectionLoggerRelease)(void* logger);
    
#ifdef __cplusplus
}
#endif

#endif
