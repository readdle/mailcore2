//
//  CCertificateUtils.h
//  mailcore2
//
//  C entry point to mailcore::checkCertificateChain(), so the certificate verification every
//  session performs after the TLS handshake can be exercised from Swift unit tests (COR-170).
//

#ifndef MAILCORE_C_CERTIFICATEUTILS_H
#define MAILCORE_C_CERTIFICATEUTILS_H

#include "CBase.h"
#include "CArray.h"
#include "MailCoreString.h"

#ifdef __cplusplus
extern "C" {
#endif
    
    /// Verifies a DER-encoded certificate chain (leaf first, CArray of CData) for `hostname`:
    /// the chain must lead to a trusted root and the leaf must be issued for `hostname`, which
    /// may be a DNS name or an IPv4/IPv6 literal.
    ///
    /// `derTrustAnchors` (CArray of CData): when its instance is non-NULL these roots are
    /// trusted *instead of* the system store. `verifyTime`: Unix time to evaluate validity at,
    /// 0 means now.
    CMAILCORE_EXPORT bool CCertificateUtils_checkCertificateChain(CArray derCertificates,
                                                                 MailCoreString hostname,
                                                                 CArray derTrustAnchors,
                                                                 int64_t verifyTime);
    
#ifdef __cplusplus
}
#endif

#endif /* MAILCORE_C_CERTIFICATEUTILS_H */
