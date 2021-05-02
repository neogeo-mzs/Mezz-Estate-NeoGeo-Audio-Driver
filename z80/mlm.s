; DOESN'T BACKUP REGISTERS
; THERE COULD BE A PROBLEM HERE
MLM_irq:
	ld iyl,0 ; Clear active mlm channel counter

	; base time counter code
	ld a,(MLM_base_time)
	ld c,a
	ld a,(MLM_base_time_counter)	
	inc a
	cp a,c
	ld (MLM_base_time_counter),a
	jr nz,MLM_update_skip

	ld b,CHANNEL_COUNT
MLM_update_loop:
	ld c,b
	dec c

	; if MLM_playback_control[ch] == 0 then
	; do not update this channel
	ld h,0
	ld l,c
	ld de,MLM_playback_control
	add hl,de
	ld a,(hl)
	or a,a ; cp a,0
	jr z,MLM_update_loop_next

	inc iyl ; increment active mlm channel counter

	; hl = &MLM_playback_timings[channel]
	; de = *hl
	ld h,0
	ld l,c
	ld de,MLM_playback_timings
	add hl,hl
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)

	; Decrement the timing and 
	; store it back into WRAM
	dec de 
	ld (hl),d
	dec hl
	ld (hl),e

	; if timing==0 update events
	; else save decremented timing
	push hl
		ld hl,0
		sbc hl,de
	pop hl
MLM_update_check_execute_events:
	call z,MLM_update_events

	; if MLM_playback_set_timings[ch] is 0
	; (thus the timing was set to 0 during this loop)
	; then execute the next event immediately
	ld h,0
	ld l,c
	ld de,MLM_playback_set_timings
	add hl,hl
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)

	; compare de to 0
	push hl
		ld hl,0
		or a,a ; clear carry flag
		sbc hl,de
	pop hl
	jr z,MLM_update_check_execute_events

MLM_update_loop_next:
	djnz MLM_update_loop 

	; Clear MLM_base_time_counter
	xor a,a
	ld (MLM_base_time_counter),a

	; if active mlm channel counter is 0,
	; then all channels have stopped, proceed
	; to call MLM_stop
	ld a,iyl
	or a,a ; cp a,0
	call z,MLM_stop
	
MLM_update_skip:
	ret

; stop song
MLM_stop:
	push hl
	push de
	push bc
	push af
		; Stop SSG Controller
		call SSGCNT_init

		; clear MLM WRAM
		ld hl,MLM_wram_start
		ld de,MLM_wram_start+1
		ld bc,MLM_wram_end-MLM_wram_start-1
		ld (hl),0
		ldir

		; clear FM WRAM
		ld hl,FM_wram_start
		ld de,FM_wram_start+1
		ld bc,FM_wram_end-FM_wram_start-1
		ld (hl),0
		ldir

		; Set WRAM variables
		;ld a,1
		;ld (MLM_base_time),a

		; Clear other WRAM variables
		xor a,a
		ld (EXT_2CH_mode),a

		call ssg_stop
		call fm_stop
		call PA_reset
		call pb_stop
	pop af
	pop bc
	pop de
	pop hl
	ret

MLM_default_channel_volumes:
	db &1F, &1F, &1F, &1F, &1F, &1F ; ADPCM-A channels
	db &00, &00, &00, &00           ; FM channels
	db &0F, &0F, &0F                ; SSG channels

; a: song
MLM_play_song:
	push hl
	push bc
	push de
	push ix
	push af
		call MLM_stop
		call set_default_banks 

		; First song index validity check
		;	If the song is bigger or equal to 128
		;   (thus bit 7 is set), the index is invalid.
		bit 7,a
		call nz,softlock ; if a's bit 7 is set then ..

		; Second song index validity check
		;	If the song is bigger or equal to the
		;   song count, the index is invalid.
		ld hl,MLM_HEADER
		ld c,(hl)
		cp a,c
		call nc,softlock ; if a >= c then ...

		; Load song header offset 
		; from MLM header into de,
		; then add MLM_songs to it
		; to obtain a pointer.
		inc hl
		sla a
		ld d,0
		ld e,a
		add hl,de
		ld e,(hl)
		inc hl
		ld d,(hl)
		ld hl,MLM_SONGS
		add hl,de

		;     For each channel...
		ld de,MLM_playback_pointers
		ld ix,MLM_playback_control
		ld b,CHANNEL_COUNT
