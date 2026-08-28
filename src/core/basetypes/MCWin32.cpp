#include "MCWin32.h"
#include <io.h>
#include <wchar.h>

// DSK-658: caller frees. Returns NULL when the input is not valid UTF-8.
static wchar_t * win32_path_to_wide(const char * path)
{
    if (path == NULL) {
        return NULL;
    }
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
    if (count <= 0) {
        return NULL;
    }
    wchar_t * widePath = (wchar_t *) malloc(count * sizeof(* widePath));
    if (widePath == NULL) {
        return NULL;
    }
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, widePath, count) <= 0) {
        free(widePath);
        return NULL;
    }
    return widePath;
}

static FILE * win32_fopen_narrow(const char * filename, const char * mode)
{
    FILE * f = NULL;
    int r = fopen_s(&f, filename, mode);
    if (r != 0) {
        return NULL;
    }
    return f;
}

FILE * mailcore::win32_fopen(const char * filename, const char * mode)
{
    if (mode == NULL) {
        return win32_fopen_narrow(filename, mode);
    }
    size_t modeLength = strlen(mode);
    wchar_t wideMode[16];
    if (modeLength >= sizeof(wideMode) / sizeof(wideMode[0])) {
        return win32_fopen_narrow(filename, mode);
    }
    wchar_t * wideFilename = win32_path_to_wide(filename);
    if (wideFilename == NULL) {
        return win32_fopen_narrow(filename, mode);
    }
    // mode is ASCII by contract, widen it char-by-char
    for (size_t i = 0; i <= modeLength; i++) {
        wideMode[i] = (wchar_t) (unsigned char) mode[i];
    }
    FILE * f = NULL;
    errno_t r = _wfopen_s(&f, wideFilename, wideMode);
    free(wideFilename);
    if (r != 0) {
        return NULL;
    }
    return f;
}

int mailcore::win32_unlink(const char * path)
{
    wchar_t * widePath = win32_path_to_wide(path);
    if (widePath == NULL) {
        return _unlink(path);
    }
    int r = _wunlink(widePath);
    free(widePath);
    return r;
}

int mailcore::win32_mkdir(const char * path)
{
    wchar_t * widePath = win32_path_to_wide(path);
    if (widePath == NULL) {
        return _mkdir(path);
    }
    int r = _wmkdir(widePath);
    free(widePath);
    return r;
}

int mailcore::win32_stat(const char * path, struct stat * buffer)
{
    // struct stat is struct _stat64i32 in the UCRT unless _USE_32BIT_TIME_T is set
    static_assert(sizeof(struct stat) == sizeof(struct _stat64i32), "unexpected struct stat layout");
    wchar_t * widePath = win32_path_to_wide(path);
    if (widePath == NULL) {
        return _stat64i32(path, (struct _stat64i32 *) buffer);
    }
    int r = _wstat64i32(widePath, (struct _stat64i32 *) buffer);
    free(widePath);
    return r;
}

static const unsigned __int64 epoch = ((unsigned __int64)116444736000000000ULL);
/*
* timezone information is stored outside the kernel so tzp isn't used anymore.

*
* Note: this function is not for Win32 high precision timing purpose. See
* elapsed_time().
*/
int mailcore::win32_gettimeofday(struct timeval * tp, struct timezone * tzp)
{
    // WARNING - tzp is ignored in this implementation.
    FILETIME    file_time;
    SYSTEMTIME  system_time;
    ULARGE_INTEGER ularge;

    GetSystemTime(&system_time);
    SystemTimeToFileTime(&system_time, &file_time);
    ularge.LowPart = file_time.dwLowDateTime;
    ularge.HighPart = file_time.dwHighDateTime;

    tp->tv_sec = (long)((ularge.QuadPart - epoch) / 10000000L);
    tp->tv_usec = (long)(system_time.wMilliseconds * 1000);
       
    return 0;
}

static int is_leap(unsigned y) {
	y += 1900;
	return (y % 4) == 0 && ((y % 100) != 0 || (y % 400) == 0);
}

