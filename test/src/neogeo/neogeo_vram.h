#include "neogeo_defines.h"

#ifndef NEOGEO_VRAM_H_INCLUDED
#define NEOGEO_VRAM_H_INCLUDED

// VRAM
static inline void VRAM_write(u16 addr, u16 data)
{
	*REG_VRAMADDR = addr;
	*REG_VRAMRW = data;
}

static inline u16 VRAM_read(u16 addr)
{
	*REG_VRAMADDR = addr;
	return *REG_VRAMRW;
}

#endif // NEOGEO_VRAM_H_INCLUDED