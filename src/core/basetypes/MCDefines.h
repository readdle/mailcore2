#ifndef MCDEFINES_H_

#define MCDEFINES_H_

#if defined(__APPLE__) || defined(__ANDROID__) || defined(__linux__) || defined(_MSC_VER)
#define MC_HAS_GCD 1
#else
#define MC_HAS_GCD 0
#endif

#ifdef _MSC_VER

#pragma section(".CRT$XCU",read)
#define INITIALIZE(name) \
    static void __cdecl initialize_##name(void); \
    __declspec(allocate(".CRT$XCU")) void (__cdecl*initialize_##name##_)(void) = initialize_##name; \
    static void __cdecl initialize_##name(void)

#else

#define INITIALIZE(name) \
   static void initialize(void) __attribute__((constructor)); \
   static void initialize(void)

#endif

#endif
