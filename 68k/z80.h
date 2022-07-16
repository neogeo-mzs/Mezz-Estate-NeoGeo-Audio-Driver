#ifndef Z80_H
#define Z80_H

#include "neogeo/neogeo_defines.h"

#define Z80_UCOM_PLAY_SONG(song)              Z80_send_user_command(0x01, song)
#define Z80_UCOM_STOP()                       Z80_send_user_command(0x02, 0)
#define Z80_UCOM_BUFFER_SFXPS_CVOL(pan, cvol) Z80_send_user_command(0x03, (pan) | ((cvol) & 0x1F))
#define Z80_UCOM_BUFFER_SFXPS_PRIO(prio)      Z80_send_user_command(0x04, prio)
#define Z80_UCOM_PLAY_SFXPS_SMP(smp)          Z80_send_user_command(0x05, smp)
#define Z80_UCOM_RETRIG_SFXPS_SMP(smp)        Z80_send_user_command(0x0B, smp)

typedef enum {
    PAN_NONE   = 0x00,
    PAN_LEFT   = 0x40,
    PAN_RIGHT  = 0x20,
    PAN_CENTER = 0x60,
} Panning;

void Z80_send_user_command(u8 command, u8 parameter);

#endif