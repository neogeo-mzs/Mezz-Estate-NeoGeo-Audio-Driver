#include "neogeo/neogeo.h"

/****************   base   ****************/
void Z80_send_byte(u8 byte);

/**************** commands ****************/
typedef enum {      //   LR
	PANNING_NONE,   // 0b00
	PANNING_RIGHT,  // 0b01
	PANNING_LEFT,   // 0b10
	PANNING_CENTER, // 0b11
} Panning;

typedef enum {
	ADPCM_CH1,
	ADPCM_CH2,
	ADPCM_CH3,
	ADPCM_CH4,
	ADPCM_CH5,
	ADPCM_CH6,
} ADPCMChannel;

typedef enum {
	SSG_CHA,
	SSG_CHB,
	SSG_CHC,
} SSGChannel;

#define FM_CH1 1
#define FM_CH2 2
#define FM_CH3 5
#define FM_CH4 6
#define FM_NOTE(octave, note) (note | (octave<<4))
#define FM_OPSLOT(op1, op2, op3, op4) ((op1<<4) | (op2<<5) | (op3<<6) | (op4<<7))

void Z80_stop_ssg();
void Z80_silence_fm();
void Z80_stop_adpcma();
void Z80_play_adpcma_sample(u16 sfx_id, Panning panning, u8 volume, ADPCMChannel channel);
void Z80_set_adpcma_master_volume(u8 volume);
void Z80_set_irq_frequency(u8 frequency);
void Z80_play_ssg_note(u8 note, u8 instrument, SSGChannel channel, u8 volume);
void Z80_play_fm_note(u8 note, u8 instrument, u8 attenuator, Panning panning, u8 op_slot, u8 channel);
void Z80_play_song(u8 song);
void Z80_stop_song();