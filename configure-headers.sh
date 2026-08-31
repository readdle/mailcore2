#!/bin/sh

set -ex

cd src

cp MailCore.h ./include/MailCore

cp core/MCCore.h ./include/MailCore

cp core/abstract/MCAbstract.h ./include/MailCore
cp core/abstract/MCAbstractMessage.h ./include/MailCore
cp core/abstract/MCAbstractMessagePart.h ./include/MailCore
cp core/abstract/MCAbstractMultipart.h ./include/MailCore
cp core/abstract/MCAbstractPart.h ./include/MailCore
cp core/abstract/MCAddress.h ./include/MailCore
cp core/abstract/MCMessageConstants.h ./include/MailCore
cp core/abstract/MCMessageHeader.h ./include/MailCore
cp core/abstract/MCErrorMessage.h ./include/MailCore

cp core/basetypes/MCArray.h ./include/MailCore
cp core/basetypes/MCAssert.h ./include/MailCore
cp core/basetypes/MCAutoreleasePool.h ./include/MailCore
cp core/basetypes/MCBaseTypes.h ./include/MailCore
cp core/basetypes/MCBasicLock.h ./include/MailCore
cp core/basetypes/MCConnectionLogger.h ./include/MailCore
cp core/basetypes/MCData.h ./include/MailCore
cp core/basetypes/MCDataDecoderUtils.h ./include/MailCore
cp core/basetypes/MCHash.h ./include/MailCore
cp core/basetypes/MCHashMap.h ./include/MailCore
cp core/basetypes/MCHTMLCleaner.h ./include/MailCore
cp core/basetypes/MCICUTypes.h ./include/MailCore
cp core/basetypes/MCIndexSet.h ./include/MailCore
cp core/basetypes/MCIterator.h ./include/MailCore
cp core/basetypes/MCJSON.h ./include/MailCore
cp core/basetypes/MCLibetpan.h ./include/MailCore
cp core/basetypes/MCLibetpanTypes.h ./include/MailCore
cp core/basetypes/MCLog.h ./include/MailCore
cp core/basetypes/MCNull.h ./include/MailCore
cp core/basetypes/MCObject.h ./include/MailCore
cp core/basetypes/MCOperation.h ./include/MailCore
cp core/basetypes/MCOperationCallback.h ./include/MailCore
cp core/basetypes/MCOperationQueue.h ./include/MailCore
cp core/basetypes/MCRange.h ./include/MailCore
cp core/basetypes/MCSet.h ./include/MailCore
cp core/basetypes/MCString.h ./include/MailCore
cp core/basetypes/MCUtils.h ./include/MailCore
cp core/basetypes/MCValue.h ./include/MailCore
cp core/basetypes/MCDataStreamDecoder.h ./include/MailCore
cp core/basetypes/MCDefines.h ./include/MailCore
cp core/basetypes/MCMD5.h ./include/MailCore
cp core/basetypes/MCOperationQueueCallback.h ./include/MailCore
cp core/basetypes/MCBase64.h ./include/MailCore
cp core/basetypes/MCLock.h ./include/MailCore
cp core/basetypes/MCMainThread.h ./include/MailCore
cp core/basetypes/MCWin32.h ./include/MailCore

cp core/imap/MCIMAP.h ./include/MailCore
cp core/imap/MCIMAPFolder.h ./include/MailCore
cp core/imap/MCIMAPFolderStatus.h ./include/MailCore
cp core/imap/MCIMAPIdentity.h ./include/MailCore
cp core/imap/MCIMAPMessage.h ./include/MailCore
cp core/imap/MCIMAPMessagePart.h ./include/MailCore
cp core/imap/MCIMAPMultipart.h ./include/MailCore
cp core/imap/MCIMAPNamespace.h ./include/MailCore
cp core/imap/MCIMAPNamespaceItem.h ./include/MailCore
cp core/imap/MCIMAPPart.h ./include/MailCore
cp core/imap/MCIMAPProgressCallback.h ./include/MailCore
cp core/imap/MCIMAPSearchExpression.h ./include/MailCore
cp core/imap/MCIMAPSession.h ./include/MailCore
cp core/imap/MCIMAPSyncResult.h ./include/MailCore

