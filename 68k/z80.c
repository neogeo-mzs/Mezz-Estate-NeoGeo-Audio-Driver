#include "z80.h"
#include "utils.h"
#include "fix.h"

// Both the command's and the
// parameter's MSB is always
// set to 1
void Z80_send_user_command(u8 command, u8 parameter)
{
	const u8 user_com_mask = 0x80;
	const int X_OFS        = 1;
	const int Y_OFS        = 11;
	u8 tmp = 0;

	for (int i = 0; i < 4; i++)
	{
		FIX_SetCursor(X_OFS, i+Y_OFS);
		FIX_PrintString("--");
	}
	command |= user_com_mask;
	parameter |= user_com_mask;

	*REG_SOUND = command;

	FIX_SetCursor(X_OFS, Y_OFS);
	FIX_PrintNibble(command >> 4);
    FIX_PrintNibble(command & 0x0F);

    u8 neg_command = command ^ 0xFF;
	while (*REG_SOUND != neg_command)
	{
		FIX_SetCursor(X_OFS, 1+Y_OFS);
		tmp = *REG_SOUND;
		FIX_PrintNibble(tmp >> 4);
    	FIX_PrintNibble(tmp & 0x0F);
	};

	wait_loop(64);

	FIX_SetCursor(X_OFS, 1+Y_OFS);
	tmp = *REG_SOUND;
	FIX_PrintNibble(tmp >> 4);
   	FIX_PrintNibble(tmp & 0x0F);

	*REG_SOUND = parameter;

	FIX_SetCursor(X_OFS, 2+Y_OFS);
	FIX_PrintNibble(parameter >> 4);
    FIX_PrintNibble(parameter & 0x0F);

    u8 neg_parameter = parameter ^ 0xFF;
	while (*REG_SOUND != neg_parameter)
	{
		FIX_SetCursor(X_OFS, 3+Y_OFS);
		tmp = *REG_SOUND;

		FIX_PrintNibble(tmp >> 4);
    	FIX_PrintNibble(tmp & 0x0F);
	}

	wait_loop(64);

	FIX_SetCursor(X_OFS, 3+Y_OFS);
	tmp = *REG_SOUND;

	FIX_PrintNibble(tmp >> 4);
   	FIX_PrintNibble(tmp & 0x0F);
}

/*void Z80_send_user_command(u8 command, u8 parameter)
{
    const u8 user_com_mask = 0x80;
    command |= user_com_mask;
    parameter |= user_com_mask;

    *REG_SOUND = command;
    u8 neg_command = command ^ 0xFF;
    while (*REG_SOUND != neg_command);
    wait_loop(64);

    *REG_SOUND = parameter;
    u8 neg_parameter = parameter ^ 0xFF;
    while (*REG_SOUND != neg_parameter);
    wait_loop(64);
}*/