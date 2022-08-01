; DOESN'T BACKUP REGISTERS
MLM_irq:
	ld a,(do_reset_chvols)
	or a,a ; cp a,0
	call nz,MLM_reset_channel_volumes
	ld a,(do_stop_song)
	or a,a ; cp a,0
	call nz,MLM_stop

	xor a,a ; clear a
	ld (MLM_active_ch_counter),a 

	ld c,0
	ld iy,MLM_channels
	ld de,MLM_Channel.SIZE
	dup CHANNEL_COUNT
		; If the channel is disabled, don't update playback...
		bit MLM_CH_ENABLE_BIT,(iy+MLM_Channel.flags)            
		jr z,$+5                          ; +2 = 2b
		call MLM_update_channel_playback  ; +3 = 5b

		inc c
		add iy,de
	edup

	; if active mlm channel counter is 0,
	; then all channels have stopped, proceed
	; to call MLM_stop
	ld a,(MLM_active_ch_counter)
	or a,a ; cp a,0
	call z,MLM_stop

	ret

; [INPUT]
; 	c: channel
;   iy: pointer to channel WRAM data
; Doesn't backup AF, HL, DE, B, IX, HL', BC' and DE'
; OPTIMIZED
MLM_update_channel_playback:
	push iy
		ld a,(MLM_active_ch_counter)
		inc a 
		ld (MLM_active_ch_counter),a

		; decrement timing,
		; if afterwards it isn't 0 return
		ld a,(iy+MLM_Channel.timing)
		dec a 
		ld (iy+MLM_Channel.timing),a 
		or a,a ; cp a,0
		jp nz,return$

parse_event$:
		brk
		push hl
			; if the note's first byte is cleared,
			; parse it as a command.
			; If it's set, parse it as a note.
			ld hl,(iy+MLM_Channel.playback_ptr)
			ld a,(hl)
			bit 7,a
			call z,MLM_parse_command
			call nz,MLM_parse_note
		pop hl

		ld a,(iy+MLM_Channel.set_timing)
		or a,a ; cp 0,0
		jr z,parse_event$
return$:
	pop iy
	ret

; c: channel
; hl: pointer to note in sdata
; iy: pointer to MLM_Channel
; DOESN'T BACKUP AF, HL
MLM_parse_note:
	push bc 
		ld a,(hl)
		and a,$7F ; Clear bit 7 of the note's first byte
		ld b,a    ; move timing in b
		ld a,c    ; move channel in a
		inc hl
		ld c,(hl)
		inc hl
		
		; if (channel < 6) MLM_parse_note_pa()
		cp a,MLM_CH_FM1
		jp c,play_adpcma_note$

		cp a,MLM_CH_SSG1
		jp c,play_fm_note$
		
		; Else, Play note SSG...
		sub a,MLM_CH_SSG1
		call SSGCNT_set_note
		call SSGCNT_enable_channel
		call SSGCNT_start_channel_macros

		add a,MLM_CH_SSG1
		ld c,b
		call MLM_set_timing
parse_end$:
		ld (iy+MLM_Channel.playback_ptr),hl
	pop bc
	ret 

; a:  channel
; bc: source   (-TTTTTTT SSSSSSSS (Timing; Sample))
; iy: pointer to MLM_Channel
; Doesn't backup BC, IX
play_adpcma_note$:
	push de
	push hl
		; Load pointer to instrument data
		; from WRAM into de
		push af
			ld a,(MLM_instruments)
			ld e,a
			ld a,(MLM_instruments+1)
			ld d,a

			; Calculate pointer to the current
			; instrument's data and store it in hl
			ld l,(iy+MLM_Channel.instrument)
			ld h,0
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
			ld de,hl

			; Check if sample id is valid;
			; if it isn't softlock.
			ld a,c
			cp a,(hl)
			jp nc,softlock ; if smp_id >= smp_count
			inc de ; Increment past sample count
		pop af

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
	jp parse_end$


; a:  channel+6
; bc: source (-TTTTTTT -OOONNNN (Timing; Octave; Note))
; iy: pointer to MLM_Channel
; Doesn't backup AF, IX, and C
play_fm_note$:
	push de
	push hl
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
		push iy
			ld iyh,c
			ld iyl,a
			call FMCNT_set_note
		pop iy
		
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
	pop hl
	pop de
	jp parse_end$

;   c:  channel
;   hl: source (playback pointer)
;   iy: pointer to MLM_Channel
MLM_parse_command:
	push bc
	push hl
	push de
	push af
		; backup the command's first byte into ixl
		ld a,(hl)
		ld ixl,a

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
		jr z,execute$

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

execute$:
		ld (iy+MLM_Channel.playback_ptr),hl
		
		; By pushing the return address to the stack,
		; functions can use the ret instruction to
		; return, making them more versatile.
		ex hl,de
		ld de,command_end$
		push de
		jp (hl)
command_end$:
	pop af
	pop de
	pop hl
	pop bc
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
		ld iy,MLM_channels
		ld de,MLM_Channel.SIZE
		ld b,1

		dup CHANNEL_COUNT
			call MLM_playback_init
			add iy,de
			inc b
			inc hl 
			inc hl
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

		; Set ADPCM-A master volume
		ld de,REG_PA_MVOL<<8 | $3F
		rst RST_YM_WRITEB

		; For each channel initialize its
		; parameters if it is enabled.
		ld iy,MLM_channels
		ld de,MLM_Channel.SIZE
		ld b,1
		dup CHANNEL_COUNT
			call MLM_ch_parameters_init
			add iy,de
			inc b
		edup
	pop af
	pop ix
	pop de
	pop bc
	pop hl
	ret
	
