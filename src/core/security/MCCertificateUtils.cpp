//
//  MCCertificateUtils.cc
//  mailcore2
//
//  Created by DINH Viêt Hoà on 7/25/13.
//  Copyright (c) 2013 MailCore. All rights reserved.
//

#include "MCWin32.h" // should be first include.

#include "MCCertificateUtils.h"

#if __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#else
#include <openssl/bio.h>
#include <openssl/x509.h>
#include <openssl/x509_vfy.h>
#include <openssl/x509v3.h>
#include <openssl/pem.h>
#include <openssl/err.h>
#endif

#if defined(ANDROID) || defined(__ANDROID__)
#include <dirent.h>
#endif

#include "MCLock.h"
#include "MCLog.h"

#if __APPLE__
#else
char* X509_to_string(X509* cert) {
    BIO* bio = BIO_new(BIO_s_mem());
    if (!bio) {
        // Handle error
        return NULL;
    }

    if (!X509_print(bio, cert)) {
        // Handle error
        BIO_free(bio);
        return NULL;
    }

    // Determine the length of the data.
    char* output;
    long len = BIO_get_mem_data(bio, &output);

    // Allocate memory for the string
    char* str = (char*)malloc(len + 1);
    if (str) {
        // Copy the data
        memcpy(str, output, len);
        // Null-terminate the string
        str[len] = '\0';
    }

    // Cleanup
    BIO_free(bio);

    return str;
}
#endif

bool mailcore::checkCertificate(mailstream * stream, String * hostname)
{
    carray * cCerts = mailstream_get_certificate_chain(stream);
    if (cCerts == NULL) {
        fprintf(stderr, "warning: No certificate chain retrieved");
        return false;
    }
    bool result = checkCertificateChain(cCerts, hostname, NULL, 0);
    mailstream_certificate_chain_free(cCerts);
    return result;
}

