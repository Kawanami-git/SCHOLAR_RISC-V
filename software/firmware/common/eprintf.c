#include <stdarg.h>
#include "defines.h"
#include "memory.h"

/*
* Embedded write char.
* Writes a character to the shared memory (core-to-platform) and advances the pointer.
*/
inline void ewc(volatile char **out, char c)
{
    **out = c;
    (*out)++;
}

/*
* Embedded int to string.
* Converts an integer to a string in the given base and writes it to 
* the shared memory (core-to-platform).
* Supports decimal (with sign) and hexadecimal output.
* Returns the number of characters written.
*/
uint32_t eits(int num, int base, volatile char **out)
{
    uint32_t count = 0;
    char buffer[32];
    char *ptr = buffer + sizeof(buffer) - 1;
    *ptr = '\0';

    int is_negative = (num < 0 && base == 10);
    uint32_t u = is_negative ? -(uint32_t)num : (uint32_t)num;

    do {
        *--ptr = "0123456789abcdef"[u % base];
        u /= base;
    } while (u);

    if (is_negative) *--ptr = '-';

    while (*ptr) {
        ewc(out, *ptr++);
        count++;
    }

    return count;
}

/*
* Embedded unsigned int to string
* Converts an unsigned integer to a string in the given base
* and writes it to memory using the ewc helper.
* Returns the number of characters written.
*/
uint32_t euts(uint32_t num, int base, volatile char **out)
{
    uint32_t    count = 0;
    char        buffer[32];
    char*       ptr   = buffer + sizeof(buffer) - 1;
    *ptr = '\0';

    do 
    {
        *--ptr = "0123456789abcdef"[num % base];
        num /= base;
    } while(num);

    while(*ptr) { ewc(out, *ptr++); count++; }
    
    return count;
}

/*
 * Embedded printf implementation.
 * Formats and writes a string to shared memory for external observation.
 * Supports %s, %d, %u, %lu, and %x specifiers.
 *
 * Waits until the memory (core-to-platform) is ready, writes the formatted 
 * string into a shared memory, and sets the total number of characters 
 * written at the shared memory size address.
 * Finally, signals that the write is complete using mem_write_ack().
 *
 * Returns the number of characters written.
 */
int eprintf(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);

    while(!shared_write_ready()) {}

    volatile char *out = ((volatile char *)(SOFTCORE_0_CTP_RAM_DATA_ADDR));
    int count = 0;

    while (*fmt) 
    {
        if (*fmt == '%') 
        {
            fmt++;
            if (*fmt == 's') 
            {
                const char *str = va_arg(args, const char *);
                while (*str) 
                {
                    ewc(&out, *str++);
                    count++;
                }
            } 
            else if (*fmt == 'd') 
            {
                int32_t num = va_arg(args, int);
                count += eits(num, 10, &out);
            } 
            else if (*fmt == 'u' || (*fmt == 'l' && *(fmt+1) == 'u')) 
            {
                uint32_t num = va_arg(args, uint32_t);
                count += euts(num, 10, &out);
                if(*fmt == 'l') { fmt++; }
            } 
            else if (*fmt == 'x') 
            {
                int32_t num = va_arg(args, int);
                count += eits(num, 16, &out);
            } 
            else 
            {
                ewc(&out, '%'); count++;
                ewc(&out, *fmt); count++;
            }
        } 
        else 
        {
            ewc(&out, *fmt);
            count++;
        }
        fmt++;
    }

    *out = '\0';
    va_end(args);
    
    out = ((volatile char *)(SOFTCORE_0_CTP_RAM_DATA_SIZE_ADDR));
    *out = count;
        
    shared_write_ack();

    return count;
}