MLM_play_song_loop:
		push bc
			; Set all channel timings to 1
			ld a,b
			dec a
			ld bc,1
			call MLM_set_timing

			; Load channel's playback offset
			; into bc
			ld c,(hl)
			inc hl
			ld b,(hl)
			inc hl

			; Obtain ptr to channel's playback
			; data by adding MLM_SONGS to its
			; playback offset.
			;	Only the due words' MSB need
			;	to be added together, since
			;	the LSB is always equal to &00.
			ld a,>MLM_SONGS
			add a,b

			; store said pointer into
			; MLM_playback_pointers[ch]
			ex de,hl
				ld (hl),c
				inc hl
				ld (hl),a
				inc hl
			ex de,hl

			; If the playback pointer isn't
			; equal to 0, set the channel's
			; playback control to &FF
			push hl
				ld hl,0
				or a,a ; Clear carry flag
				sbc hl,bc
				jr z,MLM_play_song_loop_no_playback
				ld (ix+0),&FF
MLM_play_song_loop_no_playback:
				inc ix
			pop hl
		pop bc
		djnz MLM_play_song_loop

		; Load timer a counter load
		; from song header and set it
		ld e,(hl)
		inc hl
		ld d,(hl)
		ex de,hl
		call ta_counter_load_set
		ex de,hl

		; Load base time from song
		; header and store it into WRAM
		inc hl
		ld a,(hl)
		ld (MLM_base_time),a
		
		; Copy MLM_playback_pointers
		; to MLM_playback_start_pointers
		ld hl,MLM_playback_pointers
		ld de,MLM_playback_start_pointers
		ld bc,2*CHANNEL_COUNT
		ldir
	pop af
	pop ix
	pop de
	pop bc
	pop hl
	ret

; c: channel
MLM_update_events:
	push hl
	push de
	push af
	push ix
		brk

		; de = MLM_playback_pointers[ch]
		ld h,0
		ld l,c
		add hl,hl
		ld de,MLM_playback_pointers
		add hl,de
		ld e,(hl)
		inc hl
		ld d,(hl)

		; If the first byte's most significant bit is 0, then
		; parse it and evaluate it as a note, else parse 
		; and evaluate it as a command
		ex de,hl
		ld a,(hl)
		bit 7,a
		call z,MLM_parse_command
		call nz,MLM_parse_note

MLM_update_events_skip:
	pop ix
	pop af
	pop de
	pop hl
	ret

;   c:  channel
;   hl: source (playback pointer)
;   de: &MLM_playback_pointers[channel]+1
MLM_parse_note:
	push af
	push bc
	push hl
	push de		
		ld a,(hl)
		and a,&7F ; Clear bit 7 of the note's first byte
		ld b,a
		ld a,c    ; move channel in a
		inc hl
		ld c,(hl)
		inc hl
		
		; if (channel < 6) MLM_parse_note_pa()
		cp a,6
		jp c,MLM_play_sample_pa

		cp a,10
		jp c,MLM_play_note_fm
		jp MLM_play_note_ssg
MLM_parse_note_end:
		; store playback pointer into WRAM
		ex de,hl
		ld (hl),d
		dec hl
		ld (hl),e
	pop de
	pop hl
	pop bc
	pop af
	ret

; [INPUT]
;   a:  channel
;   bc: source   (-TTTTTTT SSSSSSSS (Timing; Sample))
MLM_play_sample_pa:
	push de
	push bc
	push hl
	push ix
		; Load current instrument index into hl
		ld h,0
		ld l,a 
		ld de,MLM_channel_instruments
		add hl,de
		ld l,(hl)
		ld h,0

		; Calculate pointer to the current
		; instrument's data and store it in hl
		ld de,INSTRUMENTS
		add hl,hl ; \
		add hl,hl ;  \
		add hl,hl ;   | hl *= 32
		add hl,hl ;  /
		add hl,hl ; /
		add hl,de

		; Store pointer to ADPCM 
		; sample table in hl
		ld e,(hl)
		inc hl
		ld d,(hl)

		; ix = &ADPCM_sample_table[sample_idx]
		ld h,0
		ld l,c
		add hl,hl ; - hl *= 4
		add hl,hl ; /
		add hl,de
		ex de,hl
		ld ixl,e
		ld ixh,d

		call PA_set_sample_addr

		; Set timing
		ld c,b
		ld b,0
		call MLM_set_timing
		
		; play sample
		ld h,0
		ld l,a
		ld de,PA_channel_on_masks
		add hl,de
		ld d,REG_PA_CTRL
		ld e,(hl) 
		rst RST_YM_WRITEB
	pop ix
	pop hl
	pop bc
	pop de
	jp MLM_parse_note_end