bool mailcore::checkCertificateChain(carray * cCerts, String * hostname, carray * cTrustAnchors, time_t verifyTime)
{
    if (hostname == NULL || hostname->length() == 0) {
        MCLog("MCCertificateUtils error: no hostname to verify the certificate against");
        return false;
    }
    
#if __APPLE__
    bool result = false;
    CFStringRef hostnameCFString;
    SecPolicyRef policy;
    CFMutableArrayRef certificates;
    SecTrustRef trust = NULL;
    SecTrustResultType trustResult;
    OSStatus status;
    
    hostnameCFString = CFStringCreateWithCharacters(NULL, (const UniChar *) hostname->unicodeCharacters(),
                                                                hostname->length());
    policy = SecPolicyCreateSSL(true, hostnameCFString);
    certificates = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    
    for(unsigned int i = 0 ; i < carray_count(cCerts) ; i ++) {
        MMAPString * str;
        str = (MMAPString *) carray_get(cCerts, i);
        CFDataRef data = CFDataCreate(NULL, (const UInt8 *) str->str, (CFIndex) str->len);
        SecCertificateRef cert = SecCertificateCreateWithData(NULL, data);
        if (cert == NULL) {
            MCLog("MCCertificateUtils error: certificate %u is not a valid DER certificate", i);
            CFRelease(data);
            goto free_certs;
        }
        CFArrayAppendValue(certificates, cert);
        CFRelease(data);
        CFRelease(cert);
    }
    
    static MC_LOCK_TYPE lock = MC_LOCK_INITIAL_VALUE;
    
    // The below API calls are not thread safe. We're making sure not to call the concurrently.
    MC_LOCK(&lock);
    
    status = SecTrustCreateWithCertificates(certificates, policy, &trust);
    if (status != noErr) {
        MC_UNLOCK(&lock);
        goto free_certs;
    }
    
    if (cTrustAnchors != NULL) {
        // Tests: trust these roots in addition to the system store.
        CFMutableArrayRef anchors = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
        for(unsigned int i = 0 ; i < carray_count(cTrustAnchors) ; i ++) {
            MMAPString * str = (MMAPString *) carray_get(cTrustAnchors, i);
            CFDataRef data = CFDataCreate(NULL, (const UInt8 *) str->str, (CFIndex) str->len);
            SecCertificateRef anchor = SecCertificateCreateWithData(NULL, data);
            if (anchor != NULL) {
                CFArrayAppendValue(anchors, anchor);
                CFRelease(anchor);
            }
            CFRelease(data);
        }
        SecTrustSetAnchorCertificates(trust, anchors);
        SecTrustSetAnchorCertificatesOnly(trust, false);
        CFRelease(anchors);
    }
    if (verifyTime != 0) {
        // Tests: evaluate validity at a fixed point in time.
        CFDateRef verifyDate = CFDateCreate(NULL, (CFAbsoluteTime) verifyTime - kCFAbsoluteTimeIntervalSince1970);
        SecTrustSetVerifyDate(trust, verifyDate);
        CFRelease(verifyDate);
    }
    
    status = SecTrustEvaluate(trust, &trustResult);
    if (status != noErr) {
        MC_UNLOCK(&lock);
        goto free_certs;
    }
    
    MC_UNLOCK(&lock);
    
    switch (trustResult) {
        case kSecTrustResultUnspecified:
        case kSecTrustResultProceed:
            // certificate chain is ok
            result = true;
            break;
            
        default:
            // certificate chain is invalid
            break;
    }
    
    CFRelease(trust);
free_certs:
    CFRelease(certificates);
    CFRelease(policy);
    CFRelease(hostnameCFString);
    return result;
#elif defined(_MSC_VER)
    // COR-316: verify with the Windows chain engine, as SecTrust does on Apple platforms. Only the
    // chain engine fetches a trusted root Windows has not downloaded yet (automatic root update).
    bool result = false;
    HCERTSTORE store = NULL;
    PCCERT_CONTEXT leaf = NULL;
    PCCERT_CHAIN_CONTEXT chain = NULL;

    if (carray_count(cCerts) == 0) {
        MCLog("MCCertificateUtils error: no certificate to verify");
        return false;
    }
    store = CertOpenStore(CERT_STORE_PROV_MEMORY, 0, 0, 0, NULL);
    if (store == NULL) {
        MCLog("MCCertificateUtils error: can't create a certificate store");
        return false;
    }

    for(unsigned int i = 0 ; i < carray_count(cCerts) ; i ++) {
        MMAPString * str = (MMAPString *) carray_get(cCerts, i);
        if (!CertAddEncodedCertificateToStore(store, X509_ASN_ENCODING, (const BYTE *) str->str, (DWORD) str->len,
                                              CERT_STORE_ADD_USE_EXISTING, i == 0 ? &leaf : NULL)) {
            MCLog("MCCertificateUtils error: certificate %u is not a valid DER certificate", i);
            goto free_certs;
        }
    }

    if (cTrustAnchors != NULL) {
        // Tests: trust these roots in addition to the system store. The server may have sent them too.
        for(unsigned int i = 0 ; i < carray_count(cTrustAnchors) ; i ++) {
            MMAPString * str = (MMAPString *) carray_get(cTrustAnchors, i);
            CertAddEncodedCertificateToStore(store, X509_ASN_ENCODING, (const BYTE *) str->str, (DWORD) str->len,
                                             CERT_STORE_ADD_USE_EXISTING, NULL);
        }
    }

    {
        LPSTR serverAuth = (LPSTR) szOID_PKIX_KP_SERVER_AUTH;
        CERT_CHAIN_PARA chainPara = {};
        chainPara.cbSize = sizeof(chainPara);
        chainPara.RequestedUsage.dwType = USAGE_MATCH_TYPE_AND;
        chainPara.RequestedUsage.Usage.cUsageIdentifier = 1;
        chainPara.RequestedUsage.Usage.rgpszUsageIdentifier = &serverAuth;
        FILETIME fileTime;
        if (verifyTime != 0) {
            // Tests: evaluate validity at a fixed point in time. FILETIME counts 100 ns since 1601.
            ULONGLONG ticks = ((ULONGLONG) verifyTime + 11644473600ULL) * 10000000ULL;
            fileTime.dwLowDateTime = (DWORD) ticks;
            fileTime.dwHighDateTime = (DWORD) (ticks >> 32);
        }
        if (!CertGetCertificateChain(NULL, leaf, verifyTime != 0 ? &fileTime : NULL, store, &chainPara, 0, NULL, &chain)) {
            MCLog("MCCertificateUtils error: CertGetCertificateChain failed 0x%08lx", GetLastError());
            goto free_certs;
        }
    }

    {
        SSL_EXTRA_CERT_CHAIN_POLICY_PARA sslPara = {};
        sslPara.cbSize = sizeof(sslPara);
        sslPara.dwAuthType = AUTHTYPE_SERVER;
        sslPara.pwszServerName = (WCHAR *) hostname->unicodeCharacters();
        CERT_CHAIN_POLICY_PARA policyPara = {};
        policyPara.cbSize = sizeof(policyPara);
        policyPara.pvExtraPolicyPara = &sslPara;
        if (cTrustAnchors != NULL) {
            // Tests: no system store holds the anchors, so a chain ending in one has an unknown CA.
            PCERT_SIMPLE_CHAIN simpleChain = chain->rgpChain[chain->cChain - 1];
            PCCERT_CONTEXT root = simpleChain->rgpElement[simpleChain->cElement - 1]->pCertContext;
            for(unsigned int i = 0 ; i < carray_count(cTrustAnchors) ; i ++) {
                MMAPString * str = (MMAPString *) carray_get(cTrustAnchors, i);
                if (str->len == root->cbCertEncoded && memcmp(str->str, root->pbCertEncoded, str->len) == 0) {
                    policyPara.dwFlags = CERT_CHAIN_POLICY_ALLOW_UNKNOWN_CA_FLAG;
                }
            }
        }
        CERT_CHAIN_POLICY_STATUS policyStatus = {};
        policyStatus.cbSize = sizeof(policyStatus);
        if (!CertVerifyCertificateChainPolicy(CERT_CHAIN_POLICY_SSL, chain, &policyPara, &policyStatus)) {
            MCLog("MCCertificateUtils error: CertVerifyCertificateChainPolicy failed 0x%08lx", GetLastError());
        }
        else if (policyStatus.dwError == 0) {
            result = true;
        }
        else {
            MCLog("MCCertificateUtils error: certificate policy error 0x%08lx (chain status 0x%08lx)",
                  policyStatus.dwError, chain->TrustStatus.dwErrorStatus);
        }
    }

free_certs:
    if (chain != NULL) {
        CertFreeCertificateChain(chain);
    }
    if (leaf != NULL) {
        CertFreeCertificateContext(leaf);
    }
    CertCloseStore(store, 0);
    return result;
#else
    bool result = false;
    X509_STORE * store = NULL;
    X509_STORE_CTX * storectx = NULL;
    STACK_OF(X509) * certificates = NULL;
#if defined(ANDROID) || defined(__ANDROID__)
    DIR * dir = NULL;
    struct dirent * ent = NULL;
    FILE * f = NULL;
#endif
    int status;
    
    store = X509_STORE_new();
    if (store == NULL) {
        goto free_certs;
    }
    
#if defined(ANDROID) || defined(__ANDROID__)
    dir = opendir("/system/etc/security/cacerts");
    while ((ent = readdir(dir))) {
        if (ent->d_name[0] == '.') {
            continue;
        }
        char filename[1024];
        snprintf(filename, sizeof(filename), "/system/etc/security/cacerts/%s", ent->d_name);
        f = fopen(filename, "rb");
        if (f != NULL) {
            X509 * cert = PEM_read_X509(f, NULL, NULL, NULL);
            if (cert != NULL) {
                X509_STORE_add_cert(store, cert);
                X509_free(cert);
            }
            fclose(f);
        }
    }
    closedir(dir);
#endif

	status = X509_STORE_set_default_paths(store);
    if (status != 1) {
        printf("Error loading the system-wide CA certificates");
        MCLog("Error loading the system-wide CA certificates");
    }
    
    if (cTrustAnchors != NULL) {
        // Tests: trust these roots in addition to the system store.
        for(unsigned int i = 0 ; i < carray_count(cTrustAnchors) ; i ++) {
            MMAPString * str = (MMAPString *) carray_get(cTrustAnchors, i);
            const unsigned char * p = (const unsigned char *) str->str;
            X509 * anchor = d2i_X509(NULL, &p, (long) str->len);
            if (anchor != NULL) {
                X509_STORE_add_cert(store, anchor);
                X509_free(anchor);
            }
        }
    }
    
    certificates = sk_X509_new_null();
    for(unsigned int i = 0 ; i < carray_count(cCerts) ; i ++) {
        MMAPString * str;
        str = (MMAPString *) carray_get(cCerts, i);
        if (str == NULL) {
            MCLog("MCCertificateUtils error: out of index in array");
            goto free_certs;
        }
        
        BIO *bio = BIO_new_mem_buf((void *) str->str, str->len);
        X509 *certificate = d2i_X509_bio(bio, NULL);
        BIO_free(bio);
        if (certificate == NULL) {
            MCLog("MCCertificateUtils error: certificate %u is not a valid DER certificate", i);
            goto free_certs;
        }
        if (!sk_X509_push(certificates, certificate)) {
            MCLog("MCCertificateUtils error: can't sk_X509_push");
            // Not on the stack, so sk_X509_pop_free() below will not release it.
            X509_free(certificate);
            goto free_certs;
        }
    }
    
    ERR_clear_error();
    storectx = X509_STORE_CTX_new();
    if (storectx == NULL) {
        MCLog("MCCertificateUtils error: can't create X509_STORE_CTX");
        goto free_certs;
    }
    
    ERR_clear_error();
    status = X509_STORE_CTX_init(storectx, store, sk_X509_value(certificates, 0), certificates);
    if (status != 1) {
        MCLog("MCCertificateUtils error: X509_STORE_CTX_init status %d", status);
        goto free_certs;
    }
    
    // COR-170: X509_verify_cert() only validates the chain. It does not check that the
    // certificate was issued for the host we are connecting to (CWE-297), so a valid
    // certificate for any other domain would be accepted. Attach the expected identity to
    // the verification parameters so the hostname (or IP literal) is checked as part of
    // X509_verify_cert(), matching SecPolicyCreateSSL(true, hostname) on Apple platforms.
    {
        const char * host = hostname->UTF8Characters();
        X509_VERIFY_PARAM * param = X509_STORE_CTX_get0_param(storectx);
        X509_VERIFY_PARAM_set_hostflags(param, X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS);
        // set1_ip_asc() succeeds only when host parses as an IPv4/IPv6 literal and leaves
        // the parameters untouched otherwise, so fall back to a DNS name match.
        if (X509_VERIFY_PARAM_set1_ip_asc(param, host) != 1) {
            if (X509_VERIFY_PARAM_set1_host(param, host, 0) != 1) {
                MCLog("MCCertificateUtils error: can't set expected hostname %s", host);
                goto free_certs;
            }
        }
        if (verifyTime != 0) {
            // Tests: evaluate validity at a fixed point in time.
            X509_VERIFY_PARAM_set_time(param, verifyTime);
        }
    }
    
    ERR_clear_error();
    status = X509_verify_cert(storectx);
    if (status == 1) {
        result = true;
    }
    else {
        int verifyError = X509_STORE_CTX_get_error(storectx);
        MCLog("MCCertificateUtils error: X509_verify_cert status %d: %s (depth %d)", status,
              X509_verify_cert_error_string(verifyError), X509_STORE_CTX_get_error_depth(storectx));
        unsigned long errCode;
        while ((errCode = ERR_get_error()) != 0) {
            char *errMsg = ERR_error_string(errCode, NULL);
            MCLog("OpenSSL Error: %s", errMsg);
        }
    }
    
free_certs:
    if (certificates != NULL) {
        sk_X509_pop_free((STACK_OF(X509) *) certificates, X509_free);
    }
    if (storectx != NULL) {
        X509_STORE_CTX_free(storectx);
    }
    if (store != NULL) {
        X509_STORE_free(store);
    }
    return result;
#endif
}
