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

const char TRACK_METADATA[(FIX_LAYER_COLUMNS_SAFE-2) * (FIX_LAYER_ROWS-6)] =
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt"
    " ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco"
    " laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in"
    " voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat"
    " non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";

const char* INSTRUCTION_BOX_STRING =
{
    "\x83\x80\x80\x80\x80\x80\x80\x80\x80\x80\x81""Deflemask Player\x82\x80\x80\x80\x80\x80\x80\x80\x80\x80\x84"
    "\x87                                    \x87"
    "\x87         \x88 Play      \x89 Stop         \x87"
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
    FIX_PrintStringEx(TRACK_METADATA, FIX_LAYER_COLUMNS_SAFE-1);
}   

int main()
{
	BIOS_FixClear();
    print_gui();
    
    /*FIX_SetPalette(1);
    PAL_ENTRY(0, 1) = WHITE;
    for (u8 bank = 0; bank < 0x20; bank++)
    {
        FIX_SetCursor(bank & 0x10, bank & 0x0F);
        FIX_PrintNibble(bank >> 4);
        FIX_PrintNibble(bank & 0x0F);

        FIX_PrintString(": ");

        Z80_UCOM_BANK_TEST_Z3(bank);
        Z80_UCOM_BANK_TEST_Z3(bank);

        u8 reg_sound = *REG_SOUND;
        FIX_PrintNibble(reg_sound >> 4);
        FIX_PrintNibble(reg_sound & 0x0F);
    }*/

    while(1)
    {
        PAL_ENTRY(0, 1) = WHITE;

        render_status.vblank_done = 0;
        render_status.logic_done  = 0;

        if (BIOS_P1CHANGE->A)
            Z80_UCOM_PLAY_SONG(0);
        if (BIOS_P1CHANGE->B)
            Z80_UCOM_STOP();

        // print data (should use MESS OUT to prevent tearing)
        //FIX_SetCursor(1, 1); 
        //FIX_SetPalette(1);
        //FIX_PrintByte(*REG_SOUND);

        // wait for vblank
        PAL_ENTRY(0, 1) = DARKGREY;
        render_status.logic_done = 1;
        *BIOS_MESS_BUSY = 0;
        while(!render_status.vblank_done);
    }

    return 0;
}
