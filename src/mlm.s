; DOESN'T BACKUP REGISTERS
MLM_irq:
	; Avoids MLM_stop spam
	ld a,(MLM_is_song_playing)
	or a,a ; cp a,0
	ret z 

	xor a,a
	ld a,(do_reset_chvols)
	or a,a ; cp a,0
	call nz,MLM_reset_channel_volumes
	ld a,(do_stop_song)
	or a,a ; cp a,0
	call nz,MLM_stop

	ld iyl,0 ; Clear active mlm channel counter

	ld c,0
	ld hl,MLM_channel_control
	dup CHANNEL_COUNT
		; If the channel is disabled, don't update playback...
		bit MLM_CH_ENABLE_BIT,(hl)            ; channel is disabled if MLM_channel_control[ch]'s bit 0 is cleared
		jr z,$+10                             ; +2 = 2b

		push hl                               ; +1 = 3b
			call MLM_update_channel_playback  ; +3 = 6b
		pop hl                                ; +1 = 7b
		call MLM_update_ch_macro              ; +3 = 10b

		inc c
		inc hl
	edup

	; if active mlm channel counter is 0,
	; then all channels have stopped, proceed
	; to call MLM_stop
	ld a,iyl
	or a,a ; cp a,0
	call z,MLM_stop

	ret

; [INPUT]
; 	c: channel
; [OUTPUT]
;	iyl: active channel count
; Doesn't backup AF, HL, DE, B, IX, HL', BC' and DE'
; OPTIMIZED
MLM_update_channel_playback:
	inc iyl ; increment active mlm channel counter

	; decrement MLM_playback_timings[ch],
	; if afterwards it isn't 0 return
	ld hl,MLM_playback_timings
	ld d,0 
	ld e,c 
	add hl,de
	dec (hl)
	ld b,(hl)
	ld hl,MLM_playback_set_timings
	add hl,de ; get pointer to MLM_playback_set_timings[ch]
	xor a,a   ; ld a,0
	cp a,b    ; compare 0 to MLM_playback_timings[ch]
	ret nz

	push iy
MLM_update_channel_playback_next_event:
		push hl
			; ======== Update events ========
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
			jp z,MLM_parse_command ; hl, de, c

			; ======== Parse note ========
			push bc ;;;; CRASHES PARSING NOTE
				ld a,(hl)
				and a,$7F ; Clear bit 7 of the note's first byte
				ld b,a
				ld a,c    ; move channel in a
				inc hl
				ld c,(hl)
				inc hl
				
				; if (channel < 6) MLM_parse_note_pa()
				cp a,MLM_CH_FM1
				jp c,MLM_play_adpcma_note

				cp a,MLM_CH_SSG1
				jp c,MLM_play_fm_note
				
				; Else, Play note SSG...
				sub a,MLM_CH_SSG1
				call SSGCNT_set_note
				call SSGCNT_enable_channel
				call SSGCNT_start_channel_macros

				add a,MLM_CH_SSG1
				ld c,b
				call MLM_set_timing
MLM_parse_note_end:
				; store playback pointer into WRAM
				ex de,hl
				ld (hl),d
				dec hl
				ld (hl),e
			pop bc

MLM_update_channel_playback_check_set_t:
		pop hl

		; if MLM_playback_set_timings[ch] == 0
		; update events again
		xor a,a
		cp a,(hl) ; cp 0,(hl)
		jr z,MLM_update_channel_playback_next_event
	pop iy
	ret

; [INPUT]
;   a:  channel
;   bc: source   (-TTTTTTT SSSSSSSS (Timing; Sample))
; Doesn't backup BC, IX and AF'
; OPTIMIZED
MLM_play_adpcma_note:
	push de
	push hl
		; Load current instrument index into hl
		ld h,0
		ld l,a 
		ld de,MLM_channel_instruments
		add hl,de
		ld l,(hl)
		ld h,0

		; Load pointer to instrument data
		; from WRAM into de
		ex af,af'
			ld a,(MLM_instruments)
			ld e,a
			ld a,(MLM_instruments+1)
			ld d,a

			; Calculate pointer to the current
			; instrument's data and store it in hl
			add hl,hl ; \
			add hl,hl ;  \
			add hl,hl ;   | hl *= 32
			add hl,hl ;  /
			add hl,hl ; /
			add hl,de

			; Store offset to ADPCM 
			; sample table in hl
			ld e,(hl)
			inc hl
			ld d,(hl)

			; Add MLM_header offset to
			; it to obtain the actual address
			ld hl,MLM_HEADER
			add hl,de
			ld e,l
			ld d,h

			; Check if sample id is valid;
			; if it isn't softlock.
			ld a,c
			cp a,(hl)
			jp nc,softlock ; if smp_id >= smp_count
			inc de ; Increment past sample count
		ex af,af'

		; ix = $ADPCM_sample_table[sample_idx]
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
	pop hl
	pop de
	jp MLM_parse_note_end

