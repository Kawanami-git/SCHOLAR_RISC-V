// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       eprintf.c
\brief      Tiny printf that writes into CTP shared memory (bare-metal).
\author     Kawanami
\version    1.1
\date       12/01/2026

\details

\section eprintf_c_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 25/10/2025 | Kawanami   | Initial version.                          |
| 1.1     | 12/01/2026 | Kawanami   | Add the possibility to ignore Eprintf call using compiler flag for Spike compatibility. |
********************************************************************************
*/

#include <stdarg.h>
#include <stddef.h>

#include "defines.h"
#include "memory.h"

/* Write a single char and advance the output pointer. */
static inline void Ewc(volatile char** out, char c)
{
  **out = c;
  (*out)++;
}

/* Signed integer to string in base 10/16 (uses negative sign only for base 10). */
static uword_t Eits(word_t num, uword_t base, volatile char** out)
{
  uword_t count = 0;
  char    buffer[32];
  char*   ptr = buffer + sizeof(buffer) - 1;
  *ptr        = '\0';

  uword_t is_negative = (base == 10) && (num < 0);
  /* Cast through uword_t to avoid UB on MIN_INT negation */
  uword_t u = is_negative ? (uword_t)(-(num + 0)) : (uword_t)num;

  do
  {
    *--ptr = "0123456789abcdef"[u % base];
    u /= base;
  } while (u);

  if (is_negative)
  {
    *--ptr = '-';
  }

  while (*ptr)
  {
    Ewc(out, *ptr++);
    count++;
  }
  return count;
}

/* Unsigned integer to string in base 10/16. */
static uword_t Euts(uword_t num, uword_t base, volatile char** out)
{
  uword_t count = 0;
  char    buffer[32];
  char*   ptr = buffer + sizeof(buffer) - 1;
  *ptr        = '\0';

  do
  {
    *--ptr = "0123456789abcdef"[num % base];
    num /= base;
  } while (num);

  while (*ptr)
  {
    Ewc(out, *ptr++);
    count++;
  }
  return count;
}

/*!
 * \brief Embedded printf — writes into CTP shared buffer and signals platform.
 *
 * Protocol:
 *  1) Wait until CTP is free (SharedWriteReady()).
 *  2) Write message bytes at CTP_DATA.
 *  3) Null-terminate, then write message size at CTP_DATA_SIZE (as a word).
 *  4) SharedWriteAck() to publish the message.
 */
uword_t Eprintf(const char* fmt, ...)
{
#ifdef SPIKE
  return 0;
#endif

  if (!fmt)
  {
    return 0;
  }

  va_list args;
  va_start(args, fmt);

  while (!SharedWriteReady())
  { /* spin */
  }

  volatile char* out   = (volatile char*)SOFTCORE_0_CTP_RAM_DATA_ADDR;
  uword_t        count = 0;

  while (*fmt)
  {
    if (*fmt == '%')
    {
      fmt++;
      if (*fmt == 's')
      {
        const char* str = va_arg(args, const char*);
        if (!str)
        {
          str = "(null)";
        }
        while (*str)
        {
          Ewc(&out, *str++);
          count++;
        }
      }
      else if (*fmt == 'd')
      {
        word_t num = va_arg(args, word_t);
        count += Eits(num, 10, &out);
      }
      else if (*fmt == 'u')
      {
        uword_t num = va_arg(args, uword_t);
        count += Euts(num, 10, &out);
      }
      else if (*fmt == 'l' && *(fmt + 1) == 'u')
      {
        fmt++;
        uword_t num = va_arg(args, uword_t);
        count += Euts(num, 10, &out);
      }
      else if (*fmt == 'x')
      {
        uword_t num = va_arg(args, uword_t);
        count += Euts(num, 16, &out); /* hex should be unsigned */
      }
      else
      {
        /* Unknown specifier: print it verbatim. */
        Ewc(&out, '%');
        count++;
        Ewc(&out, *fmt);
        count++;
      }
    }
    else
    {
      Ewc(&out, *fmt);
      count++;
    }
    fmt++;
  }

  /* Null-terminate for convenience on the host side. */
  *out = '\0';
  va_end(args);

  /* Write the message size as a full word, then ack. */
  volatile uword_t* sizep = (volatile uword_t*)SOFTCORE_0_CTP_RAM_DATA_SIZE_ADDR;
  *sizep                  = count;

  SharedWriteAck();
  return count;
}
