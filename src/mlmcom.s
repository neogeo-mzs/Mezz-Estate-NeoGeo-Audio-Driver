; commands only need to backup HL, DE and IX unless 
; they set the playback pointer, then they don't
; need to backup anything.
MLM_command_vectors:
	dw MLMCOM_end_of_list,          MLMCOM_note_off
	dw MLMCOM_set_instrument,       MLMCOM_wait_ticks_byte
	dw MLMCOM_wait_ticks_word,      MLMCOM_set_channel_volume
	dw MLMCOM_set_channel_panning,  MLMCOM_set_master_volume
	dw MLMCOM_set_base_time,        MLMCOM_jump_to_sub_el
	dw MLMCOM_small_position_jump,  MLMCOM_big_position_jump
	dw MLMCOM_pitch_slide_clamped,  MLMCOM_porta_write
	dw MLMCOM_portb_write,          MLMCOM_set_timer_a
	dup 16
		dw MLMCOM_wait_ticks_nibble
	edup
	dw MLMCOM_return_from_sub_el,   MLMCOM_upward_pitch_slide
	dw MLMCOM_downward_pitch_slide, MLMCOM_reset_pitch_slide
	dup 4
		dw MLMCOM_FM_TL_set
	edup
	dw MLMCOM_set_pitch_macro,      MLMCOM_set_note
	dup 8
		dw MLMCOM_invalid ; Invalid commands
	edup
	dup 16
		dw MLMCOM_set_channel_volume_byte
	edup
	dup 64
		dw MLMCOM_invalid ; Invalid commands
	edup

MLM_command_argc:
	db $00, $01, $01, $01, $02, $01, $01, $01
	db $01, $02, $01, $02, $02, $02, $02, $02
	ds 16, $00 ; Wait ticks nibble
	db $00, $01, $01, $00
	ds 4, $01 ; FM OP TL Set
	db $02, $01
	ds 8, 0   ; Invalid commands have no arguments
	ds 16, 0   ; Set Channel Volume (byte sized)
	ds 64, 0   ; Invalid commands have no arguments