; [INPUT]
;   a:  channel+6
;   bc: source
MLM_play_note_fm:
	; Set Timing
	push bc
		; Mask timing
		push af
			ld a,b
			and a,%01111111
			ld c,a
			ld b,0
		pop af

		call MLM_set_timing
	pop bc

	; Play note
	push af
	push hl
	push de
	push bc
		; backup MLM channel number into b
		ld b,a

		; Lookup correct FM channel number
		sub a,6
		ld h,0
		ld l,a
		ld de,FM_channel_LUT
		add hl,de
		ld a,(hl)

		call FM_stop_channel

		; Set panning
		push bc
		push af
			ld h,0
			ld l,b
			ld de,MLM_channel_pannings
			add hl,de
			ld c,(hl)
			ld a,b
			call FM_set_panning
		pop af
		pop bc

		; Load instrument
		push bc
			ld h,0
			ld l,b
			ld de,MLM_channel_instruments
			add hl,de
			ld b,a
			ld c,(hl)
			call FM_load_instrument
		pop bc

		; Set attenuator
		push bc
			ld l,b
			ld h,0
			ld de,MLM_channel_volumes
			add hl,de
			ld c,(hl)
			call FM_set_attenuator
		pop bc

		ld b,a
		call FM_set_note

		ld d,REG_FM_KEY_ON
		or a,%11110000
		ld e,a
		rst RST_YM_WRITEA
	pop bc
	pop de
	pop hl
	pop af
	jp MLM_parse_note_end

;   a:  channel
;   bc: source (-TTTTTTT NNNNNNNN (Timing; Note))
MLM_play_note_ssg:
	push af
	push bc
		sub a,MLM_CH_SSG1
		call SSGCNT_set_note
		call SSGCNT_enable_channel

		add a,MLM_CH_SSG1
		ld c,b
		ld b,0
		call MLM_set_timing
	pop bc
	pop af
	jp MLM_parse_note_end

; a: instrument
; c: channel
MLM_set_instrument:
	push bc
	push hl
	push af
		; Store instrument in MLM_channel_instruments
		ld b,0
		ld hl,MLM_channel_instruments
		add hl,bc
		ld (hl),a

		; if the channel is ADPCM-A nothing
		; else needs to be done: return
		ld a,c
		cp a,MLM_CH_FM1                ; if a < MLM_CH_FM1 
		jr c,MLM_set_instrument_return ; then ...

		; If the channel is FM, for now
		; do nothing. TODO make it do something
		cp a,MLM_CH_SSG1               ; if a < MLM_CH_SSG1
		jr c,MLM_set_instrument_return ; then ...

		; Else the channel is SSG, branch
		jr MLM_set_instrument_ssg
MLM_set_instrument_return:
	pop af
	pop hl
	pop bc
	ret

; a:  channel
; hl: &MLM_channel_instruments[channel]
MLM_set_instrument_ssg:
	push de
	push hl
	push bc
	push af
	push ix
		; Calculate pointer to instrument
		ld l,(hl)
		ld h,0
		ld de,INSTRUMENTS
		add hl,hl ; \
		add hl,hl ;  \
		add hl,hl ;  | hl *= 32
		add hl,hl ;  /
		add hl,hl ; /
		add hl,de

		; Calculate SSG channel
		; in 0~2 range
		sub a,MLM_CH_SSG1
		ld d,a                    ; Channel parameter

		; Enable tone if the mixing's byte
		; bit 0 is 1, else disable it
		ld a,(hl)
		and a,%00000001 ; Get tone enable bit
		ld c,a                    ; Enable/Disable parameter
		ld e,SSGCNT_MIX_EN_TUNE   ; Tune/Noise select parameter
		call SSGCNT_set_mixing

		; Enable noise if the mixing's byte
		; bit 1 is 1, else disable it
		ld a,(hl)
		and a,%00000010 ; Get noise enable bit
		srl a
		ld c,a                   ; Enable/Disable parameter
		ld e,SSGCNT_MIX_EN_NOISE ; Tune/Noise select parameter
		call SSGCNT_set_mixing

		; Skip EG parsing (TODO: parse EG information)
		inc hl
		inc hl
		inc hl
		inc hl

		; Calculate pointer to channel's mix macro
		ld ixh,0
		ld ixl,d 
		add ix,ix ; \
		add ix,ix ; | ix *= 8
		add ix,ix ; /
		ld bc,SSGCNT_mix_macro_A
		add ix,bc

		; If macro pointer is set to &0000,
		; then disable the macro, else set the 
		; mix macro's parameters accordingly.
		ld c,(hl)
		inc hl
		ld b,(hl)
		inc hl
		push hl
			ld hl,0
			or a,a    ; Clear the carry flag
			sbc hl,bc ; Compare bc to 0
		pop hl
		ld (ix+SSGCNT_macro.enable),&00 ; Disable macro, if the set mix macro subroutine is called it'll be enabled again
		ld l,c ; - Load pointer to macro data in hl
		ld h,b ; /
		call z,SSGCNT_MACRO_set
	pop ix
	pop af
	pop bc
	pop hl
	pop de
	jr MLM_set_instrument_return

