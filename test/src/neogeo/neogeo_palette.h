#ifndef NEOGEO_PALETTE_H_INCLUDED
#define NEOGEO_PALETTE_H_INCLUDED

#include <string.h>

//                                           bank*16
#define PAL_ENTRY(bank, entry) (PALETTE_RAM[(bank<<4) + entry])

static inline void PAL_CopyBank(u8 bank, const u16* src)
{
	memcpy((void*)(PALETTE_RAM + (bank<<4)), (void*)src, 32);
}

#endif