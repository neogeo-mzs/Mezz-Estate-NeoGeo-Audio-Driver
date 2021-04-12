#ifndef Z80_H
#define Z80_H

#include "neogeo/neogeo_defines.h"

#define Z80_UCOM_PLAY_SONG(song)    Z80_send_user_command(0x01, song)
#define Z80_UCOM_STOP()             Z80_send_user_command(0x02, 0)
#define Z80_UCOM_BANK_TEST_Z3(bank) Z80_send_user_command(0x03, bank)

void Z80_send_user_command(u8 command, u8 parameter);

#endif