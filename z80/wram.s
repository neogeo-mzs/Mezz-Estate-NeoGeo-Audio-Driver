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
MLM_event_arg_buffer:         ds 32                  ; u8[16]
MLM_channel_instruments:      ds CHANNEL_COUNT       ; u8[13]
MLM_channel_pannings:         ds CHANNEL_COUNT       ; u8[13]
MLM_channel_volumes:          ds CHANNEL_COUNT       ; u8[13]
MLM_base_time:                ds 1                   ; u8
MLM_base_time_counter:        ds 1                   ; u8
MLM_wram_end:

; ======== SSG variables ========
; DO NOT CHANGE THE ORDER OF THESE FOUR ARRAYS
; if you add/remove anything from here, you might want to
; edit command_stop_ssg
ssg_vol_macros:          ds 6 ; vol_macro*[3]
ssg_vol_macro_sizes:     ds 3 ; u8[3]
ssg_vol_macro_counters:  ds 3 ; u8[3]
ssg_vol_macro_loop_pos:  ds 3 ; u8[3]
ssg_vol_attenuators:     ds 3 ; u8[3]
ssg_mix_enable_flags:    ds 1 ; u8

;ssg_base_notes: ds 3         ; u8[3] Current note, without arpeggio applied

; DO NOT CHANGE THE ORDER OF THESE FOUR ARRAYS
;ssg_arp_macros:         ds 6 ; arp_macro*[3]
;ssg_arp_macro_sizes:    ds 3 ; u8[3]
;ssg_arp_macro_counters: ds 3 ; u8[3]
;ssg_arp_macro_loop_pos: ds 3 ; u8[3]

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