//
//  CCertificateUtils.cpp
//  mailcore2
//

#include "CCertificateUtils.h"
#include "CBase+Private.h"

#include <MailCore/MCCertificateUtils.h>
#include <MailCore/MCArray.h>
#include <MailCore/MCData.h>

// Converts an Array of Data into the carray of MMAPString that libetpan uses for
// certificate chains. Free with mailstream_certificate_chain_free().
static carray * certificateChainFromArray(mailcore::Array * array)
{
    if (array == NULL) {
        return NULL;
    }
    carray * result = carray_new(array->count() > 0 ? array->count() : 1);
    for(unsigned int i = 0 ; i < array->count() ; i ++) {
        mailcore::Data * der = (mailcore::Data *) array->objectAtIndex(i);
        MMAPString * str = mmap_string_new_len(der->bytes(), (size_t) der->length());
        carray_add(result, str, NULL);
    }
    return result;
}

bool CCertificateUtils_checkCertificateChain(CArray derCertificates,
                                             MailCoreString hostname,
                                             CArray derTrustAnchors,
                                             int64_t verifyTime)
{
    carray * cCerts = certificateChainFromArray(derCertificates.instance);
    carray * cTrustAnchors = certificateChainFromArray(derTrustAnchors.instance);
    
    bool result = false;
    if (cCerts != NULL) {
        result = mailcore::checkCertificateChain(cCerts, hostname.instance, cTrustAnchors, (time_t) verifyTime);
    }
    
    if (cCerts != NULL) {
        mailstream_certificate_chain_free(cCerts);
    }
    if (cTrustAnchors != NULL) {
        mailstream_certificate_chain_free(cTrustAnchors);
    }
    return result;
}
