	org WRAM_START

breakpoint: ds 1

com_buffer:              ds COM_BUFFER_LENGTH*2 ; u16[COM_BUFFER_LENGTH]
com_buffer_idx_w:        ds 1                   ; u8
com_buffer_idx_r:        ds 1                   ; u8

; If 0, then the z80 is waiting for the command's LSB,
; if 1, then the z80 is waiting for the command's MSB
; else, the behaviour is undefined.
com_buffer_byte_significance: ds 1                   ; u8

; ======== MLM player ========
MLM_wram_start:
MLM_playback_pointers:        ds 2*CHANNEL_COUNT     ; void*[13]
MLM_playback_start_pointers:  ds 2*CHANNEL_COUNT     ; void*[13]
MLM_playback_timings:         ds 2*CHANNEL_COUNT     ; u16[13]
MLM_playback_set_timings:     ds 2*CHANNEL_COUNT     ; u16[13]
MLM_playback_control:         ds CHANNEL_COUNT       ; bool[13]
MLM_event_arg_buffer:         ds 32                  ; u8[32]
MLM_channel_instruments:      ds CHANNEL_COUNT       ; u8[13]
MLM_channel_pannings:         ds CHANNEL_COUNT       ; u8[13]
MLM_channel_volumes:          ds CHANNEL_COUNT       ; u8[13]
MLM_base_time:                ds 1                   ; u8
MLM_base_time_counter:        ds 1                   ; u8
MLM_wram_end:

; ======== SSG Controller variables ========
SSGCNT_wram_start:
SSGCNT_volumes:			ds 3 ; u8[3]
SSGCNT_mix_flags:    	ds 1 ; u8 (Buffer for the YM2610's $07 Port A register)
SSGCNT_noise_tune:		ds 1 ; u8
SSGCNT_channel_enable:	ds 3 ; bool[3]

SSGCNT_nibble_macros:
SSGCNT_vol_macro_A: 	SSGCNT_macro 
SSGCNT_vol_macro_B: 	SSGCNT_macro
SSGCNT_vol_macro_C:		SSGCNT_macro
SSGCNT_mix_macro_A:		SSGCNT_macro
SSGCNT_mix_macro_B:		SSGCNT_macro
SSGCNT_mix_macro_C:		SSGCNT_macro
SSGCNT_noise_macro:		SSGCNT_macro

SSGCNT_notes:			ds 3 ; u8[3]
SSGCNT_wram_end:

; ======== FM ========
FM_wram_start:
FM_base_total_levels:     ds 4*(FM_CHANNEL_COUNT+2) ; u8[6][4]
FM_channel_fnums:         ds 2*(FM_CHANNEL_COUNT+2) ; u16[6]
FM_channel_fblocks:       ds FM_CHANNEL_COUNT+2     ; u8[6]
FM_portamento_slide:      ds 2*(FM_CHANNEL_COUNT+2) ; u16[4]
FM_wram_end:

; ======== IRQ ========
IRQ_buffer:                   ds 2*IRQ_BUFFER_LENGTH ; u16[IRQ_BUFFER_LENGTH]
IRQ_buffer_idx_w:             ds 1                   ; u8
IRQ_buffer_idx_r:             ds 1                   ; u8

; ======== Others ========
EXT_2CH_mode: ds 1 ; u8 (0: 2CH mode off; 64: 2CH mode on)
tmp: ds 1