;   c:  channel
;   hl: source (playback pointer)
;   de: &MLM_playback_pointers[channel]+1
MLM_parse_command:
	push af
	push bc
	push ix
	push hl
	push de
	push iy
		; Backup &MLM_playback_pointers[channel]+1
		; into ix
		ld ixl,e
		ld ixh,d

		; backup the command's first byte into iyl
		ld a,(hl)
		ld iyl,a

		; Lookup command argc and store it into a
		push hl
			ld l,(hl)
			ld h,0
			ld de,MLM_command_argc
			add hl,de
			ld a,(hl)
		pop hl

		; Lookup command vector and store it into de
		push hl
			ld l,(hl)
			ld h,0
			ld de,MLM_command_vectors
			add hl,hl
			add hl,de
			ld e,(hl)
			inc hl
			ld d,(hl)
		pop hl

		inc hl

		; If the command's argc is 0, 
		; just execute the command
		or a,a ; cp a,0
		jr z,MLM_parse_command_execute

		; if it isn't, load arguments into
		; MLM_event_arg_buffer beforehand
		; and add argc to hl
		push de
		push bc
			ld de,MLM_event_arg_buffer
			ld b,0
			ld c,a
			ldir
		pop bc
		pop de

MLM_parse_command_execute:
		ex de,hl
		jp (hl)

MLM_parse_command_end:
		ex de,hl
		
		; Load &MLM_playback_pointers[channel]
		; back into de
		ld e,ixl
		ld d,ixh

		; store playback pointer into WRAM
		ex de,hl
		ld (hl),d
		dec hl
		ld (hl),e

MLM_parse_command_end_skip_playback_pointer_set:
	pop iy
	pop de
	pop hl
	pop ix
	pop bc
	pop af
	ret

MLM_command_vectors:
	dw MLMCOM_end_of_list,         MLMCOM_note_off
	dw MLMCOM_set_instrument,      MLMCOM_wait_ticks_byte
	dw MLMCOM_wait_ticks_word,     MLMCOM_set_channel_volume
	dw MLMCOM_set_channel_panning, MLMCOM_set_master_volume
	dw MLMCOM_set_base_time,       MLMCOM_set_timer_b
	dw MLMCOM_small_position_jump, MLMCOM_big_position_jump
	dw MLMCOM_portamento_slide,    MLMCOM_porta_write
	dw MLMCOM_portb_write,         MLMCOM_set_timer_a
	dsw 16,  MLMCOM_wait_ticks_nibble
	dsw 96,  MLMCOM_invalid ; Invalid commands

MLM_command_argc:
	db &00, &01, &01, &01, &02, &02, &01, &02
	db &02, &02, &01, &02, &02, &02, &02, &02
	dsb 16, &00 ; Wait ticks nibble
	dsb 96, 0   ; Invalid commands all have no arguments

; a:  channel
; bc: timing
MLM_set_timing:
	push hl
	push de
		ld h,0
		ld l,a
		ld de,MLM_playback_timings
		add hl,hl
		add hl,de
		ld (hl),c
		inc hl
		ld (hl),b

		ld de,MLM_playback_set_timings-MLM_playback_timings
		add hl,de
		ld (hl),b
		dec hl
		ld (hl),c
	pop de
	pop hl
	ret

