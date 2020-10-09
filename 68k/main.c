#include "neogeo/neogeo.h"
#include "z80.h"
#include "fix.h"

// wpset $320000,1,r,1,{ printf "Read %04X from REG_SOUND",wpdata }
// wpset $320000,1,w,1,{ printf "Wrote %04X to REG_SOUND",wpdata }

// bpset 8, 1, { print "Bus error" }
// bpset C, 1, { print "Address error" }
// bpset 10, 1, { print "Illegal instruction" }
// bpset 14, 1, { print "Division by zero" }
// bpset 18, 1, { print "CHK instruction" }
// bpset 1C, 1, { print "TRAPV instruction" }

u8 song_select = 0;

volatile struct {
    u8 vblank_done : 1;
    u8 logic_done  : 1;
} render_status;

void rom_callback_VBlank() {
    // if the logic code is taking 
    // too long, skip the frame
    if (render_status.logic_done)
    {
        FIX_set_cursor(1, 5);
        FIX_print_string("CHANNEL ");
        FIX_print_byte(song_select);

        BIOS_system_io();
    }

    render_status.vblank_done = 1;
}

void print_gui()
{
    fix_print_palette = 1;

    for (u16 i = 16; i > 0; --i)
        PAL(1, i-1) = font_color_palette[i-1];

    FIX_set_cursor(0, 0);
    FIX_print_char(0x83);       // Curve topleft

    for (u16 i = 6; i > 0; --i)
        FIX_print_char(0x80);   // horizontal line

    FIX_print_string("\x81Mezz'Estate Audio test\x82");

    for (u16 i = 6; i > 0; --i)
        FIX_print_char(0x80);   // horizontal line

    FIX_print_char(0x84);       // curve topright

    cursor_vram_increment = 1;  // print top to bottom
    
    FIX_set_cursor(0, 1);
    for (u16 i = 26; i > 0; --i)
        FIX_print_char(0x87);   // vertical line

    FIX_set_cursor(37, 1);
    for (u16 i = 26; i > 0; --i)
        FIX_print_char(0x87);   // vertical line

    cursor_vram_increment = 32; // print left to right
    FIX_set_cursor(0, 27);

    FIX_print_char(0x85);       // curve bottom left

    for (u16 i = 36; i > 0; --i)
        FIX_print_char(0x80);   // horizontal line

    FIX_print_char(0x86);       // curve bottom right

    FIX_set_cursor(1, 2);
    FIX_print_string("\x8C\x8D Select a channel");
    FIX_set_cursor(1, 3);
    FIX_print_string("\x88  test channel");
}   

int main()
{
    // Initialize
	BIOS_fix_clear();

    print_gui();

    while(1)
    {
        PAL(0, 1) = WHITE;

        render_status.vblank_done = 0;
        render_status.logic_done  = 0;

        if (((NormalInput*)BIOS_P1CHANGE)->left && song_select >= 1)
            song_select--;
        else if(((NormalInput*)BIOS_P1CHANGE)->right && song_select <= 12)
            song_select++;

        if (((NormalInput*)BIOS_P1CHANGE)->A)
            Z80_play_song(song_select);

        // wait for vblank
        PAL(0, 1) = DARKGREY;
        render_status.logic_done = 1;
        *BIOS_MESS_BUSY = 0;
        while(!render_status.vblank_done);
    }

    return 0;
}
