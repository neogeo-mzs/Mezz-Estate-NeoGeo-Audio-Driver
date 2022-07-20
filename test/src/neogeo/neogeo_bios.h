#ifndef NEOGEO_BIOS_H_INCLUDED
#define NEOGEO_BIOS_H_INCLUDED

// BIOS calls
static inline void BIOS_SystemIo()
{
	/* The SYSTEM_IO routine apparently doesn't
	 * backup the registers, and since I don't
	 * know which registers are used, I'll just
	 * backup all of them!
	 */
    __asm__ volatile (
    	"movem.l %d0-%d7/%a0-%a7,-(%sp)  \n\t" 
    	"jsr 0xC0044A                    \n\t"
    	"movem.l (%sp)+,%d0-%d7/%a0-%a7  \n\t" 
    );
}

static inline void BIOS_FixClear()
{
    __asm__ volatile ("jsr 0xC004C2" : : : "d0", "d1", "a0");
}

static inline void BIOS_MessOut()
{
    __asm__ volatile ("jsr 0xC004CE");
}

static inline void BIOS_SystemInt1()
{
    __asm__ volatile ("jsr 0xC00438");
}

#endif // NEOGEO_BIOS_H_INCLUDED
