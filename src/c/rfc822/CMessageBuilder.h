#ifndef CMessageBuilder_h
#define CMessageBuilder_h

#include "CBase.h"
#include "CMessageConstants.h"
#include "CAbstractPart.h"
#include "CAbstractMessage.h"
#include "CArray.h"
#include "CAttachment.h"

#include "MailCoreString.h"

#ifdef __cplusplus

namespace mailcore {
    class MessageBuilder;
}

extern "C" {
#endif
    
    C_SYNTHESIZE_STRUCT_DEFINITION(CMessageBuilder, mailcore::MessageBuilder)
    C_SYNTHESIZE_COBJECT_CAST_DEFINITION(CMessageBuilder)
    
    C_SYNTHESIZE_PROPERTY_DEFINITION(CMessageBuilder, MailCoreString, htmlBody, setHTMLBody)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CMessageBuilder, MailCoreString, textBody, setTextBody)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CMessageBuilder, CArray, attachments, setAttachments)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CMessageBuilder, CArray, relatedAttachments, setRelatedAttachments)
    C_SYNTHESIZE_PROPERTY_DEFINITION(CMessageBuilder, MailCoreString, boundaryPrefix, setBoundaryPrefix)
    
    C_SYNTHESIZE_FUNC_DEFINITION(CMessageBuilder, void, addAttachment, CAttachment)
    C_SYNTHESIZE_FUNC_DEFINITION(CMessageBuilder, void, addRelatedAttachment, CAttachment)
    
    C_SYNTHESIZE_FUNC_DEFINITION(CMessageBuilder, CData, data)
    C_SYNTHESIZE_FUNC_DEFINITION(CMessageBuilder, CData, dataForEncryption)
    
    C_SYNTHESIZE_FUNC_DEFINITION(CMessageBuilder, ErrorCode, writeToFile, MailCoreString, bool)
    
    C_SYNTHESIZE_FUNC_DEFINITION(CMessageBuilder, CData, openPGPSignedMessageDataWithSignatureData, CData)
    C_SYNTHESIZE_FUNC_DEFINITION(CMessageBuilder, CData, openPGPEncryptedMessageDataWithEncryptedData, CData)
    
    C_SYNTHESIZE_FUNC_DEFINITION(CMessageBuilder, MailCoreString, htmlBodyRendering)
    C_SYNTHESIZE_FUNC_DEFINITION(CMessageBuilder, MailCoreString, plainTextRendering)
    
    C_SYNTHESIZE_FUNC_DEFINITION(CMessageBuilder, MailCoreString, plainTextBodyRenderingAndStripWhitespace, bool)
    
    C_SYNTHESIZE_FUNC_DEFINITION(CMessageBuilder, void, setBoundaries, CArray)
    
    C_SYNTHESIZE_STATIC_FUNC_DEFINITION(CMessageBuilder, CMessageBuilder, init)
    
#ifdef __cplusplus
}
#endif

#endif /* CMessageBuilder_h */
