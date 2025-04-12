//
//  MCICUTypes.h
//  mailcore2
//
//  Created by DINH Viêt Hoà on 4/18/13.
//  Copyright (c) 2013 MailCore. All rights reserved.
//

#ifndef MAILCORE_MCICUTYPES_H

#define MAILCORE_MCICUTYPES_H

/**
 * UChar
 *
 * The base type for UTF-16 code units and pointers.
 * Unsigned 16-bit integer.
 * Starting with ICU 59, C++ API uses char16_t directly, while C API continues to use UChar.
 *
 * UChar is configurable by defining the macro UCHAR_TYPE
 * on the preprocessor or compiler command line:
 * -DUCHAR_TYPE=uint16_t or -DUCHAR_TYPE=wchar_t (if U_SIZEOF_WCHAR_T==2) etc.
 * (The UCHAR_TYPE can also be #defined earlier in this file, for outside the ICU library code.)
 * This is for transitional use from application code that uses uint16_t or wchar_t for UTF-16.
 *
 * The default is UChar=char16_t.
 *
 * C++11 defines char16_t as bit-compatible with uint16_t, but as a distinct type.
 *
 * In C, char16_t is a simple typedef of uint_least16_t.
 * ICU requires uint_least16_t=uint16_t for data memory mapping.
 * On macOS, char16_t is not available because the uchar.h standard header is missing.
 *
 * @stable ICU 4.4
 */

#if defined(_MSC_VER) || defined(ANDROID)
#include <unicode/uchar.h>
#elif defined(__CHAR16_TYPE__)
typedef __CHAR16_TYPE__ UChar;
#else
typedef uint16_t UChar;
#endif

#endif /* MAILCORE_MCICUTYPES_H */

