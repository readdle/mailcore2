#ifndef MAILCORE_CIMAP_ASYNC_CONNECTION_H
#define MAILCORE_CIMAP_ASYNC_CONNECTION_H

#include <stdbool.h>

#include "CBase.h"

#ifdef __cplusplus

namespace mailcore {
    class IMAPAsyncConnection;
}

extern "C" {
#endif

    C_SYNTHESIZE_STRUCT_DEFINITION(CIMAPAsyncConnection, mailcore::IMAPAsyncConnection)

    C_SYNTHESIZE_READONLY_PROPERTY_DEFINITION(CIMAPAsyncConnection, bool, isReserved)
    C_SYNTHESIZE_READONLY_PROPERTY_DEFINITION(CIMAPAsyncConnection, unsigned int, operationsCount)

#ifdef __cplusplus
}
#endif

#endif
