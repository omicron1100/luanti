
#pragma once

#include <cstdint>
#include <cassert>


typedef uint8_t u8;
typedef int8_t  s8;
typedef char    c8;

//! 16 bit unsigned variable.
typedef uint16_t u16;

//! 16 bit signed variable.
typedef int16_t s16;

//! 32 bit unsigned variable.
typedef uint32_t u32;

//! 32 bit signed variable.
typedef int32_t s32;

//! 64 bit unsigned variable.
typedef uint64_t u64;

//! 64 bit signed variable.
typedef int64_t s64;

//! 32 bit floating point variable.
/** This is a typedef for float, it ensures portability of the engine. */
typedef float f32;

//! 64 bit floating point variable.
/** This is a typedef for double, it ensures portability of the engine. */
typedef double f64;

//! Type name for character type used by the file system (legacy).
typedef char fschar_t;