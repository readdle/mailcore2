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
#if __APPLE__
    bool result = false;
    CFStringRef hostnameCFString;
    SecPolicyRef policy;
    CFMutableArrayRef certificates;
    SecTrustRef trust = NULL;
    SecTrustResultType trustResult;
    OSStatus status;
    
    carray * cCerts = mailstream_get_certificate_chain(stream);
    if (cCerts == NULL) {
        fprintf(stderr, "warning: No certificate chain retrieved");
        goto err;
    }
    
    hostnameCFString = CFStringCreateWithCharacters(NULL, (const UniChar *) hostname->unicodeCharacters(),
                                                                hostname->length());
    policy = SecPolicyCreateSSL(true, hostnameCFString);
    certificates = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    
    for(unsigned int i = 0 ; i < carray_count(cCerts) ; i ++) {
        MMAPString * str;
        str = (MMAPString *) carray_get(cCerts, i);
        CFDataRef data = CFDataCreate(NULL, (const UInt8 *) str->str, (CFIndex) str->len);
        SecCertificateRef cert = SecCertificateCreateWithData(NULL, data);
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
    mailstream_certificate_chain_free(cCerts);
    CFRelease(policy);
    CFRelease(hostnameCFString);
err:
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
    
    carray * cCerts = mailstream_get_certificate_chain(stream);
    if (cCerts == NULL) {
        fprintf(stderr, "warning: No certificate chain retrieved");
        goto err;
    }
    
    store = X509_STORE_new();
    if (store == NULL) {
        goto free_certs;
    }
    
#ifdef _MSC_VER
	HCERTSTORE systemStore = CertOpenSystemStore(NULL, L"ROOT");

	PCCERT_CONTEXT previousCert = NULL;
	while (1) {
		PCCERT_CONTEXT nextCert = CertEnumCertificatesInStore(systemStore, previousCert);
		if (nextCert == NULL) {
			break;
		}
		X509 * openSSLCert = d2i_X509(NULL, (const unsigned char **)&nextCert->pbCertEncoded, nextCert->cbCertEncoded);
		if (openSSLCert != NULL) {
			X509_STORE_add_cert(store, openSSLCert);
			X509_free(openSSLCert);
		}
		previousCert = nextCert;
	}
	CertCloseStore(systemStore, 0);
#elif defined(ANDROID) || defined(__ANDROID__)
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
        if (!sk_X509_push(certificates, certificate)) {
            MCLog("MCCertificateUtils error: can't sk_X509_push");
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
    
    ERR_clear_error();
    status = X509_verify_cert(storectx);
    if (status == 1) {
        result = true;
    }
    else {
        MCLog("MCCertificateUtils error: X509_verify_cert status %d", status);
        unsigned long errCode;
        while ((errCode = ERR_get_error()) != 0) {
            char *errMsg = ERR_error_string(errCode, NULL);
            MCLog("OpenSSL Error: %s", errMsg);
        }
    }
    
free_certs:
    mailstream_certificate_chain_free(cCerts);
    if (certificates != NULL) {
        sk_X509_pop_free((STACK_OF(X509) *) certificates, X509_free);
    }
    if (storectx != NULL) {
        X509_STORE_CTX_free(storectx);
    }
    if (store != NULL) {
        X509_STORE_free(store);
    }
err:
    return result;
#endif
}
