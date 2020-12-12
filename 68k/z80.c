#include "z80.h"
#include "utils.h"

void Z80_send_byte(u8 byte)
{
	static u8 expected_reply = 0x39;
	static u8 reply_increment = 0x00;

	while(*REG_SOUND != expected_reply);

	*REG_SOUND = byte;

	reply_increment++;
	expected_reply = byte+reply_increment;

	wait_loop(32);
}

void Z80_stop_ssg()
{
	Z80_send_byte(0x0A); // command (stop SSG channels)
}

void Z80_silence_fm()
{
	Z80_send_byte(0x0B); // command (Silence FM channels)
}

void Z80_stop_adpcma()
{
	Z80_send_byte(0x0C); // command (Stop ADPCM-A samples)
}

void Z80_play_adpcma_sample(u16 sfx_id, Panning panning, u8 volume, ADPCMChannel channel)
{
	Z80_send_byte(0x0F);                                        // command (play ADPCM sample)
	Z80_send_byte(sfx_id & 0x00FF);                             // sample id LSB
	Z80_send_byte((volume & 0x1F) | (panning << 6));            // Channel Volume (LR-VVVVV)
	Z80_send_byte((channel & 0x07) | ((sfx_id & 0x0100) >> 5)); // ----SCCC (Sample id MSB, Channel)
}

void Z80_set_adpcma_master_volume(u8 volume)
{
	Z80_send_byte(0x13);   // command (Set ADPCM-A volume)
	Z80_send_byte(volume); 
}

void Z80_set_irq_frequency(u8 frequency)
{
	Z80_send_byte(0x14);      // command (Set IRQ frequency)
	Z80_send_byte(frequency);
}

void Z80_play_ssg_note(u8 note, u8 instrument, SSGChannel channel, u8 volume)
{
	if (volume > 15) volume = 15;

	Z80_send_byte(0x15);       // command (Play SSG note)
	Z80_send_byte(note);
	Z80_send_byte(instrument);
	Z80_send_byte(channel | (volume<<4));
}

void Z80_play_fm_note(u8 note, u8 instrument, u8 attenuator, Panning panning, u8 op_slot, u8 channel)
{
	Z80_send_byte(0x16); // command (Play FM note)
	Z80_send_byte(note);
	Z80_send_byte(instrument);
	Z80_send_byte(attenuator);
	Z80_send_byte(panning<<6);
	Z80_send_byte(channel | (op_slot<<4));
}

void Z80_play_song(u8 song)
{
	Z80_send_byte(0x17); // command (Play song)
	Z80_send_byte(song);
}

void Z80_stop_song()
{
	Z80_send_byte(0x18); // command (Stop song)
}