#include "CMessageBuilder.h"
#include "CBase+Private.h"

#include <MailCore/MCCore.h>
#include "CData.h"

#define nativeType mailcore::MessageBuilder
#define structName CMessageBuilder

C_SYNTHESIZE_STRING(setHTMLBody, htmlBody)
C_SYNTHESIZE_STRING(setTextBody, textBody)
C_SYNTHESIZE_ARRAY(setAttachments, attachments)
C_SYNTHESIZE_ARRAY(setRelatedAttachments, relatedAttachments)
C_SYNTHESIZE_STRING(setBoundaryPrefix, boundaryPrefix)

C_SYNTHESIZE_CONSTRUCTOR()
C_SYNTHESIZE_COBJECT_CAST()

CMessageBuilder CMessageBuilder_init() {
    return CMessageBuilder_new(new mailcore::MessageBuilder());
}

C_SYNTHESIZE_FUNC_WITH_VOID(addAttachment, CAttachment)
C_SYNTHESIZE_FUNC_WITH_VOID(addRelatedAttachment, CAttachment)

C_SYNTHESIZE_FUNC_WITH_OBJ(CData, data)
C_SYNTHESIZE_FUNC_WITH_OBJ(CData, dataForEncryption)


ErrorCode CMessageBuilder_writeToFile(struct CMessageBuilder self, MailCoreString filename, bool useXAttachmentId) {
    return static_cast<ErrorCode>((int)self.instance->writeToFile(filename.instance, useXAttachmentId));
}

C_SYNTHESIZE_FUNC_WITH_OBJ(CData, openPGPSignedMessageDataWithSignatureData, CData)
C_SYNTHESIZE_FUNC_WITH_OBJ(CData, openPGPEncryptedMessageDataWithEncryptedData, CData)
C_SYNTHESIZE_FUNC_WITH_OBJ(MailCoreString, htmlBodyRendering)
C_SYNTHESIZE_FUNC_WITH_OBJ(MailCoreString, plainTextRendering)

C_SYNTHESIZE_FUNC_WITH_VOID(setBoundaries, CArray)

MailCoreString CMessageBuilder_plainTextBodyRenderingAndStripWhitespace(struct CMessageBuilder self, bool stripWhitespace) {
    return MailCoreString_new(self.instance->plainTextBodyRendering(stripWhitespace));
}





