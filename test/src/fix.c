#include "neogeo/neogeo.h"
#include "fix.h"

u16 cursor_vram_pointer;
u8 cursor_x, cursor_y;
u8  fix_print_palette = 0;

const char hex_digits[] = 
{
	'0', '1', '2', '3', '4', '5', '6', '7',
	'8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
};

const u16 font_palette[16] =
{
	0x8000, 0x8000, 0x7FFF, 0x6323, 
	0xE923, 0xAE34, 0xDF92, 0x4FE6, 
	0x16C4, 0x8374, 0xF133, 0xC468, 
	0x6ABD, 0x7FFF, 0xE2EF, 0x808D
};

void FIX_SetCursor(u8 x, u8 y)
{
	cursor_vram_pointer = 0x7022 + (x<<5) + y; // x<<5 = x*32
	cursor_x = x;
	cursor_y = y;
}


void FIX_SetPalette(u8 pal)
{
	fix_print_palette = pal & 0x0F; // This way the palette is guaranted to be inbetween 0 and 15
}

void FIX_PrintChar(const char chr)
{
	VRAM_write(
		cursor_vram_pointer,
		(fix_print_palette<<12) | chr);
	cursor_vram_pointer += 32;
	cursor_x += 1;
}

void FIX_PrintStringEx(const char* str, u8 limit)
{
	u8 start_x = cursor_x;

	for(; *str; ++str)
	{
		switch (*str)
		{
		case '\n':
			FIX_SetCursor(start_x, cursor_y+1);
			break;

		default:
			if (cursor_x >= limit)
				FIX_SetCursor(start_x, cursor_y+1);
			FIX_PrintChar(*str);
			break;
		}
	}
}

void FIX_PrintString(const char* str)
{
	FIX_PrintStringEx(str, FIX_LAYER_COLUMNS_SAFE);
}

void FIX_PrintNibble(u8 nibble)
{
	FIX_PrintChar(hex_digits[nibble & 0x0F]);
}

void FIX_PrintByte(u8 byte)
{
	FIX_PrintNibble(byte >> 4);
    FIX_PrintNibble(byte & 0x0F);
}

void FIX_PrintWord(u16 word)
{
	FIX_PrintChar(hex_digits[word >> 12]);
	FIX_PrintChar(hex_digits[word >> 8 & 0x0F]);
	FIX_PrintChar(hex_digits[word >> 4 & 0x0F]);
	FIX_PrintChar(hex_digits[word & 0x0F]);
}
void FIX_PrintLong(u32 lng)
{
	FIX_PrintChar(hex_digits[lng >> 28]);
	FIX_PrintChar(hex_digits[lng >> 24 & 0x0F]);
	FIX_PrintChar(hex_digits[lng >> 20 & 0x0F]);
	FIX_PrintChar(hex_digits[lng >> 16 & 0x0F]);
	FIX_PrintChar(hex_digits[lng >> 12 & 0x0F]);
	FIX_PrintChar(hex_digits[lng >> 8 & 0x0F]);
	FIX_PrintChar(hex_digits[lng >> 4 & 0x0F]);
	FIX_PrintChar(hex_digits[lng & 0x0F]);
}