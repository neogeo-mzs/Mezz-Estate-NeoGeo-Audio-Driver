	org WRAM_START

breakpoint: ds 1

com_buffer:                   ds COM_BUFFER_LENGTH*2 ; u16[COM_BUFFER_LENGTH]
com_buffer_idx_w:             ds 1                   ; u8
com_buffer_idx_r:             ds 1                   ; u8
com_sfxps_buffered_cvol:      ds 1 ; u8 (%LR-VVVVV)
com_sfxps_buffered_prio:      ds 1 ; u8
com_fdcnt_buffered_offset:    ds 1 ; u8

; If 0, then the z80 is waiting for the command's LSB,
; if 1, then the z80 is waiting for the command's MSB
; else, the behaviour is undefined.
com_buffer_byte_significance:  ds 1                   ; u8

; ======== MLM player ========
MLM_wram_start:
MLM_playback_pointers:        ds 2*CHANNEL_COUNT     ; void*[13]
MLM_playback_start_pointers:  ds 2*CHANNEL_COUNT     ; void*[13]
MLM_channel_control:          ds CHANNEL_COUNT       ; bool[13] (%0000'000E; channel Enable)
MLM_playback_timings:         ds CHANNEL_COUNT       ; u8[13]   
MLM_playback_set_timings:     ds CHANNEL_COUNT       ; u8[13]   
MLM_channel_instruments:      ds CHANNEL_COUNT       ; u8[13]
MLM_channel_pannings:         ds CHANNEL_COUNT       ; u8[13]
MLM_channel_volumes:          ds CHANNEL_COUNT       ; u8[13]
MLM_sub_el_return_pointers:   ds 2*CHANNEL_COUNT     ; void*[13]

MLM_channels:          ds MLM_Channel.SIZE*CHANNEL_COUNT

MLM_event_arg_buffer:  ds 32                  ; u8[32]
MLM_active_ch_counter: ds 1                   ; u8
MLM_instruments:       ds 2                   ; void*
MLM_wram_end:

; ======== SSG Controller variables ========
SSGCNT_wram_start:
SSGCNT_volumes:			ds SSG_CHANNEL_COUNT   ; u8[3]
SSGCNT_mix_flags:    	ds 1                   ; u8 (Buffer for the YM2610's $07 Port A register)
SSGCNT_noise_tune:		ds 1                   ; u8
SSGCNT_channel_enable:	ds SSG_CHANNEL_COUNT   ; bool[3]
SSGCNT_notes:			ds SSG_CHANNEL_COUNT   ; u8[3]
SSGCNT_pitch_ofs:       ds SSG_CHANNEL_COUNT*2 ; s16[3]
SSGCNT_pitch_slide_ofs: ds SSG_CHANNEL_COUNT*2 ; s16[3]
SSGCNT_pitch_slide_clamp: ds SSG_CHANNEL_COUNT*2 ; u16[3] bit 15: custom clamp enable, bit 14: clamp direction (0: below, 1: above)
SSGCNT_buffered_note:   ds SSG_CHANNEL_COUNT ; u8[3] Used to avoid issues with multiple clamped slides effects in a row.

; IF THE ORDER OF THESE MACROS IS 
; CHANGED THEN "MLM_set_instrument_ssg"
; AND "SSGCNT_start_channel_macros"
; MIGHT STOP FUNCTIONING CORRECTLY 
SSGCNT_macros:
SSGCNT_mix_macro_A:		ControlMacro
SSGCNT_mix_macro_B:		ControlMacro
SSGCNT_mix_macro_C:		ControlMacro
SSGCNT_vol_macro_A: 	ControlMacro 
SSGCNT_vol_macro_B: 	ControlMacro
SSGCNT_vol_macro_C:		ControlMacro
SSGCNT_arp_macro_A: 	ControlMacro 
SSGCNT_arp_macro_B: 	ControlMacro
SSGCNT_arp_macro_C:		ControlMacro
;SSGCNT_noise_macro:	ControlMacro

SSGCNT_wram_end:

; ======== FM ========

FM_wram_start:        
FM_operator_TLs:		ds FM_CHANNEL_COUNT*FM_OP_COUNT ; u8[FM_CH_COUNT][FM_OP_COUNT] (0~127; 127 is lowest, 0 is highest)

FM_ch1: ds FM_Channel.SIZE
FM_ch2: ds FM_Channel.SIZE
FM_ch3: ds FM_Channel.SIZE
FM_ch4: ds FM_Channel.SIZE

FM_wram_end:

; ======== PA ========
PA_wram_start:
PA_channel_volumes:  ds PA_CHANNEL_COUNT
PA_channel_pannings: ds PA_CHANNEL_COUNT
PA_status_register: ds 1	
PA_wram_end:

; ======== FDCNT ========

; ======== Others ========
EXT_2CH_mode:             ds 1 ; u8 (0: 2CH mode off; 64: 2CH mode on)
IRQ_TA_tick_base_time:    ds 1 ; u8
IRQ_TA_tick_time_counter: ds 1 ; u8
current_bank:             ds 1 ; u8
has_a_timer_expired:      ds 1 ; u8 (0 if no timer has expired, else timer has expired)
master_volume:            ds 1 ; u8
do_reset_chvols:          ds 1 ; bool (if this flag is set, MLM_irq will reset all channel volumes and clear the flag)
do_stop_song:             ds 1 ; bool (if this flag is set, MLM_irq will stop the current song and clear the flag)
tmp2:                     ds 2

; ======== SFX Playback System =======
SFXPS_WRAM_start:
SFXPS_adpcma_table: ds 2 ; void*
SFXPS_channel_priorities:      ds PA_CHANNEL_COUNT ; u8[6]
SFXPS_channel_sample_ids:      ;ds PA_CHANNEL_COUNT ; u8[6]
SFXPS_channel_taken_status:    ds 1                ; u8 (%--654321; is ADPCM-A channel 1~6 taken? 1 = yes, 0 = no)
SFXPS_channel_playback_status: ds 1                ; u8 (%--654321; is ADPCM-A channel 1~6 playing? 1 = yes, 0 = no)
SFXPS_WRAM_end:

; ======== Fade system ======== 
FADE_offset: ds 1 ; s8