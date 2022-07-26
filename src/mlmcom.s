; commands only need to backup HL, DE and IX unless 
; they set the playback pointer, then they don't
; need to backup anything.
MLM_command_vectors:
	dw MLMCOM_end_of_list,          MLMCOM_note_off
	dw MLMCOM_set_instrument,       MLMCOM_wait_ticks
	dw MLMCOM_invalid,              MLMCOM_set_channel_volume
	dw MLMCOM_set_channel_panning,  MLMCOM_set_master_volume
	dw MLMCOM_set_base_time,        MLMCOM_jump_to_sub_el
	dw MLMCOM_invalid,              MLMCOM_position_jump
	dw MLMCOM_invalid,              MLMCOM_invalid
	dw MLMCOM_invalid,              MLMCOM_invalid
	dup 16
		dw MLMCOM_wait_ticks_nibble
	edup
	dw MLMCOM_return_from_sub_el,   MLMCOM_invalid
	dw MLMCOM_invalid,              MLMCOM_invalid
	dup 4
		dw MLMCOM_FM_TL_set
	edup
	dup 89
		dw MLMCOM_invalid ; Invalid commands
	edup

MLM_command_argc:
	db $00, $01, $01, $01, $00, $01, $01, $01
	db $01, $02, $00, $02, $00, $00, $00, $00
	ds 16, $00 ; Wait ticks nibble
	db $00, $00, $00, $00
	ds 4, $01 ; FM OP TL Set
	ds 89, 0  ; Invalid commands

