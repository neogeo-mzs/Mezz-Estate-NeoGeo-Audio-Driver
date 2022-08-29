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

MLM_channels:          ds MLM_Channel.SIZE*CHANNEL_COUNT

MLM_event_arg_buffer:  ds 32                  ; u8[32]
MLM_active_ch_counter: ds 1                   ; u8
MLM_instruments:       ds 2                   ; void*
MLM_wram_end:

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

; ======== Others ========
EXT_2CH_mode:             ds 1 ; u8 (0: 2CH mode off; 64: 2CH mode on)
IRQ_TA_tick_base_time:    ds 1 ; u8
IRQ_TA_tick_time_counter: ds 1 ; u8
current_bank:             ds 1 ; u8
master_volume:            ds 1 ; u8
do_reset_chvols:          ds 1 ; bool (if this flag is set, MLM_irq will reset all channel volumes and clear the flag)
do_stop_song:             ds 1 ; bool (if this flag is set, MLM_irq will stop the current song and clear the flag)
SSG_inst_mix_flags:    	  ds 1 ; u8 (Contains the mix flags defined by SSG instruments)
SSG_mix_flags_buffer:     ds 1 ; u8 (Actual mix flag buffer)
is_tma_triggered:         ds 1 ; bool
is_tmb_triggered:         ds 1 ; bool
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