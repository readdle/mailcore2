//
//  MCCertificateUtils.h
//  mailcore2
//
//  Created by DINH Viêt Hoà on 7/25/13.
//  Copyright (c) 2013 MailCore. All rights reserved.
//

#ifndef MAILCORE_MCCERTIFICATEUTILS_H

#define MAILCORE_MCCERTIFICATEUTILS_H

#include <time.h>
#include <libetpan/libetpan.h>
#include <MailCore/MCString.h>

#ifdef __cplusplus

namespace mailcore {
    
    bool checkCertificate(mailstream * stream, String * hostname);
    
    // The verification behind checkCertificate(), on a DER chain (carray of MMAPString,
    // leaf first) instead of a stream. `cTrustAnchors` (same layout) are trusted in
    // addition to the system store and `verifyTime` (Unix time, 0 = now) pins the
    // validity check; both exist for unit tests, production passes NULL and 0 (COR-170).
    bool checkCertificateChain(carray * cCerts, String * hostname, carray * cTrustAnchors, time_t verifyTime);
    
}

#endif

#endif
