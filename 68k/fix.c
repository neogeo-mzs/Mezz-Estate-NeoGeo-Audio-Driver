#include "neogeo/neogeo.h"

u16 cursor_vram_pointer;
u8  fix_print_palette;

u8 cursor_vram_increment = 32;

const u16 font_color_palette[16] =
{
	0x8000, 0x8000, 0x7FFF, 0x6323, 
	0xE923, 0xAE34, 0xDF92, 0x4FE6, 
	0x16C4, 0x8374, 0xF133, 0xC468, 
	0x6ABD, 0x7FFF, 0xE2EF, 0x808D
};

const char hex_digits[] = 
{
	'0', '1', '2', '3', '4', '5', '6', '7',
	'8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
};

void FIX_set_cursor(u8 x, u8 y)
{
	cursor_vram_pointer = 0x7022 + (x<<5) + y; // x<<5 = x*32
}

void FIX_print_char(char chr)
{
	VRAM_write(
		cursor_vram_pointer,
		(fix_print_palette<<12) | chr);
	cursor_vram_pointer += cursor_vram_increment;
}

void FIX_print_string(char* str)
{
	for(; *str; ++str)
		FIX_print_char(*str);
}

void FIX_print_byte(u8 byte)
{
	FIX_print_char(hex_digits[byte >> 4]);
	FIX_print_char(hex_digits[byte & 0x0F]);
}

void FIX_print_word(u16 word)
{
	FIX_print_char(hex_digits[word >> 12]);
	FIX_print_char(hex_digits[word >> 8 & 0x0F]);
	FIX_print_char(hex_digits[word >> 4 & 0x0F]);
	FIX_print_char(hex_digits[word & 0x0F]);
}
void FIX_print_long(u32 lng)
{
	FIX_print_char(hex_digits[lng >> 28]);
	FIX_print_char(hex_digits[lng >> 24 & 0x0F]);
	FIX_print_char(hex_digits[lng >> 20 & 0x0F]);
	FIX_print_char(hex_digits[lng >> 16 & 0x0F]);
	FIX_print_char(hex_digits[lng >> 12 & 0x0F]);
	FIX_print_char(hex_digits[lng >> 8 & 0x0F]);
	FIX_print_char(hex_digits[lng >> 4 & 0x0F]);
	FIX_print_char(hex_digits[lng & 0x0F]);
}