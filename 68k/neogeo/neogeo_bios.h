#ifndef NEOGEO_BIOS_H_INCLUDED
#define NEOGEO_BIOS_H_INCLUDED

static inline void BIOS_system_io()
{
    __asm__ volatile ("jsr 0xC0044A");
}

static inline void BIOS_fix_clear()
{
    __asm__ volatile ("jsr 0xC004C2" : : : "d0", "d1", "a0");
}

#endif // NEOGEO_BIOS_H_INCLUDED