; c: channel
MLMCOM_end_of_list:
	push hl
	push de
		; Clear all channel playback control flags
		ld h,0
		ld l,c
		ld de,MLM_channel_control
		add hl,de
		ld (hl),0

		; Set timing to 1
		; (This is done to be sure that
		;  the next event won't be executed)
		ld a,c
		ld bc,1
		call MLM_set_timing
	pop de
	pop hl
	jp MLM_parse_command_end

; c: channel
; Arguments:
; 	1. timing
MLMCOM_note_off:
	push hl
		ld a,c
		call MLM_stop_note
		ld hl,MLM_event_arg_buffer
		ld a,c
		ld b,0
		ld c,(hl)
		call MLM_set_timing
	pop hl
	jp MLM_parse_command_end

; c: channel
; Arguments
;   1. instrument
MLMCOM_set_instrument:
	ld a,(MLM_event_arg_buffer)
	call MLM_set_instrument
	ld a,c
	ld bc,0
	call MLM_set_timing
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. timing
MLMCOM_wait_ticks_byte:
	push hl
		ld hl,MLM_event_arg_buffer
		ld a,c
		ld b,0
		ld c,(hl)
		inc bc
		call MLM_set_timing
	pop hl
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. timing (LSB)
;   2. timing (MSB)
MLMCOM_wait_ticks_word:
	jp softlock
	push hl
	push ix
		ld ix,MLM_event_arg_buffer
		ld a,c
		ld b,(ix+1)
		ld c,(ix+0)
		call MLM_set_timing
	pop ix
	pop hl
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. Volume
MLMCOM_set_channel_volume:
	push hl
	push de
		ld a,(MLM_event_arg_buffer)
		call MLM_set_channel_volume

		; Set timing
		ld a,c
		ld bc,0
		call MLM_set_timing
	pop de
	pop hl
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. %LRTTTTTT (Left on; Right on; Timing)
MLMCOM_set_channel_panning:
	push hl
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
		ld b,0
		call MLM_set_timing
	pop hl
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. %VVVVVVTT (Volume; Timing MSB)
MLMCOM_set_master_volume:
	push de
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
		ld b,a
		ld a,c
		ld c,b
		ld b,0
		call MLM_set_timing
	pop de
	jp MLM_parse_command_end

; c: channel
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
	jp MLM_parse_command_end

; c: channel
; ix: $MLM_playback_pointers[channel]+1
; de: source (playback pointer; points to next command)
; Arguments:
;	1. %AAAAAAAA (Address LSB)
;	2. %AAAAAAAA (Address MSB)
MLMCOM_jump_to_sub_el:
	; Store playback pointer in WRAM
	ld b,0
	ld hl,MLM_sub_el_return_pointers
	add hl,bc
	add hl,bc
	ld (hl),e
	inc hl
	ld (hl),d

	; Load address to jump to in de
	ld hl,MLM_event_arg_buffer
	ld e,(hl)
	inc hl
	ld d,(hl)

	; Add MLM_HEADER ($4000) to it 
	; to obtain the actual address
	ld hl,MLM_HEADER
	add hl,de

	; Store the actual address in WRAM
	ld (ix-1),l
	ld (ix-0),h

	; Set timing to 0
	; (Execute next command immediately)
	ld a,c
	ld bc,0
	call MLM_set_timing
	jp MLM_parse_command_end_skip_playback_pointer_set

; c:  channel
; ix: $MLM_playback_pointers[channel]+1
; de: source (playback pointer)
; Arguments:
;   1. %OOOOOOOO (Offset)
MLMCOM_small_position_jump:
	ld hl,MLM_event_arg_buffer

	; Load offset and sign extend 
	; it to 16bit (result in bc)
	ld a,(hl)
	ld l,c     ; Backup channel into l
	call AtoBCextendendsign

	; Add offset to playback 
	; pointer and store it into 
	; MLM_playback_pointers[channel]
	ld a,l ; Backup channel into a
	ld l,e
	ld h,d
	add hl,bc
	ld (ix-1),l
	ld (ix-0),h

	; Set timing to 0
	ld bc,0
	call MLM_set_timing
	jp MLM_parse_command_end_skip_playback_pointer_set

; c:  channel
; ix: $MLM_playback_pointers[channel]+1
; de: source (playback pointer)
; Arguments:
;   1. %AAAAAAAA (Address LSB)
;   2. %AAAAAAAA (Address MSB)
MLMCOM_big_position_jump:
	ld hl,MLM_event_arg_buffer

	; Load offset into bc
	ld a,c ; Backup channel into a
	ld c,(hl)
	inc hl
	ld b,(hl)

	; Add MLM header offset to 
	; obtain the actual address
	ld hl,MLM_HEADER
	add hl,bc
	ld (ix-1),l
	ld (ix-0),h

	; Set timing to 0
	ld bc,0
	call MLM_set_timing
	jp MLM_parse_command_end_skip_playback_pointer_set

; c: channel
; Arguments:
;   1. %OOOOOOOO (Unsigned pitch offset per tick) 
;   2. %-NNNNNNN (Note)
MLMCOM_pitch_slide_clamped:
	; Set timing to 0
	ld a,c
	ld bc,0
	call MLM_set_timing

	; Currently pitch slides are handled by two
	; different controllers (FMCNT and SSGCNT),
	; so two different routines have to be made.
	cp a,MLM_CH_FM1 ; if ch is ADPCMA, return (ADPCMA has no pitch)
	jp c,MLM_parse_command_end
	
	push hl
	push de
	push ix
		cp a,MLM_CH_SSG1 ; if ch is FM, setup clamped pitch slide for FMCNT...
		jp c,channel_is_fm$
		
		; Else (ch is SSG), setup clamped 
		; pitch slide for SSGCNT...
		sub a,MLM_CH_SSG1
		call SSGCNT_set_buffered_note

		; Get the current note, and from it 
		; get the channel's current pitch
		ld c,a ; load channel back in a
		ld hl,SSGCNT_notes
		ld e,a
		ld d,b ; b is currently equal to 0
		add hl,de
		ld l,(hl)
		call SSGCNT_get_pitch_from_note

		; Load note and store it in WRAM, then 
		; get its pitch and store it in hl and ix
		ld a,(MLM_event_arg_buffer+1)
		push de
			ld hl,SSGCNT_buffered_note
			ld e,c
			ld d,0
			add hl,de
			ld (hl),a

			ld l,a
			call SSGCNT_get_pitch_from_note
			ld ix,de
			ex hl,de
		pop de

		; compare pitch limit to the 
		; base pitch, and if the limit is lower 
		; than the base, set the carry flag.
		; (if it's equal or higher, clear it)
		or a,a
		sbc hl,de
		add hl,de

		; Load pitch offset in de; if 
		; limit < base (carry is set),
		; negate the pitch offset
		ld a,(MLM_event_arg_buffer+0)
		ld e,a
		ld b,64 ; if limit >= base set b to 64
		ld d,0
		jp nc,ssg_skip_negate$ ; if limit >= base (carry not set), skip negate

		ld b,0 ; if limit < base set b to 0
		ld hl,0
		or a,a ; clear carry flag
		sbc hl,de
		ex hl,de
ssg_skip_negate$:
		; Calculate address to pslide offset in WRAM,
		; then store the new pslide offset in it.
		push de
			ld a,c
			sla a ; a *= 2
			ld e,a
			ld d,0
			ld hl,SSGCNT_pitch_slide_ofs
			add hl,de
		pop de
		ld (hl),e
		inc hl
		ld (hl),d

		; Load limit from ix
		; and set its 15th bit;
		; additionally, if limit >= base, 
		; set its 14th bit 
		ld a,ixl
		ld l,a
		ld a,ixh
		or a,128
		or a,b ; if limit >= base: b = 64, else b = 0; thus is limit >= base the 14th bit gets set.
		ld h,a
		ld de,hl

		; Calculate address to pitch slide clamp
		; in WRAM and load pslide clamp to it.
		push de
			ld a,c
			sla a ; a *= 2
			ld e,a
			ld d,0
			ld hl,SSGCNT_pitch_slide_clamp
			add hl,de
		pop de
		ld (hl),e
		inc hl
		ld (hl),d
	pop ix
	pop de
	pop hl
	jp MLM_parse_command_end

channel_is_fm$:
		push iy
			; Calculate address to 
			; FMCNT channel WRAM data
			ld ix,FM_ch1-(MLM_CH_FM1*FM_Channel.SIZE)
			ld c,a ; backup channel in c
			or a,a ; clear carry
			rla ; -\
			rla ;  | a *= 16 (when multiplicand < 16)
			rla ;  /
			rla ; /
			ld e,a
			ld d,0
			add ix,de

			; Set buffered note
			ld a,(ix+FM_Channel.bufrd_note)
			ld iyh,a
			ld a,c
			sub a,MLM_CH_FM1
			ld iyl,a
			call FMCNT_set_note

			; Store destination note in WRAM buffer
			ld a,(MLM_event_arg_buffer+1)
			ld (ix+FM_Channel.bufrd_note),a

			; Store current frequency's block in e
			ld a,(ix+FM_Channel.frequency+1)
			and a,%00111000
			rrca ; \
			rrca ; | 00BBB000 >> 00000BBB
			rrca ; /
			ld e,a

			; Compare pitch limit to channel's
			; pitch, if the limit is lower than
			; the base, set the carry flag.
			; (if it's equal or higher, clear it)
			ld a,(MLM_event_arg_buffer+1)
			ld d,a
			call FMCNT_get_note_with_block
			ld a,l
			ld iyl,a
			ld a,h
			ld iyh,a
			ld e,(ix+FM_Channel.frequency+0)
			ld a,(ix+FM_Channel.frequency+1)
			ld d,a
			or a,a
			sbc hl,de

			; Load pitch offset in de; if
			; limit < base (carry is set)
			; negate the pitch offset
			ld a,(MLM_event_arg_buffer+0)
			ld e,a
			ld b,64 ; if limit >= base set b to 64
			ld d,0
			jp nc,fm_skip_negate$ ; if limit >= base (carry not set), skip negate

			ld b,0 ; if limit < base set b to 0
			ld hl,0
			or a,a ; clear carry flag
			sbc hl,de
			ex hl,de
fm_skip_negate$:
			; Store pitch slide offset in WRAM
			ld (ix+FM_Channel.pslide_ofs+0),e
			ld (ix+FM_Channel.pslide_ofs+1),d

			; Load limit from argument buffer
			; and set its 15th bit;
			; additionally, if limit >= base, 
			; set its 14th bit 
			ld a,iyl
			ld l,a
			ld a,iyh
			or a,128
			or a,b ; if limit >= base: b = 64, else b = 0; thus is limit >= base the 14th bit gets set.
			ld h,a
			ex hl,de

			; Store pitch slide clamp in WRAM
			ld (ix+FM_Channel.fnum_clamp+0),e
			ld (ix+FM_Channel.fnum_clamp+1),d
		pop iy
	pop ix
	pop de
	pop hl
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. %AAAAAAAA (Address)
;   2. %DDDDDDDD (Data)
MLMCOM_porta_write:
	push de
		ld a,(MLM_event_arg_buffer)
		ld d,a
		ld a,(MLM_event_arg_buffer+1)
		ld e,a
		rst RST_YM_WRITEA

		ld a,c
		ld bc,0
		call MLM_set_timing

		; If address isn't equal to 
		; REG_TIMER_CNT return
		ld a,d
		cp a,REG_TIMER_CNT
		jr nz,return$

		; If address is equal to $27, then
		; store the data's 7th bit in WRAM
		ld a,e
		and a,%01000000 ; bit 6 enables 2CH mode
		ld (EXT_2CH_mode),a
		
return$:
	pop de
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. %AAAAAAAA (Address)
;   2. %DDDDDDDD (Data)
MLMCOM_portb_write:
	push de
		ld a,(MLM_event_arg_buffer)
		ld d,a
		ld a,(MLM_event_arg_buffer+1)
		ld e,a
		rst RST_YM_WRITEB

		ld a,c
		ld bc,0
		call MLM_set_timing
	pop de
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. %AAAAAAAA (timer A MSB) 
;   2. %TTTTTTAA (Timing; timer A LSB)
MLMCOM_set_timer_a:
	push de
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

		ld b,0
		ld a,(MLM_event_arg_buffer+1)
		srl a
		srl a
		ld c,a
		ld a,e
		call MLM_set_timing
	pop de
	jp MLM_parse_command_end

; c: channel
; de: playback pointer
MLMCOM_wait_ticks_nibble:
	push hl
		; Load command ($1T) in a
		ld h,d
		ld l,e
		dec hl
		ld a,(hl)
		ld l,c ; backup channel

		and a,$0F ; get timing
		ld c,a
		ld b,0
		ld a,l
		inc c ; 0~15 -> 1~16
		call MLM_set_timing
	pop hl
	jp MLM_parse_command_end

; c: channel
; ix: $MLM_playback_pointers[channel]+1
; de: source (playback pointer)
MLMCOM_return_from_sub_el:
	; Load playback pointer in WRAM
	; and store it into MLM_playback_pointers[channel]
	ld b,0
	ld hl,MLM_sub_el_return_pointers
	add hl,bc
	add hl,bc
	ld a,(hl)   ; - Load and store address LSB
	ld (ix-1),a ; /
	inc hl		; \
	ld a,(hl)   ; | Load and store address MSB
	ld (ix-0),a ; /

	; Set timing to 0
	; (Execute next command immediately)
	ld a,c
	ld bc,0
	call MLM_set_timing
	jp MLM_parse_command_end_skip_playback_pointer_set

; c: channel
MLMCOM_upward_pitch_slide:
	; disable channel's pitch macro
	push hl
	push bc
		; Calculate address to pitch macro enable
		ld hl,MLM_channel_pitch_macros+ControlMacro.enable
		ld a,c
		sla a ; -\
		sla a ;  | a *= 16
		sla a ;  /
		sla a ; /
		ld c,a
		ld b,0
		add hl,bc

		xor a,a ; clear a
		ld (hl),a
	pop bc
	pop hl

	; ADPCM-A channels have no pitch, just set timing and return.
	ld a,c 
	cp a,MLM_CH_FM1
	jp c,channel_is_adpcma$

	; Else if FM, update FMCNT accordingly
	cp a,MLM_CH_SSG1
	jp c,channel_is_fm$
	
	; Else, update SSGCNT...
	push hl
	push de
		ld a,(MLM_event_arg_buffer) ; Load pitch offset per tick in a

		; Convert 8bit ofs to a negative
		; 16bit ofs, then store it into de
		; (The lower the tune value is, 
		; the higher the pitch)
		xor a,$FF
		ld l,a
		ld h,$FF
		inc hl
		ex hl,de

		; Store pitch offset per tick in WRAM
		ld hl,SSGCNT_pitch_slide_ofs-(MLM_CH_SSG1*2)
		ld b,0
		add hl,bc
		add hl,bc
		ld (hl),e
		inc hl
		ld (hl),d

		; Disable custom clamp limits
		ld hl,SSGCNT_pitch_slide_clamp-(MLM_CH_SSG1*2)+1
		add hl,bc
		add hl,bc
		xor a,a
		ld (hl),a ; clears enable flag

		; Set timing to 0
		; (Execute next command immediately)
		ld a,c
		ld bc,0
		call MLM_set_timing
	pop de
	pop hl
	jp MLM_parse_command_end

channel_is_adpcma$:
	; Set timing to 0
	; (Execute next command immediately)
	push af
		ld a,c
		ld bc,0
	pop af
	call MLM_set_timing
	jp MLM_parse_command_end

channel_is_fm$:
	push hl
	push de
		; Calculate address to FMCNT
		; channel's pitch slide offset
		ld a,c
		rlca
		rlca
		rlca
		rlca
		ld e,a
		ld d,0

		; Disable custom fnum clamp
		ld hl,FM_ch1+FM_Channel.fnum_clamp+1-(MLM_CH_FM1*16)
		add hl,de
		ld (hl),d ; clears enable flag

		ld hl,FM_ch1+FM_Channel.pslide_ofs-(MLM_CH_FM1*16)
		add hl,de

		; Sets pitch slide offset
		ld a,(MLM_event_arg_buffer) ; Load pitch offset per tick in a
		ld (hl),a
		inc hl
		ld (hl),0

		; Set timing to 0
		; (Execute next command immediately)
		ld a,c
		ld bc,0
		call MLM_set_timing
	pop de
	pop hl
	jp MLM_parse_command_end

; c: channel
MLMCOM_downward_pitch_slide:
	; disable channel's pitch macro
	push hl
	push bc
		; Calculate address to pitch macro enable
		ld hl,MLM_channel_pitch_macros+ControlMacro.enable
		ld a,c
		sla a ; -\
		sla a ;  | a *= 16
		sla a ;  /
		sla a ; /
		ld c,a
		ld b,0
		add hl,bc

		xor a,a ; clear a
		ld (hl),a
	pop bc
	pop hl

	; ADPCM-A channels have no pitch, return
	ld a,c
	cp a,MLM_CH_FM1
	jp c,channel_is_adpcma$

	; Else if FM, update FMCNT accordingly
	cp a,MLM_CH_SSG1
	jp c,channel_is_fm$

	; Else, update SSGCNT...
	push hl
		ld a,(MLM_event_arg_buffer) ; Load pitch offset per tick in a
		
		; Store pitch offset per tick in WRAM
		ld hl,SSGCNT_pitch_slide_ofs-(MLM_CH_SSG1*2)
		ld b,0
		add hl,bc
		add hl,bc
		ld (hl),a
		inc hl
		ld (hl),0

		; Disable custom clamp limits
		ld hl,SSGCNT_pitch_slide_clamp-(MLM_CH_SSG1*2)+1
		add hl,bc
		add hl,bc
		xor a,a
		ld (hl),a ; clears enable flag

		; Set timing to 0
		; (Execute next command immediately)
		ld a,c
		ld bc,0
		call MLM_set_timing
	pop hl
	jp MLM_parse_command_end

channel_is_adpcma$:
	; Set timing to 0
	; (Execute next command immediately)
	push af
		ld a,c
		ld bc,0
	pop af
	call MLM_set_timing
	jp MLM_parse_command_end
    
channel_is_fm$:
	push hl
	push de
		; Convert 8bit ofs to a negative 
		; 16bit ofs, then store it into de
		ld a,(MLM_event_arg_buffer) ; Load pitch offset per tick in a
		xor a,$FF
		ld l,a
		ld h,$FF
		inc hl
		ex hl,de
		
		; Calculate address to FMCNT
		; channel's pitch slide offset
		push de
			ld a,c
			rlca
			rlca
			rlca
			rlca
			ld e,a
			ld d,0

			; Disable custom fnum clamp
			ld hl,FM_ch1+FM_Channel.fnum_clamp+1-(MLM_CH_FM1*16)
			add hl,de
			ld (hl),d ; clears enable flag

			ld hl,FM_ch1+FM_Channel.pslide_ofs-(MLM_CH_FM1*16)
			add hl,de
		pop de

		; Sets pitch slide offset
		ld (hl),e
		inc hl
		ld (hl),d

		; Set timing to 0
		; (Execute next command immediately)
		ld a,c
		ld bc,0
		call MLM_set_timing
	pop de
	pop hl
	jp MLM_parse_command_end

; c: channel
MLMCOM_reset_pitch_slide:
	; Set timing to 0
	; (Execute next command immediately)
	push bc
		ld a,c
		ld bc,0
		call MLM_set_timing
	pop bc

	; ADPCM-A channels have no pitch, return
	ld a,c
	cp a,MLM_CH_FM1
	jp c,MLM_parse_command_end

	; Else if FM, update FMCNT accordingly
	cp a,MLM_CH_SSG1
	jp c,channel_is_fm$

	; Else, update SSGCNT...
	push hl
		; Clear pitch slide offset
		ld hl,SSGCNT_pitch_slide_ofs-(MLM_CH_SSG1*2)
		ld b,0
		add hl,bc
		add hl,bc
		ld (hl),b
		inc hl
		ld (hl),b
	pop hl
	jp MLM_parse_command_end

channel_is_fm$:
	push hl
		; Clear pitch slide offset
		push bc
			ld h,0
			ld l,c
			ld bc,FM_ch1+FM_Channel.pslide_ofs-(MLM_CH_FM1*16)
			add hl,hl
			add hl,hl
			add hl,hl
			add hl,hl
			add hl,bc
		pop bc
		xor a,a ; ld a,0
		ld (hl),0
		inc hl
		ld (hl),0
	pop hl
	jp MLM_parse_command_end

; c: channel
; de: playback pointer
MLMCOM_FM_TL_set:
	; Set timing to 0
	push bc
		ld a,c
		ld bc,0
		call MLM_set_timing
	pop bc

	cp a,MLM_CH_FM1 ; if a < MLM_CH_FM1 (channel is ADPCMA)
	jp c,MLM_parse_command_end 

	cp a,MLM_CH_SSG1 ; if a >= MLM_CH_SSG1 (channel is SSG)
	jp nc,MLM_parse_command_end

	; Else... (Channel is FM)
	push hl
	push de
		; Correctly offset FM channel (6~9 -> 0~3)
		sub a,MLM_CH_FM1
		ld c,a

		; Get operator to set
		ex hl,de
		dec hl
		dec hl
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
	pop de
	pop hl
	jp MLM_parse_command_end 

; c: channel
MLMCOM_set_pitch_macro:
	;ld a,c
	;ld bc,0
	;call MLM_set_timing
	;jp MLM_parse_command_end 
	
	push hl
	push de
	push ix
		; Load pointer to macro init. data in hl
		; and if it's 0, go to reset macro routine
		ld a,(MLM_event_arg_buffer)
		ld l,a
		ld a,(MLM_event_arg_buffer+1)
		ld h,a
		ld de,0
		or a,a ; reset carry flag
		sbc hl,de ; if hl == 0
		jp z,reset$

		; Else...
		; calculate data's physical address
		ld de,MLM_HEADER
		add hl,de
		
		; Calculate address to macro in WRAM
		; (works because ControlMacro.SIZE is 8)
		ld ix,MLM_channel_pitch_macros
		ld a,c
		sla a ; \
		sla a ; | a *= 8
		sla a ; /
		ld e,a
		ld d,0
		add ix,de
		
		call MACRO_set
		
		ld a,c
		ld bc,0
		call MLM_set_timing
	pop ix
	pop de
	pop hl
	jp MLM_parse_command_end 

reset$:
		; Calculate address to macro in WRAM
		; (works because ControlMacro.SIZE is 8)
		ld ix,MLM_channel_pitch_macros
		ld a,c
		sla a ; \
		sla a ; | a *= 8
		sla a ; /
		ld e,a
		ld d,0
		add ix,de

		; Disable macro
		xor a,a
		ld (ix+ControlMacro.enable),a
		call MLM_reset_pitch_ofs

		ld a,c
		ld bc,0
		call MLM_set_timing
	pop ix
	pop de
	pop hl
	jp MLM_parse_command_end 

; c: channel
; Arguments:
;   1. %-NNNNNNN
MLMCOM_set_note:
	; Set timing to 0
	ld a,c
	ld bc,0
	call MLM_set_timing

	ld c,a ; store channel back in c
	cp a,MLM_CH_FM1 ; if a < MLM_CH_FM1 (channel is ADPCMA)
	jp c,MLM_parse_command_end 

	cp a,MLM_CH_SSG1 ; if a < MLM_CH_SSG1 (channel is SSG)
	jp c,channel_is_fm$

	; Else, channel is SSG...
	push af
		ld a,(MLM_event_arg_buffer)
		ld c,a
	pop af
	call SSGCNT_set_note
	jp MLM_parse_command_end 

channel_is_fm$:
	push de
	push hl
	push ix
		sub a,MLM_CH_FM1 ; Calculate FM channel range (6~9 -> 0~3)

		; Calculate address of FM channel data
		push af
			rlca
			rlca
			rlca
			rlca
			and a,$F0
			ld ixl,a
			ld ixh,0
			ld de,FM_ch1
			add ix,de
		pop af

		; Set pitch
		ld iyl,c
		ld a,(MLM_event_arg_buffer)
		ld iyh,a
		call FMCNT_set_note
	pop ix
	pop hl
	pop de
	jp MLM_parse_command_end
	
; c: channel
; de: playback pointer
MLMCOM_set_channel_volume_byte:
	ld a,c
	cp a,MLM_CH_FM1
	jp c,channel_is_adpcma$

	cp a,MLM_CH_SSG1
	jp c,channel_is_fm$

	jp channel_is_ssg$
return$:
	ld a,c
	ld bc,0
	call MLM_set_timing
	jp MLM_parse_command_end

; a: channel
; c: channel
; de: playback pointer
channel_is_adpcma$:
	push hl
	push de
		; Load command byte in l
		ex de,hl
		dec hl
		ld e,(hl)
		ex de,hl

		; Store offset from com byte
		; in a and increment it by 1
		ld a,l
		and a,$07
		inc a

		; Shift offset to the left
		; to adjust the offset to fit 
		; the ADPCM-A range ($00~$1F)
		sla a
		sla a
		sla a

		; If the sign bit is set, 
		; negate offset
		bit 3,l
		jr z,channel_is_adpcma_pos$
		neg ; negates a

channel_is_adpcma_pos$:
		; Calculate address to channel volume
		ld hl,MLM_channel_volumes
		ld b,0
		add hl,bc

		; Add offset to channel volume
		add a,(hl)
		call MLM_set_channel_volume
	pop de
	pop hl
	jp return$

; a: channel
; c: channel
; de: playback pointer
channel_is_fm$:
	push hl
	push de
		; Load command byte in l
		ex de,hl
		dec hl
		ld e,(hl)
		ex de,hl

		; Store offset from com byte
		; in a and increment it by 1
		ld a,l
		and a,$07
		inc a

		; Shift offset to the left
		; to adjust the offset to
		; the FM range ($00~$7F)
		sla a

		; If the sign bit is set, 
		; negate offset
		bit 3,l
		jr z,channel_is_fm_pos$
		neg ; negates a

channel_is_fm_pos$:
		; Calculate address to channel volume
		ld hl,MLM_channel_volumes
		ld b,0
		add hl,bc

		; Add offset to channel volume
		add a,(hl)
		call MLM_set_channel_volume
	pop de
	pop hl
	jp return$


; a: channel
; c: channel
; de: playback pointer
channel_is_ssg$:
	push de
	push hl
		; Load command byte in a, and 
		; then get the volume from the 
		; least significant nibble of it
		ex de,hl
		dec hl
		ld a,(hl)
		ex de,hl
		and a,$0F

		; Transform SSG Volume ($00~$0F)
		; into an MLM volume ($00~$FF)
		sla a ; -\
		sla a ;  | a <<= 4
		sla a ;  /
		sla a ; /

		call MLM_set_channel_volume
	pop hl
	pop de
	jp return$

; invalid command, plays a noisy beep
; and softlocks the driver
MLMCOM_invalid:
	call softlock