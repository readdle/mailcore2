#ifndef MAILCORE_COBJECT_H
#define MAILCORE_COBJECT_H

#include "stdint.h"
#include "CBase.h"
#include <dispatch/dispatch.h>

#ifdef __cplusplus

namespace  mailcore {
    class Object;
}

extern "C" {
#endif
    
    C_SYNTHESIZE_STRUCT_DEFINITION(CObject, mailcore::Object)
    C_SYNTHESIZE_FUNC_DEFINITION(CObject, uint32_t, castToUInt32);

    #ifdef __ANDROID__
    C_SYNTHESIZE_STATIC_FUNC_DEFINITION(CObject, void, setMainQueue, dispatch_queue_t);
    #endif
    typedef void (*MCLogger)(const char * filename, unsigned int line, const char * message);
    C_SYNTHESIZE_STATIC_FUNC_DEFINITION(CObject, void, setMCAssertHandler, MCLogger);
    C_SYNTHESIZE_STATIC_FUNC_DEFINITION(CObject, void, setLogger, MCLogger);
    C_SYNTHESIZE_STATIC_FUNC_DEFINITION(CObject, void, setLoggerEnabled, bool);
    C_SYNTHESIZE_STATIC_FUNC_DEFINITION(CObject, void, setLoggerVerboseEnabled, bool);
    
    CMAILCORE_EXPORT CObject CObject_new_WithUInt32(uint32_t string)
    CF_SWIFT_NAME(CObject.init(uint32:));
    
#ifdef __cplusplus
}
#endif

#endif