cp core/nntp/MCNNTP.h ./include/MailCore
cp core/nntp/MCNNTPGroupInfo.h ./include/MailCore
cp core/nntp/MCNNTPProgressCallback.h ./include/MailCore
cp core/nntp/MCNNTPSession.h ./include/MailCore

cp core/pop/MCPOP.h ./include/MailCore
cp core/pop/MCPOPMessageInfo.h ./include/MailCore
cp core/pop/MCPOPProgressCallback.h ./include/MailCore
cp core/pop/MCPOPSession.h ./include/MailCore

cp core/provider/MCAccountValidator.h ./include/MailCore
cp core/provider/MCMailProvider.h ./include/MailCore
cp core/provider/MCMailProvidersManager.h ./include/MailCore
cp core/provider/MCNetService.h ./include/MailCore
cp core/provider/MCProvider.h ./include/MailCore
cp core/provider/MCMXRecordResolverOperation.h ./include/MailCore

cp core/renderer/MCAddressDisplay.h ./include/MailCore
cp core/renderer/MCDateFormatter.h ./include/MailCore
cp core/renderer/MCHTMLBodyRendererTemplateCallback.h ./include/MailCore
cp core/renderer/MCHTMLRenderer.h ./include/MailCore
cp core/renderer/MCHTMLRendererCallback.h ./include/MailCore
cp core/renderer/MCRenderer.h ./include/MailCore
cp core/renderer/MCHTMLRendererIMAPDataCallback.h ./include/MailCore
cp core/renderer/MCSizeFormatter.h ./include/MailCore

cp core/rfc822/MCAttachment.h ./include/MailCore
cp core/rfc822/MCMessageBuilder.h ./include/MailCore
cp core/rfc822/MCMessageParser.h ./include/MailCore
cp core/rfc822/MCMessagePart.h ./include/MailCore
cp core/rfc822/MCMultipart.h ./include/MailCore
cp core/rfc822/MCRFC822.h ./include/MailCore

cp core/smtp/MCSMTP.h ./include/MailCore
cp core/smtp/MCSMTPProgressCallback.h ./include/MailCore
cp core/smtp/MCSMTPSession.h ./include/MailCore

cp core/zip/MCZip.h ./include/MailCore

cp async/MCAsync.h ./include/MailCore

cp async/imap/MCAsyncIMAP.h ./include/MailCore
cp async/imap/MCIMAPAppendMessageOperation.h ./include/MailCore
cp async/imap/MCIMAPAsyncSession.h ./include/MailCore
cp async/imap/MCIMAPCapabilityOperation.h ./include/MailCore
cp async/imap/MCIMAPCheckAccountOperation.h ./include/MailCore
cp async/imap/MCIMAPCopyMessagesOperation.h ./include/MailCore
cp async/imap/MCIMAPCustomCommandOperation.h ./include/MailCore
cp async/imap/MCIMAPFetchContentOperation.h ./include/MailCore
cp async/imap/MCIMAPFetchContentToFileOperation.h ./include/MailCore
cp async/imap/MCIMAPFetchFoldersOperation.h ./include/MailCore
cp async/imap/MCIMAPFetchMessagesOperation.h ./include/MailCore
cp async/imap/MCIMAPFetchNamespaceOperation.h ./include/MailCore
cp async/imap/MCIMAPFetchParsedContentOperation.h ./include/MailCore
cp async/imap/MCIMAPFolderInfo.h ./include/MailCore
cp async/imap/MCIMAPFolderInfoOperation.h ./include/MailCore
cp async/imap/MCIMAPFolderStatusOperation.h ./include/MailCore
cp async/imap/MCIMAPIdentityOperation.h ./include/MailCore
cp async/imap/MCIMAPIdleOperation.h ./include/MailCore
cp async/imap/MCIMAPMessageRenderingOperation.h ./include/MailCore
cp async/imap/MCIMAPMoveMessagesOperation.h ./include/MailCore
cp async/imap/MCIMAPOperation.h ./include/MailCore
cp async/imap/MCIMAPOperationCallback.h ./include/MailCore
cp async/imap/MCIMAPQuotaOperation.h ./include/MailCore
cp async/imap/MCIMAPSearchOperation.h ./include/MailCore
cp async/imap/MCIMAPAsyncConnection.h ./include/MailCore
cp async/imap/MCIMAPConnectOperation.h ./include/MailCore
cp async/imap/MCIMAPCreateFolderOperation.h ./include/MailCore
cp async/imap/MCIMAPDeleteFolderOperation.h ./include/MailCore
cp async/imap/MCIMAPDisconnectOperation.h ./include/MailCore
cp async/imap/MCIMAPExpungeOperation.h ./include/MailCore
cp async/imap/MCIMAPMultiDisconnectOperation.h ./include/MailCore
cp async/imap/MCIMAPNoopOperation.h ./include/MailCore
cp async/imap/MCIMAPRenameFolderOperation.h ./include/MailCore
cp async/imap/MCIMAPStoreFlagsOperation.h ./include/MailCore
cp async/imap/MCIMAPStoreLabelsOperation.h ./include/MailCore
cp async/imap/MCIMAPSubscribeFolderOperation.h ./include/MailCore

