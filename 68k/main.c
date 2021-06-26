#include "neogeo/neogeo.h"
#include "z80.h"
#include "fix.h"
#include "utils.h"

// wpset $320000,1,r,1,{ printf "Read %04X from REG_SOUND",wpdata }
// wpset $320000,1,w,1,{ printf "Wrote %04X to REG_SOUND",wpdata }

// bpset 8, 1, { print "Bus error" }
// bpset C, 1, { print "Address error" }
// bpset 10, 1, { print "Illegal instruction" }
// bpset 14, 1, { print "Division by zero" }
// bpset 18, 1, { print "CHK instruction" }
// bpset 1C, 1, { print "TRAPV instruction" }

const char* INSTRUCTION_BOX_STRING =
{                                                
    "\x83\x80\x80\x80\x80\x80\x80\x80\x80\x80\x81""MZS test program\x82\x80\x80\x80\x80\x80\x80\x80\x80\x80\x84"
    "\x87                                    \x87"
    "\x87  \x88 Play   \x89 Stop   \x8E\x8F Song Select  \x87"
    "\x87                                    \x87"
    "\x85\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x86"
};


volatile struct {
    u8 vblank_done : 1;
    u8 logic_done  : 1;
} render_status;

void rom_callback_VBlank() {
    // if the logic code is taking 
    // too long, skip the frame
    if (render_status.logic_done)
    {
        BIOS_SystemIo();
        BIOS_MessOut();
    }

    render_status.vblank_done = 1;
}

void print_gui()
{
    FIX_SetPalette(1);

    PAL_CopyBank(1, font_palette);

    FIX_SetCursor(0, 0);
    FIX_PrintString(INSTRUCTION_BOX_STRING);

    FIX_SetCursor(1, 6);
    FIX_PrintString("Song: $");
}   

int main()
{
	BIOS_FixClear();
    print_gui();

    const int SONG_COUNT = 13;
    int selected_song = 0;
    
    while(1)
    {
        PAL_ENTRY(0, 1) = WHITE;

        render_status.vblank_done = 0;
        render_status.logic_done  = 0;

        if (BIOS_P1CHANGE->up)
            selected_song = WRAP(selected_song+1, 0, SONG_COUNT);
        if (BIOS_P1CHANGE->down)
            selected_song = WRAP(selected_song-1, 0, SONG_COUNT);

        if (BIOS_P1CHANGE->A)
            Z80_UCOM_PLAY_SONG(selected_song);
        if (BIOS_P1CHANGE->B)
            Z80_UCOM_STOP();

        FIX_SetCursor(8, 6);
        FIX_PrintNibble(selected_song >> 4);
        FIX_PrintNibble(selected_song & 0x0F);

        // wait for vblank
        PAL_ENTRY(0, 1) = DARKGREY;
        render_status.logic_done = 1;
        *BIOS_MESS_BUSY = 0;
        while(!render_status.vblank_done);
    }

    return 0;
}
