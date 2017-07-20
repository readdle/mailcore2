#ifndef MAILCORE_CBASE_H
#define MAILCORE_CBASE_H

#include <stdbool.h>
#include <stdint.h>
#include <MailCore/MCICUTypes.h>

#if __has_attribute(swift_name)
# define CF_SWIFT_NAME(_name) __attribute__((swift_name(#_name)))
#else
# define CF_SWIFT_NAME(_name)
#endif

#ifdef __cplusplus
extern "C" {
#endif
    
    struct CData {
        const char* bytes;
        unsigned int length;
    };
    typedef struct CData CData;
    
    CData   CData_new(const char* bytes, unsigned int length)
            CF_SWIFT_NAME(CData.init(bytes:length:));
    
#ifdef __cplusplus
}

namespace mailcore {
    class Data;
}

CData CData_new(mailcore::Data data);
#endif

#endif