cp async/nntp/MCAsyncNNTP.h ./include/MailCore
cp async/nntp/MCNNTPAsyncSession.h ./include/MailCore
cp async/nntp/MCNNTPFetchAllArticlesOperation.h ./include/MailCore
cp async/nntp/MCNNTPFetchArticleOperation.h ./include/MailCore
cp async/nntp/MCNNTPFetchHeaderOperation.h ./include/MailCore
cp async/nntp/MCNNTPFetchOverviewOperation.h ./include/MailCore
cp async/nntp/MCNNTPFetchServerTimeOperation.h ./include/MailCore
cp async/nntp/MCNNTPListNewsgroupsOperation.h ./include/MailCore
cp async/nntp/MCNNTPOperation.h ./include/MailCore
cp async/nntp/MCNNTPOperationCallback.h ./include/MailCore
cp async/nntp/MCNNTPPostOperation.h ./include/MailCore
cp async/nntp/MCNNTPCheckAccountOperation.h ./include/MailCore
cp async/nntp/MCNNTPDisconnectOperation.h ./include/MailCore

cp async/pop/MCAsyncPOP.h ./include/MailCore
cp async/pop/MCPOPAsyncSession.h ./include/MailCore
cp async/pop/MCPOPFetchHeaderOperation.h ./include/MailCore
cp async/pop/MCPOPFetchMessageOperation.h ./include/MailCore
cp async/pop/MCPOPFetchMessagesOperation.h ./include/MailCore
cp async/pop/MCPOPOperation.h ./include/MailCore
cp async/pop/MCPOPOperationCallback.h ./include/MailCore
cp async/pop/MCPOPCheckAccountOperation.h ./include/MailCore
cp async/pop/MCPOPDeleteMessagesOperation.h ./include/MailCore
cp async/pop/MCPOPNoopOperation.h ./include/MailCore

cp async/smtp/MCAsyncSMTP.h ./include/MailCore
cp async/smtp/MCSMTPAsyncSession.h ./include/MailCore
cp async/smtp/MCSMTPOperation.h ./include/MailCore
cp async/smtp/MCSMTPOperationCallback.h ./include/MailCore
cp async/smtp/MCSMTPCheckAccountOperation.h ./include/MailCore
cp async/smtp/MCSMTPDisconnectOperation.h ./include/MailCore
cp async/smtp/MCSMTPLoginOperation.h ./include/MailCore
cp async/smtp/MCSMTPNoopOperation.h ./include/MailCore
cp async/smtp/MCSMTPSendWithDataOperation.h ./include/MailCore

cp c/CBase.h ./include/MailCore
cp c/CCore.h ./include/MailCore
cp c/CMailCore.h ./include/MailCore

