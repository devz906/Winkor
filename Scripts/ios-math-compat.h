#ifndef IOS_MATH_COMPAT_H
#define IOS_MATH_COMPAT_H

// iOS math compatibility header
// Fixes missing math functions on iOS

#include <math.h>

#ifdef __cplusplus
extern "C" {
#endif

// iOS compatibility for math functions
#ifndef isnanf
#define isnanf(x) __builtin_isnan(x)
#endif

#ifndef isinff
#define isinff(x) __builtin_isinf(x)
#endif

#ifndef isfinitef
#define isfinitef(x) __builtin_isfinite(x)
#endif

#ifndef isnan
#define isnan(x) __builtin_isnan(x)
#endif

#ifndef isinf
#define isinf(x) __builtin_isinf(x)
#endif

#ifndef isfinite
#define isfinite(x) __builtin_isfinite(x)
#endif

// Additional math functions that might be missing
#ifndef signbit
#define signbit(x) __builtin_signbit(x)
#endif

#ifndef fpclassify
#define fpclassify(x) __builtin_fpclassify(x)
#endif

// iOS-specific fixes
#ifdef __arm64__
// ARM64 specific math optimizations
static inline int ios_isnanf(float x) {
    union { float f; uint32_t i; } u = {x};
    return (u.i & 0x7fffffff) > 0x7f800000;
}

static inline int ios_isinff(float x) {
    union { float f; uint32_t i; } u = {x};
    return (u.i & 0x7fffffff) == 0x7f800000;
}

// Override with ARM64 versions if needed
#undef isnanf
#define isnanf ios_isnanf

#undef isinff
#define isinff ios_isinff
#endif

#ifdef __cplusplus
}
#endif

#endif // IOS_MATH_COMPAT_H