time_t mailcore::win32_timegm(struct tm *tm) {
	static const unsigned ndays[2][12] = {
			{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 },
			{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	};
	time_t res = 0;
	int i;

	for (i = 70; i < tm->tm_year; ++i)
		res += is_leap(i) ? 366 : 365;

	for (i = 0; i < tm->tm_mon; ++i)
		res += ndays[is_leap(tm->tm_year)][i];
	res += tm->tm_mday - 1;
	res *= 24;
	res += tm->tm_hour;
	res *= 60;
	res += tm->tm_min;
	res *= 60;
	res += tm->tm_sec;
	return res;
}

struct tm * mailcore::win32_gmtime_r(const time_t *clock, struct tm *result)
{
    gmtime_s(result, clock);
	return result;
}

struct tm * mailcore::win32_localtime_r(const time_t *clock, struct tm *result)
{
    localtime_s(result, clock);
	return result;
}

char * mailcore::win32_strcasestr(const char * s, const char * find)
{
    char c, sc;
    size_t len;

    if ((c = *find++) != 0) {
        c = tolower((unsigned char)c);
        len = strlen(find);
        do {
            do {
                if ((sc = *s++) == 0)
                    return (NULL);
            } while ((char)tolower((unsigned char)sc) != c);
        } while (strncasecmp(s, find, len) != 0);
        s--;
    }
    return ((char *)s);
}

int mailcore::win32_vasprintf(char **strp, const char *fmt, va_list ap)
{
    int r = -1, size = _vscprintf(fmt, ap);

    if ((size >= 0) && (size < INT_MAX)) {
        *strp = (char *) malloc(size + 1);
        if (* strp) {
            r = vsnprintf_s(* strp, size + 1, _TRUNCATE, fmt, ap);
            if ((r < 0) || (r > size))
            {
                free(* strp);
                r = -1;
            }
        }
    }
    else {
        * strp = 0;
    }

    return r;
}

int mailcore::win32_snprintf(char * str, size_t size, const char *  format, ...)
{
    va_list argp;
    
    va_start(argp, format);
    int result = vsnprintf_s(str, size, _TRUNCATE, format, argp);
    va_end(argp);
    
    return result;
}

long mailcore::win32_random(void)
{
    unsigned int randValue;
    rand_s(&randValue);
    return randValue;
}

pid_t mailcore::win32_getpid(void)
{
    return GetCurrentProcessId();
}

static const char padchar[] =
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

char * mailcore::win32_mkdtemp(char *path)
{
    register char *start, *trv, *suffp;
    const char *pad;
    struct stat sbuf;
    int rval;

    for (trv = path; *trv; ++trv);
    suffp = trv;
    --trv;
    if (trv < path) {
        errno = EINVAL;
        return NULL;
    }

    /* Fill space with random characters */
    /*
     * I hope this is random enough.  The orginal implementation
     * uses arc4random(3) which is not available everywhere.
     */
    while (*trv == 'X') {
        //int randv = g_random_int_range(0, sizeof(padchar) - 1);
        int randv = mailcore::win32_random() % sizeof(padchar);
        *trv-- = padchar[randv];
    }
    start = trv + 1;

    /*
     * check the target directory.
     */
    for (;; --trv) {
        if (trv <= path)
            break;
        if (*trv == '/') {
            *trv = '\0';
            rval = stat(path, &sbuf);
            *trv = '/';
            if (rval != 0)
                return NULL;
            if (!S_ISDIR(sbuf.st_mode)) {
                errno = ENOTDIR;
                return NULL;
            }
            break;
        }
    }

    for (;;) {
        if (mkdir(path) == 0)
            return path;
        if (errno != EEXIST)
            return NULL;

        /* If we have a collision, cycle through the space of filenames */
        for (trv = start;;) {
            if (*trv == '\0' || trv == suffp)
                return NULL;
            pad = strchr(padchar, *trv);
            if (pad == NULL || !*++pad)
                *trv++ = padchar[0];
            else {
                *trv++ = *pad;
                break;
            }
        }
    }
}

void * mailcore::win32_mmap(void * start, size_t length, int prot, int flags, int fd, off_t offset) {
	struct stat st;
	size_t len;
	if (!fstat(fd, &st)) {
		len = (size_t)st.st_size;
	} 
	else {
		fprintf(stderr,"mmap: could not determine filesize");
		return MAP_FAILED;
	}

	if ((length + offset) > len) {
		length = len - offset;
	}

	if (!(flags & MAP_PRIVATE)) {
		fprintf(stderr, "Invalid usage of mmap when built with USE_WIN32_MMAP");
		return MAP_FAILED;
	}

	HANDLE hmap = CreateFileMapping((HANDLE)_get_osfhandle(fd), 0, PAGE_WRITECOPY, 0, 0, 0);

	if (!hmap) {
		return MAP_FAILED;
	}

	uint64_t o = offset;
	uint32_t l = o & 0xFFFFFFFF;
	uint32_t h = (o >> 32) & 0xFFFFFFFF;

	void * temp = MapViewOfFileEx(hmap, FILE_MAP_COPY, h, l, length, start);

	if (!CloseHandle(hmap)) {
		fprintf(stderr, "unable to close file mapping handle\n");
	}

	return temp ? temp : MAP_FAILED;
}

int mailcore::win32_munmap(void * start, size_t length) {
	return !UnmapViewOfFile(start);
}

