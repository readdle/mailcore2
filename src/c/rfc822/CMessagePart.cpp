#include "CMessagePart.h"
#include "CBase+Private.h"
#include <MailCore/MCCore.h>

#define nativeType mailcore::MessagePart
#define structName CMessagePart

C_SYNTHESIZE_CONSTRUCTOR()
C_SYNTHESIZE_COBJECT_CAST()
C_SYNTHESIZE_STRING(setPartID, partID)