; c: channel
MLM_stop_channel:
	push hl
	push de
	push af
		ld h,0
		ld l,c
		ld de,MLM_stop_channel_LUT
		add hl,hl
		add hl,de
		ld e,(hl)
		inc hl
		ld d,(hl)
		ex de,hl
		jp (hl)
MLM_stop_channel_return:
	pop af
	pop de
	pop hl
	ret

MLM_stop_channel_LUT:
	dsw 6, MLM_stop_channel_return
	dsw 4, MLM_stop_channel_FM
	dsw 3, MLM_stop_channel_return

; c: channel
MLM_stop_channel_FM:
	push bc
	push hl
	push af
		ld hl,FM_channel_LUT
		ld b,0
		add hl,bc
		ld a,(hl)
		call FM_stop_channel
	pop af
	pop hl
	pop bc
	jp MLM_stop_channel_return

; c: channel
MLMCOM_end_of_list:
	push hl
	push de
	push af
	push bc
		; Set playback control to 0
		ld h,0
		ld l,c
		ld de,MLM_playback_control
		add hl,de
		ld (hl),0

		; Set timing to 1
		; (This is done to be sure that
		;  the next event won't be executed)
		ld a,c
		ld bc,1
		call MLM_set_timing
MLMCOM_end_of_list_return:
	pop bc
	pop af
	pop de
	pop hl
	jp MLM_parse_command_end

; c: channel
; Arguments:
; 	1. timing
MLMCOM_note_off:
	push hl
	push af
	push de
	push bc
		; switch (channel) {
		; case is_adpcma:
		;   PA_stop_sample(channel);
		;   break;
		;
		; case is_ssg:
		;   SSG_stop_channel(channel-10);
		;   break;
		;
		; default: // is fm
		;   FM_stop_channel(FM_channel_LUT[channel-6]);
		;   break;
		; }
		ld a,c
		cp a,6
		call c,PA_stop_sample
		jr c,MLMCOM_note_off_break

		cp a,10
		sub a,10
		;call nc,SSG_stop_note
		jr nc,MLMCOM_note_off_break

		ld a,c
		sub a,6
		ld h,0
		ld l,a 
		ld de,FM_channel_LUT
		add hl,de
		ld a,(hl)
		call FM_stop_channel

MLMCOM_note_off_break:
		ld hl,MLM_event_arg_buffer
		ld a,c
		ld b,0
		ld c,(hl)
		call MLM_set_timing
	pop bc
	pop de
	pop af
	pop hl
	jp MLM_parse_command_end

; c: channel
; Arguments
;   1. instrument
MLMCOM_set_instrument:
	push af
	push bc
		ld a,(MLM_event_arg_buffer)
		call MLM_set_instrument

		ld a,c
		ld bc,0
		call MLM_set_timing
	pop bc
	pop af
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. timing
MLMCOM_wait_ticks_byte:
	push hl
	push bc
	push af
		ld hl,MLM_event_arg_buffer
		ld a,c
		ld b,0
		ld c,(hl)
		call MLM_set_timing
	pop af
	pop bc
	pop hl
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. timing (LSB)
;   2. timing (MSB)
MLMCOM_wait_ticks_word:
	push hl
	push bc
	push af
	push ix
		ld ix,MLM_event_arg_buffer
		ld a,c
		ld b,(ix+1)
		ld c,(ix+0)
		call MLM_set_timing
	pop ix
	pop af
	pop bc
	pop hl
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. Volume
;   2. Timing
MLMCOM_set_channel_volume:
	push ix
	push af
	push hl
	push bc
		ld ix,MLM_event_arg_buffer
		ld a,c ; backup channel into a

		; Store volume in 
		; MLM_channel_volumes[channel]
		ld h,0
		ld l,a
		ld bc,MLM_channel_volumes
		add hl,bc
		ld c,(ix+0)
		ld (hl),c

		; if channel is adpcma...
		cp a,6
		call c,PA_set_channel_volume
		jr c,MLMCOM_set_channel_volume_set_timing

		; elseif channel is fm...
		cp a,10
		jr c,MLMCOM_set_channel_volume_fm

		; else (channel is ssg)...
		push af
			sub a,10
			call SSGCNT_set_vol
		pop af

MLMCOM_set_channel_volume_set_timing:
		ld c,(ix+1)
		ld b,0
		call MLM_set_timing
	pop bc
	pop hl
	pop af
	pop ix
	jp MLM_parse_command_end

MLMCOM_set_channel_volume_fm:
	push af
	push hl
	push de
		; Load actual FM channel number
		; from LUT into a
		sub a,6
		ld h,0
		ld l,a
		ld de,FM_channel_LUT
		add hl,de
		ld a,(hl)

		call FM_set_attenuator
	pop de
	pop hl
	pop af
	jr MLMCOM_set_channel_volume_set_timing

; c: channel
; Arguments:
;   1. %LRTTTTTT (Left on; Right on; Timing)
MLMCOM_set_channel_panning:
	push af
	push hl
	push bc
	push de
		; Load panning into c
		ld a,(MLM_event_arg_buffer)
		and a,%11000000
		ld b,a ; \
		ld a,c ;  |- Swap a and c sacrificing b
		ld c,b ; /

		; Store panning into 
		; MLM_channel_pannings[channel]
		ld h,0
		ld l,a
		ld de,MLM_channel_pannings
		add hl,de
		ld (hl),c

		; if channel is adpcma...
		cp a,6
		call c,PA_set_channel_panning
		jr c,MLMCOM_set_channel_panning_set_timing

		; elseif channel is FM...
		cp a,10
		call c,FM_set_panning

		; else channel is SSG, the panning will be
		; ignored since the SSG channels are mono

MLMCOM_set_channel_panning_set_timing:
		ld b,a ; backup channel in b
		ld a,(MLM_event_arg_buffer)
		and a,%00111111 ; Get timing
		ld c,a
		ld a,b
		ld b,0
		call MLM_set_timing
	pop de
	pop bc
	pop hl
	pop af
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. %VVVVVVTT (Volume; Timing MSB)
;   2. %TTTTTTTT (Timing LSB)
MLMCOM_set_master_volume:
	push ix
	push af
	push de
	push bc
		ld ix,MLM_event_arg_buffer

		; Set master volume
		ld a,(ix+0)
		srl a ; %VVVVVV-- -> %-VVVVVV-
		srl a ; %-VVVVVV- -> %--VVVVVV
		ld d,REG_PA_MVOL
		ld e,a
		rst RST_YM_WRITEB

		; Set timing
		ld a,(ix+0)
		and a,%00000011
		ld b,a
		ld a,c
		ld c,(ix+1)
		call MLM_set_timing
	pop bc
	pop de
	pop af
	pop ix
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. %BBBBBBBB (Base time)
;   2. %TTTTTTTT (Timing)
MLMCOM_set_base_time:
	push ix
	push af
		ld ix,MLM_event_arg_buffer

		; Set base time
		ld a,(ix+0)
		ld (MLM_base_time),a

		; Set timing
		ld a,c
		ld b,0
		ld c,(ix+1)
		call MLM_set_timing
	pop af
	pop ix
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. %BBBBBBBB (timer B)
;   2. %TTTTTTTT (Timing)
MLMCOM_set_timer_b:
	jp MLM_parse_command_end
	push ix
	push de
	push bc
	push af
		ld ix,MLM_event_arg_buffer

		; Set Timer B (will be loaded later)
		ld e,(ix+0)
		ld d,REG_TMB_COUNTER 
		rst RST_YM_WRITEA

		; Set timing
		ld a,c
		ld c,(ix+1)
		ld b,0
		call MLM_set_timing
	pop af
	pop bc
	pop de
	pop ix
	jp MLM_parse_command_end

; c:  channel
; ix: &MLM_playback_pointers[channel]+1
; de: source (playback pointer)
; Arguments:
;   1. %OOOOOOOO (Offset)
MLMCOM_small_position_jump:
	push hl
	push de
	push ix
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
	pop ix
	pop de
	pop hl
	jp MLM_parse_command_end_skip_playback_pointer_set

; c:  channel
; ix: &MLM_playback_pointers[channel]+1
; de: source (playback pointer)
; Arguments:
;   1. %OOOOOOOO (Offset)
MLMCOM_big_position_jump:
	push hl
	push de
	push ix
		ld hl,MLM_event_arg_buffer

		; Load offset into bc
		ld a,c ; Backup channel into a
		ld c,(hl)
		inc hl
		ld b,(hl)

		; Add offset to playback 
		; pointer and store it into 
		; MLM_playback_pointers[channel]
		ld l,e
		ld h,d
		add hl,bc
		ld (ix-1),l
		ld (ix-0),h

		; Set timing to 0
		ld bc,0
		call MLM_set_timing
	pop ix
	pop de
	pop hl
	jp MLM_parse_command_end_skip_playback_pointer_set

; c: channel
; Arguments:
;   1. %SSSSSSSS (Signed pitch offset per tick)
;   2. %TTTTTTTT (Timing)
MLMCOM_portamento_slide:
	jp MLM_parse_command_end
	push hl
	push de
	push ix
	push bc
	push af
		ld ixl,c ; Backup MLM channel into ixl

		; Jump to the end of the subroutine
		; if the channel isn't FM
		ld a,c
		cp a,MLM_CH_FM1   ; if a < MLM_CH_FM1
		jr c,MLMCOM_portamento_slide_skip
		cp a,MLM_CH_FM4+1 ; if a > MLM_CH_FM4
		jr nc,MLMCOM_portamento_slide_skip

		; Load internal fm channel into l
		ld h,0
		ld l,c
		ld de,FM_channel_LUT-MLM_CH_FM1
		add hl,de
		ld l,(hl)

		; Load 8bit signed pitch offset, sign extend
		; it to 16bit, then store it into WRAM
		ld a,(MLM_event_arg_buffer)
		;call AtoBCextendendsign
		ld h,0
		;ld de,FM_portamento_slide
		add hl,hl
		add hl,de
		ld (hl),c
		inc hl
		ld (hl),b
		
MLMCOM_portamento_slide_skip:
		ld a,(MLM_event_arg_buffer+1)
		ld c,a
		ld a,ixl
		ld b,0
		call MLM_set_timing
	pop af
	pop bc
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
	push ix
	push af
	push bc
		ld ix,MLM_event_arg_buffer

		ld d,(ix+0)
		ld e,(ix+1)
		rst RST_YM_WRITEA

		ld a,c
		ld bc,0
		call MLM_set_timing

		; If address isn't equal to 
		; REG_TIMER_CNT return
		ld a,d
		cp a,REG_TIMER_CNT
		jr nz,MLMCOM_porta_write_return

		; If address is equal to &27, then
		; store the data's 7th bit in WRAM
		ld a,e
		and a,%01000000 ; bit 6 enables 2CH mode
		ld (EXT_2CH_mode),a
		
MLMCOM_porta_write_return:
	pop bc
	pop af
	pop ix
	pop de
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. %AAAAAAAA (Address)
;   2. %DDDDDDDD (Data)
MLMCOM_portb_write:
	push de
	push ix
	push af
	push bc
		ld ix,MLM_event_arg_buffer

		ld d,(ix+0)
		ld e,(ix+1)
		rst RST_YM_WRITEB

		ld a,c
		ld bc,0
		call MLM_set_timing
	pop bc
	pop af
	pop ix
	pop de
	jp MLM_parse_command_end

; c: channel
; Arguments:
;   1. %AAAAAAAA (timer A MSB) 
;   2. %TTTTTTAA (Timing; timer A LSB)
MLMCOM_set_timer_a:
	push ix
	push bc
	push af
	push de
		ld ix,MLM_event_arg_buffer
		ld e,c ; backup channel in e

		; Set timer a counter load
		ld d,REG_TMA_COUNTER_MSB
		ld e,(ix+0)
		rst RST_YM_WRITEA
		inc d
		ld e,(ix+1)
		rst RST_YM_WRITEA
		ld de,(REG_TIMER_CNT<<8) | %10101
		RST RST_YM_WRITEA

		ld b,0
		ld a,(ix+1)
		srl a
		srl a
		ld c,a
		ld a,e
		call MLM_set_timing
	pop de
	pop af
	pop bc
	pop ix
	jp MLM_parse_command_end

; c: channel
; de: playback pointer
MLMCOM_wait_ticks_nibble:
	push hl
	push af
	push bc
		; Load command ($1T) in a
		ld h,d
		ld l,e
		dec hl
		ld a,(hl)
		ld l,c ; backup channel

		and a,&0F ; get timing
		ld c,a
		ld b,0
		ld a,l
		call MLM_set_timing
	pop bc
	pop af
	pop hl
	jp MLM_parse_command_end

; invalid command, plays a noisy beep
; and softlocks the driver
MLMCOM_invalid:
	call softlock