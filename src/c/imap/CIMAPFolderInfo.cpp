#include "CIMAPFolderInfo.h"
#include "CBase+Private.h"

#include <MailCore/MCAsync.h>

#define nativeType mailcore::IMAPFolderInfo
#define structName CIMAPFolderInfo

C_SYNTHESIZE_SCALAR(uint32_t, uint32_t, setUidNext, uidNext)
C_SYNTHESIZE_SCALAR(uint32_t, uint32_t, setUidValidity, uidValidity)
C_SYNTHESIZE_SCALAR(uint64_t, uint64_t, setModSequenceValue, modSequenceValue)
C_SYNTHESIZE_SCALAR(int, int, setMessageCount, messageCount)
C_SYNTHESIZE_SCALAR(uint32_t, uint32_t, setFirstUnseenUid, firstUnseenUid)
C_SYNTHESIZE_BOOL(setAllowsNewPermanentFlags, allowsNewPermanentFlags);

CIMAPFolderInfo CIMAPFolderInfo_new(mailcore::IMAPFolderInfo *info) {
    CIMAPFolderInfo self;
    self.instance = info;
    self.instance->retain();
    return self;
}

void CIMAPFolderInfo_release(CIMAPFolderInfo self) {
    C_SAFE_RELEASE(self.instance);
}

