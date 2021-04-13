#include "z80.h"
#include "utils.h"
#include "fix.h"

// Both the command's and the
// parameter's MSB is always
// set to 1
void Z80_send_user_command(u8 command, u8 parameter)
{
	const u8 user_com_mask = 0x80;
	//u8 tmp = 0;

	/*for (int i = 0; i < 4; i++)
	{
		FIX_SetCursor(0, i);
		FIX_PrintString("--");
	}*/
	command |= user_com_mask;
	parameter |= user_com_mask;

	*REG_SOUND = command;

	/*FIX_SetCursor(0, 0);
	FIX_PrintNibble(command >> 4);
    FIX_PrintNibble(command & 0x0F);*/

	while (*REG_SOUND != (command ^ 0xFF))
	{
		/*FIX_SetCursor(0, 1);
		tmp = *REG_SOUND;

		FIX_PrintNibble(tmp >> 4);
    	FIX_PrintNibble(tmp & 0x0F);*/
	};

	wait_loop(64);

	/*FIX_SetCursor(0, 1);
	tmp = *REG_SOUND;
	FIX_PrintNibble(tmp >> 4);
   	FIX_PrintNibble(tmp & 0x0F);*/

	*REG_SOUND = parameter;

	/*FIX_SetCursor(0, 2);
	FIX_PrintNibble(parameter >> 4);
    FIX_PrintNibble(parameter & 0x0F);*/

	while (*REG_SOUND != (parameter ^ 0xFF))
	{
		/*FIX_SetCursor(0, 3);
		tmp = *REG_SOUND;

		FIX_PrintNibble(tmp >> 4);
    	FIX_PrintNibble(tmp & 0x0F);*/
	}

	wait_loop(64);

	/*FIX_SetCursor(0, 3);
	tmp = *REG_SOUND;

	FIX_PrintNibble(tmp >> 4);
   	FIX_PrintNibble(tmp & 0x0F);*/
}