#include <MailCore/MCCore.h>
#include <MailCore/MCAssert.h>
#include "CObject.h"
#include "CBase+Private.h"
#include "CDictionary.h"

#define nativeType mailcore::Object
#define structName CObject

C_SYNTHESIZE_CONSTRUCTOR()
C_SYNTHESIZE_FUNC_WITH_OBJ(CDictionary, serializable)
C_SYNTHESIZE_STATIC_FUNC_WITH_OBJ(CObject, objectWithSerializable, CDictionary)

CObject CObject_new_WithUInt32(uint32_t value) {
    return CObject_new(mailcore::Value::valueWithUnsignedIntValue(value));
}

uint32_t CObject_castToUInt32(struct CObject self) {
    return (reinterpret_cast<mailcore::Value*>(self.instance))->unsignedIntValue();
}

#ifdef __ANDROID__
void CObject_setMainQueue(dispatch_queue_t mainQueue) {
    mailcore::mainQueue = mainQueue;
}
#endif

void CObject_setMCAssertHandler(MCLogger handler) {
    setMCAssertHandler(handler);
}

void CObject_setLogger(MCLogger logger) {
    setMCLogger(logger);
}

void CObject_setLoggerEnabled(bool enable) {
    MCLogEnabled = enable;
}

void CObject_setLoggerVerboseEnabled(bool enable) {
    MCLogVerboseEnabled = enable;
}
