#ifndef FIX_H_INCLUDED
#define FIX_H_INCLUDED

#include "neogeo/neogeo.h"

extern const u16 font_palette[16];

void FIX_SetCursor(u8 x, u8 y);
void FIX_SetPalette(u8 pal);
void FIX_PrintChar(const char chr);
void FIX_PrintStringEx(const char* str, u8 limit);
void FIX_PrintString(const char* str);
void FIX_PrintNibble(u8 nibble);
void FIX_PrintByte(u8 byte);
void FIX_PrintWord(u16 word);
void FIX_PrintLong(u32 lng);

#endif