#include "neogeo/neogeo.h"
#include "z80.h"

// wpset $320000,1,r,1,{ printf "Read %04X from REG_SOUND",wpdata }
// wpset $320000,1,w,1,{ printf "Wrote %04X to REG_SOUND",wpdata }

// bpset 8, 1, { print "Bus error" }
// bpset C, 1, { print "Address error" }
// bpset 10, 1, { print "Illegal instruction" }
// bpset 14, 1, { print "Division by zero" }
// bpset 18, 1, { print "CHK instruction" }
// bpset 1C, 1, { print "TRAPV instruction" }

volatile struct {
    u8 vblank_done : 1;
    u8 logic_done  : 1;
} render_status;

void rom_callback_VBlank() {
    // if the logic code is taking 
    // too long, skip the frame
    if (render_status.logic_done)
    {
        // render here...
    }

    render_status.vblank_done = 1;
    BIOS_system_io();
}

int main()
{
    // Initialize
	BIOS_fix_clear();

    while(1)
    {
        PALETTES[1] = WHITE;

        render_status.vblank_done = 0;
        render_status.logic_done  = 0;

        // Update game logic here...
        if (((NormalInput*)BIOS_P1CHANGE)->A)
            Z80_play_song(0);
        else if (((NormalInput*)BIOS_P1CHANGE)->B)
            Z80_play_song(1);
        else if (((NormalInput*)BIOS_P1CHANGE)->C)
            Z80_play_song(2);

        // wait for vblank
        PALETTES[1] = DARKGREY;
        render_status.logic_done = 1;
        while(!render_status.vblank_done);
    }

    return 0;
}