; c: channel
; iy: pointer to MLM_Channel
MLMCOM_end_of_list:
	xor a,a
	ld (iy+MLM_Channel.flags),a

	; Set timing to 1
	; (This is done to be sure that
	;  the next event won't be executed)
	ld a,c
	ld c,a
	call MLM_set_timing
	ret

; c: channel
; iy: pointer to MLM_Channel
; Arguments:
; 	1. timing
MLMCOM_note_off:
	ld a,c
	call MLM_stop_note
	ld hl,MLM_event_arg_buffer
	ld a,c
	ld b,0
	ld c,(hl)
	call MLM_set_timing
	ret

; c: channel
; iy: pointer to MLM_Channel
; Arguments
;   1. instrument
MLMCOM_set_instrument:
	ld a,(MLM_event_arg_buffer)
	call MLM_set_instrument
	ld a,c
	ld c,0
	call MLM_set_timing
	ret

; c: channel
; iy: pointer to MLM_Channel
; Arguments:
;   1. timing
MLMCOM_wait_ticks:
	ld hl,MLM_event_arg_buffer
	ld a,c
	ld c,(hl)
	call MLM_set_timing
	ret

; c: channel
; iy: pointer to MLM_Channel
; Arguments:
;   1. Volume
MLMCOM_set_channel_volume:
	ld a,(MLM_event_arg_buffer)
	call MLM_set_channel_volume

	; Set timing
	ld a,c
	ld c,0
	call MLM_set_timing
	ret

; c: channel
; iy: pointer to MLM_Channel
; Arguments:
;   1. %LRTTTTTT (Left on; Right on; Timing)
MLMCOM_set_channel_panning:
	; Load panning into c
	ld a,(MLM_event_arg_buffer)
	and a,%11000000
	ld b,a ; \
	ld a,c ;  |- Swap a and c sacrificing b
	ld c,b ; /

	call MLM_set_channel_panning

	ld b,a ; backup channel in b
	ld a,(MLM_event_arg_buffer)
	and a,%00111111 ; Get timing
	ld c,a
	ld a,b
	call MLM_set_timing
	ret

; c: channel
; iy: pointer to MLM_Channel
; Arguments:
;   1. %VVVVVVTT (Volume; Timing MSB)
MLMCOM_set_master_volume:
	; Set master volume
	ld a,(MLM_event_arg_buffer)
	srl a ; %VVVVVV-- -> %-VVVVVV-
	srl a ; %-VVVVVV- -> %--VVVVVV
	ld d,REG_PA_MVOL
	ld e,a
	rst RST_YM_WRITEB

	; Set timing
	ld a,(MLM_event_arg_buffer)
	and a,%00000011
	ld b,a ; backup timing
	ld a,c
	ld c,b
	call MLM_set_timing
	ret

; c: channel
; iy: pointer to MLM_Channel
; Arguments:
;   1. %BBBBBBBB (Base time)
MLMCOM_set_base_time:
	; Set base time
	ld a,(MLM_event_arg_buffer)
	ld (IRQ_TA_tick_base_time),a

	; Set timing
	ld a,c
	ld bc,0
	call MLM_set_timing
	ret

; c: channel
; iy: pointer to MLM_Channel
; Arguments:
;	1. %AAAAAAAA (Address LSB)
;	2. %AAAAAAAA (Address MSB)
MLMCOM_jump_to_sub_el:
	ld hl,(iy+MLM_Channel.playback_ptr)
	ld (iy+MLM_Channel.return_ptr),hl

	; Load address to jump to in de
	ld hl,MLM_event_arg_buffer
	ld e,(hl)
	inc hl
	ld d,(hl)

	; Add MLM_HEADER ($4000) to it 
	; to obtain the actual address
	; and store it in WRAM
	ld hl,MLM_HEADER
	add hl,de
	ld (iy+MLM_Channel.playback_ptr),hl

	; Set timing to 0
	; (Execute next command immediately)
	ld a,c
	ld c,0
	call MLM_set_timing
	ret

; c:  channel
; ix: $MLM_playback_pointers[channel]+1
; de: source (playback pointer)
; iy: pointer to MLM_Channel
; Arguments:
;   1. %AAAAAAAA (Address LSB)
;   2. %AAAAAAAA (Address MSB)
MLMCOM_position_jump:
	ld hl,MLM_event_arg_buffer

	; Load offset into bc, add MLM header 
	; offset to obtain the physical 
	; address and save it in WRAM
	ld a,c ; Backup channel into a
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld hl,MLM_HEADER
	add hl,bc
	ld (iy+MLM_Channel.playback_ptr),hl

	; Set timing to 0
	ld c,0
	call MLM_set_timing
	ret

; c: channel
; iy: pointer to MLM_Channel
; Arguments:
;   1. %AAAAAAAA (timer A MSB) 
;   2. %TTTTTTAA (Timing; timer A LSB)
MLMCOM_set_timer_a:
	ld e,c ; backup channel in e

	; Set timer a counter load
	ld d,REG_TMA_COUNTER_MSB
	ld a,(MLM_event_arg_buffer)
	ld e,a
	rst RST_YM_WRITEA
	inc d
	ld a,(MLM_event_arg_buffer+1)
	ld e,a
	rst RST_YM_WRITEA
	ld de,REG_TIMER_CNT<<8 | %10101
	RST RST_YM_WRITEA

	ld a,(MLM_event_arg_buffer+1)
	srl a
	srl a
	ld c,a
	ld a,e
	call MLM_set_timing
	ret

; c: channel
; de: playback pointer
; iy: pointer to MLM_Channel
MLMCOM_wait_ticks_nibble:
	; Load command ($1T) in a
	ld hl,(iy+MLM_Channel.playback_ptr)
	dec hl ; com[n].src == com[n+1].src - com[n].argc
	ld a,(hl)
	ld l,c ; backup channel

	and a,$0F ; get timing
	ld c,a
	ld a,l
	inc c ; 0~15 -> 1~16
	call MLM_set_timing
	ret

; c: channel
; iy: pointer to MLM_Channel
MLMCOM_return_from_sub_el:
	; Load playback pointer in WRAM
	; and store it into MLM_playback_pointers[channel]
	ld hl,(iy+MLM_Channel.return_ptr)
	ld (iy+MLM_Channel.playback_ptr),hl

	; Set timing to 0
	; (Execute next command immediately)
	ld a,c
	ld c,0
	call MLM_set_timing
	ret

; c: channel
; de: playback pointer
; iy: pointer to MLM_Channel
MLMCOM_FM_TL_set:
	; Set timing to 0
	push bc
		ld a,c
		ld c,0
		call MLM_set_timing
	pop bc

	cp a,MLM_CH_FM1 ; if a < MLM_CH_FM1 (channel is ADPCMA)
	ret c

	cp a,MLM_CH_SSG1 ; if a >= MLM_CH_SSG1 (channel is SSG)
	ret nc

	; Else... (Channel is FM)
	; Correctly offset FM channel (6~9 -> 0~3)
	sub a,MLM_CH_FM1
	ld c,a

	; Get operator to set
	ld hl,(iy+MLM_Channel.playback_ptr)
	dec hl ; - com[n].src == com[n+1].src - com[n].argc
	dec hl ; /
	ld a,(hl)
	and a,%00000011

	; Calculate FM OP TL Set address
	ld hl,FM_operator_TLs
	ld e,a
	ld d,0
	add hl,de
	ld a,c
	rlca ; - a *= 4
	rlca ; / 
	ld e,a
	add hl,de

	; Set FM OP TL
	ld a,(MLM_event_arg_buffer)
	and a,$7F
	ld (hl),a

	; Calculate address to FM channel flag
	; and set the volume (and TL) update flag
	; (change if FM_Channel.SIZE isn't 16)
	ld a,c
	rlca ; -\
	rlca ;  | a *= 16
	rlca ;  /
	rlca ; /
	ld e,a
	ld hl,FM_ch1+FM_Channel.enable
	add hl,de
	ld a,(hl)
	or a,FMCNT_VOL_UPDATE
	ld (hl),a
	ret 

; invalid command, plays a noisy beep
; and softlocks the driver
MLMCOM_invalid:
	call softlock