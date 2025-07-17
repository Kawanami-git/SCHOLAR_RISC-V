#include "memory.h"
#include "defines.h"

/*
 * Writes `size` bytes from the `data` buffer to the given memory `addr`.
 * Assumes `size` is a multiple of 4 (word-aligned transfer).
 */
void mem_write(uintptr_t addr, const uint32_t* data, uint32_t size)
{
    uint32_t* localaddr = (uint32_t*)addr;
    for(int i = 0; i < size; i+=4)
    {
        *localaddr = *data;
        localaddr++;
        data++;
    }
}

/*
 * Reads `size` bytes from the given memory `addr` to the `data` buffer.
 * Assumes `size` is a multiple of 4 (word-aligned transfer).
 */
void mem_read(uintptr_t addr, uint32_t* data, uint32_t size)
{
    uint32_t* localaddr = (uint32_t*)addr;
    for(int i = 0; i < size; i+=4)
    {
        *data = *localaddr;
        localaddr++;
        data++;
    }
}

/*
 * Fill a memory region with a given 32-bit value.
 *
 * Sets `size` bytes starting at `addr` to `value`, word by word (4 bytes).
 * Assumes both `addr` and `size` are word-aligned.
 */
void mem_reset(uint32_t addr, uint32_t size, uint32_t value)
{
    uint32_t* localaddr = (uint32_t*)addr;

    for(int i = 0; i < size; i+=4)
    {
        *localaddr = value;
        localaddr++;
    }
}

/*
 * Check if the core-to-platform shared memory is ready.
 *
 * Returns 1 if the platform-to-core (PTC) and core-to-platform (CTP)
 * message counters are synchronized, indicating that the
 * core-to-platform shared memory is ready to be written by the core.
 */
inline uint32_t shared_write_ready()
{
    uint32_t* ctp_count = (uint32_t*)SOFTCORE_0_CTP_RAM_CORE_COUNT_ADDR;
    uint32_t* ptc_count = (uint32_t*)SOFTCORE_0_PTC_RAM_CORE_COUNT_ADDR;

    if(*ptc_count == *ctp_count) { return 1; }

    return 0;
}

/*
 * Check if new data is available to be read by the core
 * in the platform-to-core shared memory.
 *
 * Returns the size of the available message (in bytes) if the
 * platform-to-core (PTC) message count is greater than the last
 * processed core-to-platform (CTP) count. Otherwise, returns 0.
 */
inline uint32_t shared_read_ready()
{
    uint32_t* ctp_count = (uint32_t*)SOFTCORE_0_CTP_RAM_PLATFORM_COUNT_ADDR;
    uint32_t* ptc_count = (uint32_t*)SOFTCORE_0_PTC_RAM_PLATFORM_COUNT_ADDR;
    uint32_t* size      = (uint32_t*)SOFTCORE_0_PTC_RAM_DATA_SIZE_ADDR;
    if(*ptc_count > *ctp_count)
    {
        return *size;
    }

    return 0;
}

/*
 * Acknowledge that the platform has read a message from platform-to-core (PTC)
 * shared RAM by incrementing the core-to-platform platform read counter.
 */
inline void shared_read_ack()
{
    uint32_t* count = (uint32_t*)SOFTCORE_0_CTP_RAM_PLATFORM_COUNT_ADDR;
    *count = *count + 1;
}

/*
 * Acknowledge that the core has written a message to core-to-platform (CTP)
 * shared RAM by incrementing the core-to-platform write counter.
 */
inline void shared_write_ack()
{
    uint32_t* count = (uint32_t*)SOFTCORE_0_CTP_RAM_CORE_COUNT_ADDR;
    *count = *count + 1;
}