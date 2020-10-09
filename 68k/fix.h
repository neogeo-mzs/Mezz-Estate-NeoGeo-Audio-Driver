#include "neogeo/neogeo.h"

extern const u16 font_color_palette[16];

extern u8 fix_print_palette;
extern u8 cursor_vram_increment;

void FIX_set_cursor(u8 x, u8 y);
void FIX_print_char(char chr);
void FIX_print_char_repeat(char chr, u16 times);
void FIX_print_string(char* str);
void FIX_print_byte(u8 byte);
void FIX_print_word(u16 word);
void FIX_print_long(u32 lng);