cp c/abstract/CAbstractMessage.h ./include/MailCore
cp c/abstract/CAbstractMessagePart.h ./include/MailCore
cp c/abstract/CAbstractMessageRendererCallback.h ./include/MailCore
cp c/abstract/CAbstractMessageRendererCallbackWrapper.h ./include/MailCore
cp c/abstract/CAbstractMultipart.h ./include/MailCore
cp c/abstract/CAbstractPart.h ./include/MailCore
cp c/abstract/CAddress.h ./include/MailCore
cp c/abstract/CMessageConstants.h ./include/MailCore
cp c/abstract/CMessageHeader.h ./include/MailCore

cp c/basetypes/CArray.h ./include/MailCore
cp c/basetypes/CData.h ./include/MailCore
cp c/basetypes/CDictionary.h ./include/MailCore
cp c/basetypes/CIndexSet.h ./include/MailCore
cp c/basetypes/CObject.h ./include/MailCore
cp c/basetypes/MailCoreString.h ./include/MailCore

cp c/rfc822/CAttachment.h ./include/MailCore
cp c/rfc822/CMessageBuilder.h ./include/MailCore
cp c/rfc822/CMessageParser.h ./include/MailCore
cp c/rfc822/CMessagePart.h ./include/MailCore
cp c/rfc822/CMultipart.h ./include/MailCore

cp c/provider/CMailProvider.h ./include/MailCore
cp c/provider/CMailProvidersManager.h ./include/MailCore
cp c/provider/CNetService.h ./include/MailCore

cp c/smtp/CSMTPOperation.h ./include/MailCore
cp c/smtp/CSMTPSession.h ./include/MailCore

cp c/imap/CIMAPAppendMessageOperation.h ./include/MailCore
cp c/imap/CIMAPAsyncSession.h ./include/MailCore
cp c/imap/CIMAPAsyncConnection.h ./include/MailCore
cp c/imap/CIMAPBaseOperation.h ./include/MailCore
cp c/imap/CIMAPCapabilityOperation.h ./include/MailCore
cp c/imap/CIMAPCheckAccountOperation.h ./include/MailCore
cp c/imap/CIMAPCopyMessagesOperation.h ./include/MailCore
cp c/imap/CIMAPCustomCommandOperation.h ./include/MailCore
cp c/imap/CIMAPFetchContentOperation.h ./include/MailCore
cp c/imap/CIMAPFetchContentToFileOperation.h ./include/MailCore
cp c/imap/CIMAPFetchFoldersOperation.h ./include/MailCore
cp c/imap/CIMAPFetchMessagesOperation.h ./include/MailCore
cp c/imap/CIMAPFetchNamespaceOperation.h ./include/MailCore
cp c/imap/CIMAPFetchParsedContentOperation.h ./include/MailCore
cp c/imap/CIMAPFolder.h ./include/MailCore
cp c/imap/CIMAPFolderInfo.h ./include/MailCore
cp c/imap/CIMAPFolderInfoOperation.h ./include/MailCore
cp c/imap/CIMAPFolderStatus.h ./include/MailCore
cp c/imap/CIMAPFolderStatusOperation.h ./include/MailCore
cp c/imap/CIMAPIdentity.h ./include/MailCore
cp c/imap/CIMAPIdentityOperation.h ./include/MailCore
cp c/imap/CIMAPIdleOperation.h ./include/MailCore
cp c/imap/CIMAPMessage.h ./include/MailCore
cp c/imap/CIMAPMessagePart.h ./include/MailCore
cp c/imap/CIMAPMessageRenderingOperation.h ./include/MailCore
cp c/imap/CIMAPMoveMessagesOperation.h ./include/MailCore
cp c/imap/CIMAPMultipart.h ./include/MailCore
cp c/imap/CIMAPNamespace.h ./include/MailCore
cp c/imap/CIMAPNamespaceItem.h ./include/MailCore
cp c/imap/CIMAPPart.h ./include/MailCore
cp c/imap/CIMAPQuotaOperation.h ./include/MailCore
cp c/imap/CIMAPSearchExpression.h ./include/MailCore
cp c/imap/CIMAPSearchOperation.h ./include/MailCore

cp c/utils/COperation.h ./include/MailCore
cp c/utils/CAutoreleasePool.h ./include/MailCore