; [INPUT]
;   a:  channel+6
;   bc: source (-TTTTTTT -OOONNNN (Timing; Octave; Note))
; Doesn't backup AF, IX, IY and C
MLM_play_fm_note:
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

		; Make sure the OP TLs are set
		; before playing a note
		ld h,b ; backup timing in h
		ld b,a
		call FMCNT_update_total_levels
		ld b,h ; store timing back into b

		; Stop FM channel  
		;   Load channel bit from LUT 
		ld hl,FM_channel_LUT
		ld e,a
		ld d,0
		add hl,de

		;   Write to the YM2610 FM registers
		ld e,(hl)
		ld d,REG_FM_KEY_ON
		rst RST_YM_WRITEA

		; Set pitch
		ld iyh,c
		ld iyl,a
		call FMCNT_set_note
		
		; Play FM channel
		;   Calculate pointer enabled operators 
		push af
			;   OR enabled operators and channels
			;   together, then proceed to play the channel 
			ld a,(hl)
			or a,(ix+FM_Channel.op_enable)
			ld e,a
			ld d,REG_FM_KEY_ON
			rst RST_YM_WRITEA
		pop af

		add a,MLM_CH_FM1
		ld c,b
		call MLM_set_timing
	pop ix
	pop hl
	pop de
	jp MLM_parse_note_end

;   c:  channel
;   hl: source (playback pointer)
;   de: $MLM_playback_pointers[channel]+1
MLM_parse_command:
	push bc
	push hl
	push de
		; Backup $MLM_playback_pointers[channel]+1
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
		
		; Load $MLM_playback_pointers[channel]+1
		; back into de
		ld e,ixl
		ld d,ixh

		; store playback pointer into WRAM
		ex de,hl
		ld (hl),d
		dec hl
		ld (hl),e

MLM_parse_command_end_skip_playback_pointer_set:
	pop de
	pop hl
	pop bc
	jp MLM_update_channel_playback_check_set_t

; c: channel
MLM_update_ch_macro:
	; Calculate address to channel macro
	ld ix,MLM_channel_pitch_macros
	ld a,c
	sla a ; \
	sla a ; | a *= 8
	sla a ; /
	ld e,a
	ld d,0
	add ix,de

	; If control macro is disabled, return.
	xor a,a ; ld a,0
	cp a,(ix+ControlMacro.enable)
	ret z

	ld a,c
	cp a,MLM_CH_FM1  ; If channel is ADPCMA...
	ret c            ; return, because ADPCMA has no pitch.
	cp a,MLM_CH_SSG1 ; If channel is FM...
	jp c,MLM_update_ch_macro_fm

	push hl
	push bc
		; Else, channel is SSG...
		; Calculate address to pitch offset in WRAM
		ld hl,SSGCNT_pitch_ofs-(MLM_CH_SSG1*2)
		sla a ; a *= 2
		ld e,a
		add hl,de

		call BMACRO_read
		call AtoBCextendendsign
		ld (hl),c
		inc hl
		ld (hl),b
		call MACRO_update
	pop bc
	pop hl
	ret

; a: channel
; d: 0
MLM_update_ch_macro_fm:
	push hl
	push bc
		; Calculate address to FM Channel pitch offset
		ld hl,FM_ch1+FM_Channel.pitch_ofs-(MLM_CH_FM1*16)
		sla a ; -\
		sla a ;  | a *= 16
		sla a ;  /
		sla a ; /
		ld e,a
		add hl,de

		call BMACRO_read
		call AtoBCextendendsign
		ld (hl),c
		inc hl
		ld (hl),b
								
		call MACRO_update
	pop bc
	pop hl  
	ret

; stop song
MLM_stop:
	push hl
	push de
	push bc
	push af
		call SSGCNT_init
		call FMCNT_init
		call SFXPS_set_taken_channels_free

		; clear MLM WRAM
		ld hl,MLM_wram_start
		ld de,MLM_wram_start+1
		ld bc,MLM_wram_end-MLM_wram_start-1
		ld (hl),0
		ldir

		; Clear other WRAM variables
		xor a,a
		ld (EXT_2CH_mode),a
		ld (IRQ_TA_tick_base_time),a
		ld (IRQ_TA_tick_time_counter),a
		ld (do_stop_song),a

		; DON'T RESET PAS, this messes with SFXPS
		call ssg_stop
		call fm_stop
		;call PA_reset
		call pb_stop
	pop af
	pop bc
	pop de
	pop hl
	ret

; a: song
MLM_play_song:
	push hl
	push bc
	push de
	push ix
	push af
		call MLM_stop

		; First song index validity check
		;	If the song is bigger or equal to 128
		;   (thus bit 7 is set), the index is invalid.
		bit 7,a
		call nz,softlock ; if a's bit 7 is set then ..

		; Second song index validity check
		;	If the song is bigger or equal to the
		;   song count, the index is invalid.
		ld hl,MLM_HEADER+2 ; Skip SFXPS header stuff
		ld c,(hl)
		cp a,c
		call nc,softlock ; if a >= c then ...

		; Index song offset list
		inc hl
		sla a
		sla a
		ld d,0
		ld e,a
		add hl,de ; Calculate song offset

		; Switch to the bank specified 
		; in the offset
		ld b,(hl)
		inc b
		call set_banks

		; Load offset to song and
		; increment it to obtain pointer
		inc hl
		ld e,(hl)
		inc hl
		ld d,(hl)
		ld hl,MLM_HEADER
		add hl,de ; Get pointer from offset

		;     For each channel...
		ld de,MLM_playback_pointers
		ld ix,MLM_channel_control
		ld b,1

		dup CHANNEL_COUNT
			call MLM_playback_init
			inc b
		edup

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
		ld (IRQ_TA_tick_base_time),a

		; Load instrument offset into de
		inc hl
		ld e,(hl)
		inc hl
		ld d,(hl)

		; Calculate actual address, then
		; load said address into WRAM
		ld hl,MLM_HEADER
		add hl,de
		ld a,l
		ld (MLM_instruments),a
		ld a,h
		ld (MLM_instruments+1),a

		; Copy MLM_playback_pointers
		; to MLM_playback_start_pointers
		ld hl,MLM_playback_pointers
		ld de,MLM_playback_start_pointers
		ld bc,2*CHANNEL_COUNT
		ldir

		; Set ADPCM-A master volume
		ld de,REG_PA_MVOL<<8 | $3F
		rst RST_YM_WRITEB

		; For each channel initialize its
		; parameters if it is enabled.
		ld b,CHANNEL_COUNT
loop$:
		xor a,a
		cp a,(ix-1)
		call nz,MLM_ch_parameters_init
		dec ix
		djnz loop$

		ld a,$FF
		ld (MLM_is_song_playing),a
	pop af
	pop ix
	pop de
	pop bc
	pop hl
	ret

; [INPUT]
;	b:	channel+1
;	de:	$MLM_playback_pointers[ch]
;	ix:	$MLM_channel_control[ch]
;   hl: song_header[ch]
; [OUTPUT]
;	de:	$MLM_playback_pointers[ch+1]
;	ix:	$MLM_channel_control[ch+1]
;   hl: song_header[ch+1]
MLM_playback_init:
	push bc
	push af
	push iy
		; Set the channel timing to 1
		ld a,b
		dec a
		ld iyl,a ; backup channel in iyl
		ld bc,1
		call MLM_set_timing

		; Load channel's playback offset
		; into bc
		ld c,(hl)
		inc hl
		ld b,(hl)
		inc hl

		; Obtain ptr to channel's playback
		; data by adding MLM_HEADER to its
		; playback offset.
		;	Only the due words' MSB need
		;	to be added together, since
		;	the LSB is always equal to $00.
		ld a,MLM_HEADER>>8
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
		; playback control to $FF, and
		; also set SFXPS ch. status to taken
		push hl
			ld hl,0
			or a,a ; Clear carry flag
			sbc hl,bc
			jr z,no_playback
			ld (ix+0),MLM_CH_ENABLE ; Set playback control channel enable flag
no_playback:
			inc ix
		pop hl
	pop iy
	pop af
	pop bc
	ret

; b: channel+1
;	Initializes channel parameters
MLM_ch_parameters_init:
	push af
	push bc
		ld a,b
		dec a
		ld c,PANNING_CENTER
		call MLM_set_channel_panning

		ld a,0
		ld c,b
		dec c
		call MLM_set_instrument

		ld a,$FF
		call MLM_set_channel_volume

		; If the channel is ADPCM-A, initialize 
		; specific ADPCM-A parameters
		ld a,c
		cp a,MLM_CH_FM1                ; if a < MLM_CH_FM1 
		jr c,init_adpcma_channel$ ; then ...

		; If the channel is FM, initialize
		; specific FM parameters
		cp a,MLM_CH_SSG1               ; if a < MLM_CH_SSG1
		jr c,init_fm_channel$     ; then ...

		; Else the channel is SSG, there's
		; no specific SSG parameters to set.
	pop bc
	pop af
	ret

; a: channel
init_adpcma_channel$:
		; Tell SFXPS that this channel  
		; is reserved for music playback
		ld c,a
		call SFXPS_set_channel_as_taken 
	pop bc
	pop af
	ret

; a: channel
init_fm_channel$:
		; Enable FMCNT for the channel
		sub a,MLM_CH_FM1 ; Calculate FM channel range (6~9 -> 0~3)
		ld c,a
		call FMCNT_enable_channel
	pop bc
	pop af
	ret

; a: instrument
; c: channel
; COULD OPTIMIZE
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
		jr c,return$ ; then ...

		; If the channel is FM, branch
		cp a,MLM_CH_SSG1               ; if a < MLM_CH_SSG1
		jr c,set_fm_instrument$     ; then ...

		; Else the channel is SSG, branch
		jr set_ssg_instrument$
return$: 
	pop af
	pop hl
	pop bc
	ret

; a:  channel
; hl: $MLM_channel_instruments[channel]
set_fm_instrument$:
	push hl
	push de
	push bc
	push af
	push ix
		sub a,MLM_CH_FM1
		push af
			; Calculate address to
			; FM_Channel struct
			rlca      ; \
			rlca      ;  \
			rlca      ;  | offset = channel * 16
			rlca      ;  /
			and a,$F0 ; /
			ld ixl,a
			ld ixh,0
			ld de,FM_ch1
			add ix,de

			; Load pointer to instrument data
			; from WRAM into de
			ld a,(MLM_instruments)
			ld e,a
			ld a,(MLM_instruments+1)
			ld d,a
		pop af

		; Calculate pointer to instrument
		ld l,(hl)
		ld h,0
		add hl,hl ; \
		add hl,hl ;  \
		add hl,hl ;  | hl *= 32
		add hl,hl ;  /
		add hl,hl ; /
		add hl,de

		; Set feedback & algorithm
		ld c,a
		ld a,(hl)
		call FMCNT_set_fbalgo

		; Set AMS and PMS
		inc hl
		ld a,(hl)
		call FMCNT_set_amspms

		; Set OP enable
		
		inc hl
		ld a,(hl)
		ld (ix+FM_Channel.op_enable),a

		; Set operators
		ld b,0
		inc hl
		ld de,7 ; operator data size

		; Set OP 1
		call FMCNT_set_operator
		add hl,de
		inc b

		; Set OP 2
		call FMCNT_set_operator
		add hl,de
		inc b

		; Set OP 3
		call FMCNT_set_operator
		add hl,de
		inc b

		; Set OP 4
		call FMCNT_set_operator
		add hl,de

		; Set volume update flag
		ld a,(ix+FM_Channel.enable)
		or a,FMCNT_VOL_UPDATE
		ld (ix+FM_Channel.enable),a
	pop ix
	pop af
	pop bc
	pop de
	pop hl
	jr return$

; a:  channel
; hl: $MLM_channel_instruments[channel]
set_ssg_instrument$:
	push de
	push hl
	push bc
	push af
	push ix
		; Load pointer to instrument data
		; from WRAM into de
		push af
			ld a,(MLM_instruments)
			ld e,a
			ld a,(MLM_instruments+1)
			ld d,a
		pop af

		; Calculate pointer to instrument
		ld l,(hl)
		ld h,0
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
		inc hl

		; Calculate pointer to channel's mix macro
		ld ixh,0
		ld ixl,d 
		add ix,ix ; \
		add ix,ix ; | ix *= 8
		add ix,ix ; /
		ld bc,SSGCNT_mix_macro_A
		add ix,bc

		; Set mix macro
		ld e,(hl) ; \
		inc hl    ; | Store macro data
		ld d,(hl) ; | offset in hl
		ex de,hl  ; /
		push de              ; \
			ld de,MLM_HEADER ; | Add MLM header offset to
			add hl,de        ; | obtain the actual address
		pop de               ; /
		call MACRO_set
		
		; Calculate pointer to volume macro
		; initialization data (hl) and pointer
		; to the volume macro in WRAM (ix)
		ex de,hl
		inc hl
		ld bc,ControlMacro.SIZE*3
		add ix,bc

		; Set volume macro
		ld e,(hl)
		inc hl
		ld d,(hl)
		ex de,hl
		push de              ; \
			ld de,MLM_HEADER ; | Add MLM header offset to
			add hl,de        ; | obtain the actual address
		pop de               ; /
		call MACRO_set

		; Set arpeggio macro
		ex de,hl
		inc hl
		add ix,bc
		ld e,(hl)
		inc hl
		ld d,(hl)
		ex de,hl
		push de              ; \
			ld de,MLM_HEADER ; | Add MLM header offset to
			add hl,de        ; | obtain the actual address
		pop de               ; /
		call MACRO_set
	pop ix
	pop af
	pop bc
	pop hl
	pop de
	jp return$

; a: channel
; c: timing
MLM_set_timing:
	push hl
	push de
	push af
		; MLM_playback_timings[channel] = c
		ld hl,MLM_playback_timings
		ld e,a
		ld d,0
		add hl,de
		ld (hl),c

		; MLM_playback_set_timings[channel] = c
		ld de,MLM_playback_set_timings-MLM_playback_timings
		add hl,de
		ld (hl),c
	pop af
	pop de
	pop hl
	ret

; a: channel (MLM)
; OPTIMIZED
MLM_stop_note:
	push af
		cp a,MLM_CH_FM1
		jp c,MLM_stop_note_PA

		cp a,MLM_CH_SSG1
		jp c,MLM_stop_note_FM

		; Else, Stop SSG note...
		sub a,MLM_CH_SSG1
		call SSGCNT_disable_channel
	pop af
	ret

MLM_stop_note_PA:
		call PA_stop_sample
	pop af
	ret

MLM_stop_note_FM:
	push bc
		sub a,MLM_CH_FM1
		ld c,a
		call FMCNT_stop_channel
	pop bc
	pop af
	ret

; a: volume
; c: channel
;	This sets MLM_channel_volumes,
;   the register writes are done in
;   the IRQ
MLM_set_channel_volume:
	push hl
	push bc
	push af
	push iy
		; Store unaltered channel volume in WRAM
		ld hl,MLM_channel_volumes
		ld b,0
		add hl,bc
		ld (hl),a

		; If master volume is 255, there's 
		; no need to alter the volume
		ld iyh,b ; b is 0
		ld hl,master_volume
		ld b,(hl)
		inc b ; cp b,255
		jr z,skip_mvol_calculation$

		; Else, negate the master vol and
		; subtract it from the channel vol
		; (The master volume works logarithmically)
		ld b,a ; backup cvol in b
		ld a,$FF
		sub a,(hl)
		ld iyl,a ; backup negated mvol in iyl...
		ld iyh,a ; ...and iyh
		ld a,b   ; store cvol back in a
		sub a,iyl

		jp nc,skip_mvol_calculation$ ; if no overflow happened...
		ld a,0 ; if underflow happened, take care of it

skip_mvol_calculation$:
		ld iyl,a ; Backup scaled MLM chvol 

		; Swap a and c
		ld b,a
		ld a,c
		ld c,b
		
		cp a,MLM_CH_FM1
		jp c,set_adpcma_channel_volume$

		cp a,MLM_CH_SSG1
		jp c,set_fm_channel_volume$

		; Else, Set SSG volume...
		;   Swap a and c again
		ld b,a
		ld a,c
		ld c,b

		;   Scale down volume ($00~$FF -> $00~$0F)
		rrca
		rrca
		rrca
		rrca
		and a,$0F

		;   Store volume into SSGCNT WRAM
		ld hl,SSGCNT_volumes-MLM_CH_SSG1
		ld b,0
		add hl,bc
		ld (hl),a
	pop iy
	pop af
	pop bc
	pop hl
	ret

set_adpcma_channel_volume$:
		; Swap a and c again
		ld b,a
		ld a,c
		ld c,b

		sub a,iyh
		jp nc,$+5 ; +3 = 3b
		ld a,0    ; +2 = 5b
		ld iyl,a 

		; Scale down volume
		; ($00~$FF -> $00~$1F)
		rrca
		rrca
		rrca
		and a,$1F
		push de
			; Store volume in 
			; PA_channel_volumes[channel]
			ld hl,PA_channel_volumes
			ld b,0
			add hl,bc
			ld (hl),a

			; if the scaled MLM chvol isn't 0, load 
			; panning from PA_channel_pannings[channel]
			; and OR it with the volume
			ld b,PANNING_NONE
			ld e,a ; backup cvol in e
			ld a,iyl 
			cp a,0 ; cp a,0
			ld a,e ; store cvol back in a
			jp z,adpcma_keep_panning_none$
			ld de,PA_channel_pannings-PA_channel_volumes
			add hl,de
			ld b,(hl)
adpcma_keep_panning_none$:
			or a,b ; ORs the volume and panning
			ld e,a
			
			; Set CVOL register
			ld a,c
			add a,REG_PA_CVOL
			ld d,a
			rst RST_YM_WRITEB
		pop de
	pop iy
	pop af
	pop bc
	pop hl
	ret

set_fm_channel_volume$:
		sub a,MLM_CH_FM1 ; Transform into FMCNT channel range (6~9 -> 0~3)

		push ix
			; Obtain address to FM_Channel
			push af
				rlca       ; -\
				rlca       ;  | offset = channel*16
				rlca       ;  /
				rlca       ; /
				ld ixl,a
				ld ixh,0
				ld de,FM_ch1
				add ix,de
			pop af

			; Swap a and c again
			ld b,a
			ld a,c
			ld c,b

			srl a ; $00~$FF -> $00~$7F
			and a,127 ; Wrap volume inbetween 0 and 127
			ld (ix+FM_Channel.volume),a

			; set channel volume update flag
			ld a,(ix+FM_Channel.enable)
			or a,FMCNT_VOL_UPDATE
			ld (ix+FM_Channel.enable),a
		pop ix
	pop iy
	pop af
	pop bc
	pop hl
	ret

; Should be called after 
; setting the master volume
; clears do_reset_chvols
MLM_reset_channel_volumes:
	push af
	push bc
		; Load and negate master volume
		ld a,(master_volume)
		ld b,a
		ld a,$FF
		sub a,b
		ld b,a

ch_counter set 0
		dup PA_CHANNEL_COUNT
			; If channel is disabled, skip volume code
			ld a,(MLM_channel_control+ch_counter)
			or a,a
			jp z,$+48 ; Skips the whole cycle, onto the next loop. Update this if any piece of code below is changed

			; Load MLM volume, subtract mvol and 
			; scale the result down (0~255 -> 0~31)
			ld a,(MLM_channel_volumes+ch_counter)
			sub a,b
			jp nc,$+5 ; +3 = 3b
			ld a,0    ; +2 = 5b
			sub a,b
			jp nc,$+5 ; +3 = 3b
			ld a,0    ; +2 = 5b
			ld iyl,a

			rrca
			rrca
			rrca
			and a,$1F
			
			ld (PA_channel_volumes+ch_counter),a
			ld c,a
			ld a,(PA_channel_pannings+ch_counter)
			or a,c

			; if the scaled MLM chvol isn't 0, load 
			; panning from PA_channel_pannings[channel]
			; and OR it with the volume
			ld d,PANNING_NONE
			ld e,a            ; backup cvol in e
			ld a,iyl 
			or a,a ; cp a,0
			jr z,$+6                              ; +2 = 2b
			ld a,(PA_channel_pannings+ch_counter) ; +3 = 5b
			ld d,a                                ; +1 = 6b
			ld a,e                                

			or a,d ; ORs the volume and panning

			; Set CVOL register
			ld e,a
			ld d,REG_PA_CVOL+ch_counter
			rst RST_YM_WRITEB

ch_counter set ch_counter+1
		edup

ch_counter set 0
		dup FM_CHANNEL_COUNT
			; Load MLM volume, subtract mvol and 
			; scale the result down (0~255 -> 0~127)
			ld a,(MLM_channel_volumes+MLM_CH_FM1+ch_counter)
			sub a,b
			jp nc,$+5 ; +3 = 3b
			ld a,0    ; +2 = 5b
			srl a
			and a,127

			ld (FM_ch1+(ch_counter*FM_Channel.SIZE)+FM_Channel.volume),a
			ld a,(FM_ch1+(ch_counter*FM_Channel.SIZE)+FM_Channel.enable)
			or a,FMCNT_VOL_UPDATE
			ld (FM_ch1+(ch_counter*FM_Channel.SIZE)+FM_Channel.enable),a
ch_counter set ch_counter+1
		edup

ch_counter set 0
		dup SSG_CHANNEL_COUNT
			; Load MLM volume, subtract mvol and 
			; scale the result down (0~255 -> 0~15)
			ld a,(MLM_channel_volumes+MLM_CH_SSG1+ch_counter)
			sub a,b
			jp nc,$+5 ; +3 = 3b
			ld a,0    ; +2 = 5b
			rrca
			rrca
			rrca
			rrca
			and a,$0F

			ld (SSGCNT_volumes+ch_counter),a
ch_counter set ch_counter+1
		edup

		xor a,a
		ld (do_reset_chvols),a
	pop bc
	pop af
	ret

; a: channel
; c: panning (LR------)
; TO REFACTOR. USING A VECTOR ARRAY FOR THIS IS STUPID.
MLM_set_channel_panning:
	push hl
	push de
	push af
		ld h,0
		ld l,a
		ld de,MLM_set_ch_pan_vectors
		add hl,hl
		add hl,de
		ld e,(hl)
		inc hl
		ld d,(hl)
		ex de,hl
		jp (hl)
MLM_set_ch_pan_ret:
	pop af
	pop de
	pop hl
	ret

MLM_set_ch_pan_vectors:
	dw MLM_set_ch_pan_PA,MLM_set_ch_pan_PA
	dw MLM_set_ch_pan_PA,MLM_set_ch_pan_PA
	dw MLM_set_ch_pan_PA,MLM_set_ch_pan_PA
	dw MLM_set_ch_pan_FM,MLM_set_ch_pan_FM
	dw MLM_set_ch_pan_FM,MLM_set_ch_pan_FM
	dw MLM_set_ch_pan_ret,MLM_set_ch_pan_ret
	dw MLM_set_ch_pan_ret ; SSG is mono

MLM_set_ch_pan_PA:
	call PA_set_channel_panning
	jr MLM_set_ch_pan_ret

MLM_set_ch_pan_FM:
	push bc
	push af
		sub a,MLM_CH_FM1
		ld b,c ; \
		ld c,a ; | swap a and c
		ld a,b ; /
		call FMCNT_set_panning
	pop af
	pop bc
	jr MLM_set_ch_pan_ret

; [INPUT]
;   c: channel
; [OUTPUT]
;   a: channel
; DOESN'T BACKUP HL AND DE
MLM_reset_pitch_ofs:
	ld a,c
	cp a,MLM_CH_FM1  ; if ch is ADPCMA...
	ret c            ; return.
	cp a,MLM_CH_SSG1 ; if ch is FM...
	jp c,channel_is_fm$

	; Else, ch is SSG...
	; Calculate address to channel's pitch offset
	ld hl,SSGCNT_pitch_ofs-(2*MLM_CH_SSG1)
	sla a ; a *= 2
	ld e,a
	ld d,0
	add hl,de

	; Clear pitch offset
	ld (hl),d
	inc hl
	ld (hl),d
	ret

channel_is_fm$:
	; Calculate address to channel's pitch offset
	ld hl,FM_ch1+FM_Channel.pitch_ofs-(FM_Channel.SIZE*MLM_CH_FM1)
	sla a ; -\
	sla a ;  | a *= 16 (FM_Channel.SIZE)
	sla a ;  /
	sla a ; /
	ld e,a
	ld d,0
	add hl,de

	; Clear pitch offset
	ld (hl),d
	inc hl
	ld (hl),d
	ret