; b:  channel+1
; iy: pointer to MLM_Channel
; hl: song_header[ch]
; DOESN'T BACKUP AF 
MLM_playback_init:
	push hl
	push bc
		; Set the channel timing to 1
		ld a,b
		dec a
		ld c,1
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

		; store said pointer into WRAM
		ld (iy+MLM_Channel.playback_ptr+0),c 
		ld (iy+MLM_Channel.playback_ptr+1),a
		ld (iy+MLM_Channel.start_ptr+0),c 
		ld (iy+MLM_Channel.start_ptr+1),a

		; If the playback pointer isn't
		; equal to 0, set the channel's
		; playback control to $FF, and
		; also set SFXPS ch. status to taken
		ld hl,0
		or a,a ; Clear carry flag
		sbc hl,bc
		jr z,no_playback$
		ld (iy+MLM_Channel.flags),MLM_CH_ENABLE ; Set playback control channel enable flag
no_playback$:
	pop bc
	pop hl
	ret

; b: channel+1
; iy: pointer to MLM_Channel
; DOESN'T BACKUP AF AND BC
;	Initializes channel parameters
MLM_ch_parameters_init:
	bit MLM_CH_ENABLE_BIT,(iy+MLM_Channel.flags)
	ret z 

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
	ret

; a: channel
init_adpcma_channel$:
	; Tell SFXPS that this channel  
	; is reserved for music playback
	ld c,a
	call SFXPS_set_channel_as_taken 
	ret

; a: channel
init_fm_channel$:
	; Enable FMCNT for the channel
	sub a,MLM_CH_FM1 ; Calculate FM channel range (6~9 -> 0~3)
	ld c,a
	call FMCNT_enable_channel
	ret

; a: instrument
; c: channel
; iy: pointer to MLM_Channel
; COULD OPTIMIZE
MLM_set_instrument:
	push bc
	push af
		ld (iy+MLM_Channel.instrument),a

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
	pop bc
	ret

; a:  channel
; iy: pointer to MLM_Channel
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
		ld l,(iy+MLM_Channel.instrument)
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
; iy: pointer to MLM_Channel
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
		ld l,(iy+MLM_Channel.instrument)
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

; iy: pointer to MLM_Channel
; c: timing
MLM_set_timing:
	ld (iy+MLM_Channel.timing),c
	ld (iy+MLM_Channel.set_timing),c
	ret

; a: channel (MLM)
; OPTIMIZED
MLM_stop_note:
	push af
		cp a,MLM_CH_FM1
		jp c,channel_is_adpcma$

		cp a,MLM_CH_SSG1
		jp c,channel_is_fm$

		; Else, Stop SSG note...
		sub a,MLM_CH_SSG1
		call SSGCNT_disable_channel
	pop af
	ret

channel_is_adpcma$:
		call PA_stop_sample
	pop af
	ret

channel_is_fm$:
	push bc
		sub a,MLM_CH_FM1
		ld c,a
		call FMCNT_stop_channel
	pop bc
	pop af
	ret

; a: volume
; c: channel
; iy: pointer to MLM_Channel
;	This sets MLM_channel_volumes,
;   the register writes are done in
;   the IRQ
MLM_set_channel_volume:
	push hl
	push bc
	push af
	push ix
		ld (iy+MLM_Channel.volume),a

		; If master volume is 255, there's 
		; no need to alter the volume
		ld ixh,b ; b is 0
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
		ld ixl,a ; backup negated mvol in ixl...
		ld ixh,a ; ...and ixh
		ld a,b   ; store cvol back in a
		sub a,ixl

		jp nc,skip_mvol_calculation$ ; if no overflow happened...
		ld a,0 ; if underflow happened, take care of it

skip_mvol_calculation$:
		ld ixl,a ; Backup scaled MLM chvol 

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
	pop ix
	pop af
	pop bc
	pop hl
	ret

set_adpcma_channel_volume$:
		; Swap a and c again
		ld b,a
		ld a,c
		ld c,b

		sub a,ixh
		jp nc,$+5 ; +3 = 3b
		ld a,0    ; +2 = 5b
		ld ixl,a 

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
			ld a,ixl 
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
	pop ix
	pop af
	pop bc
	pop hl
	ret

set_fm_channel_volume$:
		sub a,MLM_CH_FM1 ; Transform into FMCNT channel range (6~9 -> 0~3)

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
			; Load MLM volume, subtract mvol and 
			; scale the result down (0~255 -> 0~31)
			ld a,(MLM_channels+(MLM_Channel.SIZE*ch_counter)+MLM_Channel.volume)
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
			ld a,(MLM_channels+(MLM_Channel.SIZE*(MLM_CH_FM1+ch_counter))+MLM_Channel.volume)
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
			ld a,(MLM_channels+(MLM_Channel.SIZE*(MLM_CH_SSG1+ch_counter))+MLM_Channel.volume)
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