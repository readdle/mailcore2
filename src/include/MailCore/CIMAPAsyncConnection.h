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

    // completed in CIMAPBaseOperation.h; including it here would be circular
    typedef struct CIMAPBaseOperation CIMAPBaseOperation;

    C_SYNTHESIZE_STRUCT_DEFINITION(CIMAPAsyncConnection, mailcore::IMAPAsyncConnection)

    C_SYNTHESIZE_READONLY_PROPERTY_DEFINITION(CIMAPAsyncConnection, bool, isReserved)
    C_SYNTHESIZE_READONLY_PROPERTY_DEFINITION(CIMAPAsyncConnection, unsigned int, operationsCount)

    C_SYNTHESIZE_FUNC_DEFINITION(CIMAPAsyncConnection, CIMAPBaseOperation, disconnectOperation)

#ifdef __cplusplus
}
#endif

#endif
