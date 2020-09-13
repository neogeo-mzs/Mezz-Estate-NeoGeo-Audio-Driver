; RAM defines for Dummy Z80 sound driver

	org $F800

breakpoint: ds 1    ; used for debugging

; ======== General ========
counter: ds 1

; ======== 68K/Z80 communication ========
com_arg_buffer: ds 16 ; u8[16]

; if it's 0 then the driver is waiting for
; a command; if it's 1 then the driver is waiting
; for an argument.
com_loading_arg:       ds 1 ; u8
com_current_arg_index: ds 1 ; u8

com_68k_input:     ds 1 ; u8
com_68k_increment: ds 1 ; u8
com_68k_command:   ds 1 ; u8

; ======== SSG variables ========

; DO NOT CHANGE THE ORDER OF THESE FOUR ARRAYS
; if you add/remove anything from here, you might want to
; edit command_stop_ssg
ssg_vol_macros:          ds 6 ; vol_macro*[3]
ssg_vol_macro_sizes:     ds 3 ; u8[3]
ssg_vol_macro_counters:  ds 3 ; u8[3]
ssg_vol_macro_loop_pos:  ds 3 ; u8[3]
ssg_vol_attenuators: ds 3 ; u8[3]

;ssg_base_notes: ds 3         ; u8[3] Current note, without arpeggio applied

; DO NOT CHANGE THE ORDER OF THESE FOUR ARRAYS
;ssg_arp_macros:         ds 6 ; arp_macro*[3]
;ssg_arp_macro_sizes:    ds 3 ; u8[3]
;ssg_arp_macro_counters: ds 3 ; u8[3]
;ssg_arp_macro_loop_pos: ds 3 ; u8[3]

; ======== FM ========
FM_base_total_levels: ds 4*6 ; u8[6][4]
FM_pannings: ds 6            ; u8[6]

; ======== MLM player ========
MLM_playback_pointers:        ds 2*13 ; void*[13]
MLM_playback_timings:         ds 2*13 ; u16[13]
MLM_playback_set_timings:     ds 2*13 ; u16[13]
MLM_playback_control:         ds 13   ; bool[13]
MLM_event_arg_buffer:         ds 16   ; u8[16]
MLM_channel_instruments:      ds 13   ; u8[13]
MLM_wram_end: