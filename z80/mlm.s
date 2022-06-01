; DOESN'T BACKUP REGISTERS
MLM_irq:
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

MLM_update_skip:
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
MLM_update_channel_playback_exec_check:
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
				jp c,MLM_play_sample_pa

				cp a,MLM_CH_SSG1
				jp c,MLM_play_note_fm
				
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
		jr z,MLM_update_channel_playback_exec_check
	pop iy
	ret

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

		call ssg_stop
		call fm_stop
		call PA_reset
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
MLM_play_song_loop2:
		xor a,a
		cp a,(ix-1)
		call nz,MLM_ch_parameters_init
		dec ix
		djnz MLM_play_song_loop2
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
			jr z,MLM_playback_init_no_playback
			ld (ix+0),MLM_CH_ENABLE ; Set playback control channel enable flag
MLM_playback_init_no_playback:
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
		jr c,MLM_ch_parameters_init_pa ; then ...

		; If the channel is FM, initialize
		; specific FM parameters
		cp a,MLM_CH_SSG1               ; if a < MLM_CH_SSG1
		jr c,MLM_ch_parameters_init_fm     ; then ...

		; Else the channel is SSG, there's
		; no specific SSG parameters to set.
	pop bc
	pop af
	ret

; a: channel
MLM_ch_parameters_init_pa:
		; Tell SFXPS that this channel  
		; is reserved for music playback
		ld c,a
		call SFXPS_set_channel_as_taken 
	pop bc
	pop af
	ret

; a: channel
MLM_ch_parameters_init_fm:
		; Enable FMCNT for the channel
		sub a,MLM_CH_FM1 ; Calculate FM channel range (6~9 -> 0~3)
		ld c,a
		call FMCNT_enable_channel
	pop bc
	pop af
	ret

; [INPUT]
;   a:  channel
;   bc: source   (-TTTTTTT SSSSSSSS (Timing; Sample))
; Doesn't backup BC, IX and AF'
; OPTIMIZED
MLM_play_sample_pa:
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
MLM_play_note_fm:
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
		jr c,MLM_set_instrument_return ; then ...

		; If the channel is FM, branch
		cp a,MLM_CH_SSG1               ; if a < MLM_CH_SSG1
		jr c,MLM_set_instrument_fm     ; then ...

		; Else the channel is SSG, branch
		jr MLM_set_instrument_ssg
MLM_set_instrument_return: ;MLM_playback_init_no_playback:
	pop af
	pop hl
	pop bc
	ret

; a:  channel
; hl: $MLM_channel_instruments[channel]
MLM_set_instrument_fm:
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
	jr MLM_set_instrument_return

; a:  channel
; hl: $MLM_channel_instruments[channel]
MLM_set_instrument_ssg:
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
	jp MLM_set_instrument_return

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
		ld hl,master_volume
		ld b,(hl)
		inc b ; cp b,255
		jp z,MLM_set_channel_volume_skip_mvol_calc

		; Else, since cvol : 255 = x : mvol, calculate x using 
		; cvol*mvol / 256 (It's much faster to divide by 256 
		; than to divide by 255, a small error to pay for speed)
		push de
			ld h,(hl)
			ld e,a
			call H_Times_E
			add a,$80 ; Makes next "division" more accurate
			ld a,h    ; No division needs to be done, hl / 256 = h
		pop de

MLM_set_channel_volume_skip_mvol_calc:
		ld iyl,a ; Backup scaled MLM chvol 

		; Swap a and c
		ld b,a
		ld a,c
		ld c,b
		
		cp a,MLM_CH_FM1
		jp c,MLM_set_channel_volume_PA

		cp a,MLM_CH_SSG1
		jp c,MLM_set_channel_volume_FM

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

MLM_set_channel_volume_PA:
		; Swap a and c again
		ld b,a
		ld a,c
		ld c,b

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
			dec iyl ; - cp ixl,0
			inc iyl ; /
			jp z,MLM_set_channel_volume_PA_no_pan
			ld de,PA_channel_pannings-PA_channel_volumes
			add hl,de
MLM_set_channel_volume_PA_no_pan:
			or a,(hl) ; ORs the volume and panning
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

MLM_set_channel_volume_FM:
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

; TODO: REFACTOR
MLM_reset_active_chvols:
	jp softlock
	push ix
	push hl
	push de
	push iy
		; ==== RESET PA CHVOLS ====
		ld ix,MLM_channel_volumes
		ld hl,MLM_channel_control
		ld iy,PA_channel_volumes
MLM_reset_acvls_counter set 0
		dup PA_CHANNEL_COUNT
			bit 0,(hl)
			jr z,$+40+2                             ; +2  = 2b
			push hl                                 ; +37 = 39b
				; Else, since cvol : 255 = x : mvol, calculate x using 
				; cvol*mvol / 256 (It's much faster to divide by 256 
				; than to divide by 255, a small error to pay for speed)
				ld e,(ix+0)
				ld a,(master_volume)
				ld h,a
				call H_Times_E
				ld de,128 ; - Rounds the next "division"
				add hl,de ; /
				ld a,h    ; No division needs to be done, hl / 256 = h
                
				; Scale down volume
				; ($00~$FF -> $00~$1F)
				rrca
				rrca
				rrca
				and a,$1F

				; Store volume in 
				; PA_channel_volumes[channel]
				ld (iy+0),a

				; If MLM_volume isn't 0, OR volume 
				; with PA_channel_pannings[channel]
				dec h ; - cp h,0
				inc h ; /
				jr z,$+2+3                                       ; +2b
				or a,(iy+PA_channel_pannings-PA_channel_volumes) ; +3b                                         
				
				; Set CVOL register
				ld e,a 
				ld a,MLM_reset_acvls_counter
				add a,REG_PA_CVOL
				ld d,a
				rst RST_YM_WRITEB
			pop hl                                  ; +1  = 40b
			inc hl
			inc ix
MLM_reset_acvls_counter set MLM_reset_acvls_counter+1
		edup

		; ==== RESET FM CHVOLS ====
		;ld iy,FM_channel_volumes
MLM_reset_acvls_counter set 0
		dup FM_CHANNEL_COUNT
			bit 0,(hl)
			jr z,$+36+2                             ; +2  = 2b
			push hl                                 ; +33 = 35b 
				; Else, since cvol : 255 = x : mvol, calculate x using 
				; cvol*mvol / 256 (It's much faster to divide by 256 
				; than to divide by 255, a small error to pay for speed)
				ld e,(ix+0)
				ld a,(master_volume)
				ld h,a
				call H_Times_E
				ld de,128 ; - Rounds the next "division"
				add hl,de ; / 
				ld a,h    ; No division needs to be done, hl / 256 = h

				; Store volume in WRAM
				srl a     ; $00~$FF -> $00~$7F
				and a,127 ; Wrap volume inbetween 0 and 127
				ld (iy+MLM_reset_acvls_counter),a

				; set channel volume update flag
			;	ld hl,FM_channel_enable
				add hl,bc
			;	ld a,(iy+MLM_reset_acvls_counter+(FM_channel_enable-FM_channel_volumes))
				or a,FMCNT_VOL_UPDATE
			;	ld (iy+MLM_reset_acvls_counter+(FM_channel_enable-FM_channel_volumes)),a
			pop hl                                  ; +1  = 36b
			inc hl
			inc ix
MLM_reset_acvls_counter set MLM_reset_acvls_counter+1
		edup
		
		; ==== RESET SSG CHVOLS ====
		ld iy,SSGCNT_volumes
MLM_reset_acvls_counter set 0
		dup SSG_CHANNEL_COUNT
			bit 0,(hl)
			jr z,$+26+2                             
			push hl                                 
				; Else, since cvol : 255 = x : mvol, calculate x using 
				; cvol*mvol / 256 (It's much faster to divide by 256 
				; than to divide by 255, a small error to pay for speed)
				ld e,(ix+0)
				ld a,(master_volume)
				ld h,a
				call H_Times_E
				ld de,128 ; - Rounds the next "division"
				add hl,de ; / 
				ld a,h    ; No division needs to be done, hl / 256 = h

				; Scale down volume ($00~$FF -> $00~$0F)
				; and store result into SSGCNT WRAM
				rrca
				rrca
				rrca
				rrca
				and a,$0F
				ld (iy+MLM_reset_acvls_counter),a
			pop hl                                 
			inc hl
			inc ix
MLM_reset_acvls_counter set MLM_reset_acvls_counter+1
		edup
	pop iy
	pop de
	pop hl
	pop ix
	ret


MLM_reset_active_chvols_apply_mvol:
	
	ret

; a: channel
; c: panning (LR------)
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
	jp c,MLM_reset_pitch_ofs_fm

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

MLM_reset_pitch_ofs_fm:
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
	dw MLMCOM_invalid,              MLMCOM_porta_write
	dw MLMCOM_portb_write,          MLMCOM_set_timer_a
	dup 16
		dw MLMCOM_wait_ticks_nibble
	edup
	dw MLMCOM_return_from_sub_el,   MLMCOM_upward_pitch_slide
	dw MLMCOM_downward_pitch_slide, MLMCOM_reset_pitch_slide
	dup 4
		dw MLMCOM_FM_TL_set
	edup
	dw MLMCOM_set_pitch_macro
	dup 9
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
	db $01, $02, $01, $02, $01, $02, $02, $02
	ds 16, $00 ; Wait ticks nibble
	db $00, $01, $01, $00
	ds 4, $01 ; FM OP TL Set
	db $02
	ds 9, 0   ; Invalid commands have no arguments
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
MLMCOM_end_of_list_return:
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

MLMCOM_set_channel_panning_set_timing:
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
		jr nz,MLMCOM_porta_write_return

		; If address is equal to $27, then
		; store the data's 7th bit in WRAM
		ld a,e
		and a,%01000000 ; bit 6 enables 2CH mode
		ld (EXT_2CH_mode),a
		
MLMCOM_porta_write_return:
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
	; ADPCM-A channels have no pitch, return
	ld a,c 
	cp a,MLM_CH_FM1
	jp c,MLMCOM_pitch_slide_PA_ret

	; Else if FM, update FMCNT accordingly
	cp a,MLM_CH_SSG1
	jp c,MLMCOM_upward_pitch_slide_FM
	
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

		; Set timing to 0
		; (Execute next command immediately)
		ld a,c
		ld bc,0
		call MLM_set_timing
	pop de
	pop hl
	jp MLM_parse_command_end

MLMCOM_pitch_slide_PA_ret:
	; Set timing to 0
	; (Execute next command immediately)
	push af
		ld a,c
		ld bc,0
	pop af
	call MLM_set_timing
	jp MLM_parse_command_end

MLMCOM_upward_pitch_slide_FM:
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
	; ADPCM-A channels have no pitch, return
	ld a,c
	cp a,MLM_CH_FM1
	jp c,MLMCOM_pitch_slide_PA_ret

	; Else if FM, update FMCNT accordingly
	cp a,MLM_CH_SSG1
	jp c,MLMCOM_downward_pitch_slide_FM

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

		; Set timing to 0
		; (Execute next command immediately)
		ld a,c
		ld bc,0
		call MLM_set_timing
	pop hl
	jp MLM_parse_command_end

MLMCOM_downward_pitch_slide_FM:
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
	; ADPCM-A channels have no pitch, return
	ld a,c
	cp a,MLM_CH_FM1
	jp c,MLMCOM_pitch_slide_PA_ret

	; Else if FM, update FMCNT accordingly
	cp a,MLM_CH_SSG1
	jp c,MLMCOM_reset_pitch_slide_FM

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

		; Set timing to 0
		; (Execute next command immediately)
		ld a,c
		ld bc,0
		call MLM_set_timing
	pop hl
	jp MLM_parse_command_end

MLMCOM_reset_pitch_slide_FM:
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

		; Set timing to 0
		; (Execute next command immediately)
		ld a,c
		ld bc,0
		call MLM_set_timing
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
		jp z,MLMCOM_set_pitch_macro_reset

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

MLMCOM_set_pitch_macro_reset:
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
; de: playback pointer
MLMCOM_set_channel_volume_byte:
	ld a,c
	cp a,MLM_CH_FM1
	jp c,MLMCOM_set_channel_volume_byte_ADPCMA

	cp a,MLM_CH_SSG1
	jp c,MLMCOM_set_channel_volume_byte_FM

	jp MLMCOM_set_channel_volume_byte_SSG
MLMCOM_set_channel_volume_byte_ret:
	ld a,c
	ld bc,0
	call MLM_set_timing
	jp MLM_parse_command_end

; a: channel
; c: channel
; de: playback pointer
MLMCOM_set_channel_volume_byte_ADPCMA:
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
		jr z,MLMCOM_set_channel_volume_byte_ADPCMA_pos
		neg ; negates a

MLMCOM_set_channel_volume_byte_ADPCMA_pos:
		; Calculate address to channel volume
		ld hl,MLM_channel_volumes
		ld b,0
		add hl,bc

		; Add offset to channel volume
		add a,(hl)
		call MLM_set_channel_volume
	pop de
	pop hl
	jp MLMCOM_set_channel_volume_byte_ret

; a: channel
; c: channel
; de: playback pointer
MLMCOM_set_channel_volume_byte_FM:
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
		jr z,MLMCOM_set_channel_volume_byte_FM_pos
		neg ; negates a

MLMCOM_set_channel_volume_byte_FM_pos:
		; Calculate address to channel volume
		ld hl,MLM_channel_volumes
		ld b,0
		add hl,bc

		; Add offset to channel volume
		add a,(hl)
		call MLM_set_channel_volume
	pop de
	pop hl
	jp MLMCOM_set_channel_volume_byte_ret


; a: channel
; c: channel
; de: playback pointer
MLMCOM_set_channel_volume_byte_SSG:
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
	jp MLMCOM_set_channel_volume_byte_ret

; invalid command, plays a noisy beep
; and softlocks the driver
MLMCOM_invalid:
	call softlock