#include <MailCore/MCAsync.h>
#include <MailCore/MCIMAPAsyncConnection.h>

#include "CIMAPAsyncConnection.h"

#include "CBase+Private.h"

#define nativeType mailcore::IMAPAsyncConnection
#define structName CIMAPAsyncConnection

C_SYNTHESIZE_CONSTRUCTOR()

C_SYNTHESIZE_FUNC_WITH_SCALAR(bool, isReserved)
C_SYNTHESIZE_FUNC_WITH_SCALAR(unsigned int, operationsCount)
