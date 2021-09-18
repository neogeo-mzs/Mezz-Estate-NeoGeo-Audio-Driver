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
MLM_playback_control:         ds CHANNEL_COUNT       ; bool[13] \
MLM_playback_timings:         ds CHANNEL_COUNT       ; u8[13]   | KEEP THIS THREE TOGETHER. 'MLM_update_channel_playback' ASSUMES THIS ORDER
MLM_playback_set_timings:     ds CHANNEL_COUNT       ; u8[13]   /
MLM_event_arg_buffer:         ds 32                  ; u8[32]
MLM_channel_instruments:      ds CHANNEL_COUNT       ; u8[13]
MLM_channel_pannings:         ds CHANNEL_COUNT       ; u8[13]
MLM_channel_volumes:          ds CHANNEL_COUNT       ; u8[13]
MLM_base_time:                ds 1                   ; u8
MLM_base_time_counter:        ds 1                   ; u8
MLM_sub_el_return_pointers:   ds 2*CHANNEL_COUNT     ; void*[13]
MLM_instruments:              ds 2                   ; void* 
MLM_wram_end:

; ======== SSG Controller variables ========
SSGCNT_wram_start:
SSGCNT_volumes:			ds 3 ; u8[3]
SSGCNT_mix_flags:    	ds 1 ; u8 (Buffer for the YM2610's $07 Port A register)
SSGCNT_noise_tune:		ds 1 ; u8
SSGCNT_channel_enable:	ds 3 ; bool[3]
SSGCNT_notes:			ds 3 ; u8[3]

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
FM_channel_lramspms:	ds FM_CHANNEL_COUNT             ; u8[4] (LRAA-PPP; Left & Right, Ams, Pms)
FM_channel_op_enable:	ds FM_CHANNEL_COUNT             ; u8[4] (4321----; op 4 enable; op 3 enable; op 2 enable; op 1 enable)
FM_channel_frequencies: ds FM_CHANNEL_COUNT*2           ; u16[4] (--BBBFFF'FFFFFFFF; Block, F-Num 2 & 1)
FM_operator_TLs:		ds FM_CHANNEL_COUNT*FM_OP_COUNT ; u8[FM_CH_COUNT][FM_OP_COUNT] (0~127; 127 is lowest, 0 is highest)
FM_channel_volumes:		ds FM_CHANNEL_COUNT             ; u8[4] (127 is lowest, 0 is highest)
FM_channel_key_on:		ds FM_CHANNEL_COUNT             ; bool[4] (If it isn't 0, then the channel will be played next IRQ and the value will be cleared)
FM_channel_enable:      ds FM_CHANNEL_COUNT             ; bool[4] (If it's 0, then the channel won't be touched by the FM IRQ routine)
FM_channel_algos:       ds FM_CHANNEL_COUNT             ; u8[4]
FM_wram_end:

; ======== PA ========
PA_wram_start:
PA_channel_volumes:  ds PA_CHANNEL_COUNT
PA_channel_pannings: ds PA_CHANNEL_COUNT	
PA_wram_end:

; ======== IRQ ========
IRQ_buffer:                   ds 2*IRQ_BUFFER_LENGTH ; u16[IRQ_BUFFER_LENGTH]
IRQ_buffer_idx_w:             ds 1                   ; u8
IRQ_buffer_idx_r:             ds 1                   ; u8

; ======== SFX Playback System =======
SFXPS_WRAM_start:
SFXPS_adpcma_table: ds 2 ; void*
SFXPS_channel_statuses: ds PA_CHANNEL_COUNT ; u8[6] ($00: free, $01: busy playing sfx, $02: taken for music playback)
SFXPS_channel_priorities: ds PA_CHANNEL_COUNT ; u[6]
SFXPS_WRAM_end:

; ======== Others ========
EXT_2CH_mode: ds 1 ; u8 (0: 2CH mode off; 64: 2CH mode on)