; DOESN'T SAVE REGISTERS
COM_irq:
	; Load the pointer to the 
	; assigned buffer in ix
	ld a,(com_buffer_select)
	ld ix,com_buffers        
	cp a,0                        ; if buffer select 
	jr z,COM_irq_use_first_buffer ; is 0, use 1st buffer
	ld de,ComBuffer ; If it isn't, use the 2nd
	add ix,de       ; buffer

COM_irq_use_first_buffer:
	; If ComBuffer.mlm_is_play_song_requested is 1,
	; play the song in ComBuffer.mlm_requested_song.
	ld a,(ix+ComBuffer.mlm_requested_song)
	ld c,(ix+ComBuffer.mlm_is_play_song_requested)
	dec c                ; if c is equal to 0,
	call z,MLM_play_song ; call MLM_play_song

	; If ComBuffer.mlm_is_stop_song_requested 
	; is 1, stop the song.
	ld a,(ix+ComBuffer.mlm_is_stop_song_requested)
	dec a
	call z,MLM_stop

	; Clear assigned buffer
	ld e,ixl ; - Load pointer to buffer in de
	ld d,ixh ; /
	ld l,e   ; - Load pointer to buffer in hl
	ld h,d   ; /
	inc de
	ld bc,ComBuffer-1
	ld (hl),0
	ldir     ; Memory fills the buffer with 0

	; Flip buffer select
	ld a,(com_buffer_select)
	xor a,1
	ld (com_buffer_select),a
	ret

command_nop:
	jp NMI_execute_command_end

;==============================================================================;
; command01_Setup
; Handles the setup for calling command $01.

command01_Setup:
	xor  a
	out  (0xC),a
	out  (0),a
	ld   sp,0xFFFC

	; set up Command $01's address on the stack
	ld   hl,command_01
	push hl
	retn
	; execution continues at command_01

;==============================================================================;
; command_01
; Slot switch.

command_01:
	di
	xor  a
	out  (0xC),a
	out  (0),a

	call SetDefaultBanks

	; [FM] Turn off Left/Right output (and AM/PM Sense)
	ld   de,0xB500
	call write45
	call write67
	ld   de,0xBb00
	call write45
	call write67

	; [ADPCM-A, ADPCM-B] reset ADPCM channels
	ld   de,0x00BF ; $00BF: ADPCM-A dump flag = 1, all channels = 1
	call write67
	ld   de,0x1001 ; $1001: ADPCM-B reset flag = 1
	call write45

	; [ADPCM-A, ADPCM-B] poke ADPCM channel flags
	ld   de,0x1CBF ; $1CBF: Reset flags for ADPCM-A 1-6 and ADPCM-B
	call write45
	ld   de,0x1C00 ; $1C00: Enable flags for ADPCM-A 1-6 and ADPCM-B
	call write45

	; silence FM channels
	ld   de,0x2801 ; FM channel 1 (1/4)
	call write45
	ld   de,0x2802 ; FM channel 2 (2/4)
	call write45
	ld   de,0x2805 ; FM channel 5 (3/4)
	call write45
	ld   de,0x2806 ; FM channel 6 (4/4)
	call write45

	; silence SSG channels
	ld   de,0x800 ; SSG Channel A
	call write45
	ld   de,0x900 ; SSG Channel B
	call write45
	ld   de,0xA00 ; SSG Channel C
	call write45

	; set up infinite loop at the end of RAM.
	ld   hl,0xFFFD
	ld   (hl),0xC3 ; Set 0xFFFD = 0xC3 ($C3 is opcode for "jp")
	ld   (0xFFFE),hl ; Set 0xFFFE = 0xFFFD (making "jp $FFFD")

	ld   a,1
	out  (0xC),a ; Write 1 to port 0xC (Reply to 68K)
	jp   0xFFFD ; jump to infinite loop in RAM

;==============================================================================;
; command03_Setup
; Handles the setup for calling command $03.

command03_Setup:
	xor  a
	out  (0xC),a
	out  (0),a
	ld   sp,0xFFFC

	; set up Command $03's address on the stack
	ld   hl,command_03
	push hl
	retn
	; execution continues at command_03

;==============================================================================;
; command_03
; Handles a soft reset.

command_03:
	di
	xor  a
	out  (0xC),a
	out  (0),a
	ld   sp,0xFFFF
	jp   Start

; Command &0A
command_stop_ssg:
	push hl
	push de
	push bc
		; Clear SSG variables
		ld hl,ssg_vol_macros
		ld de,ssg_vol_macros+1
		ld bc,17
		ld (hl),0
		ldir

		ld d,REG_SSG_CHA_VOL
		ld e,0
		rst RST_YM_WRITEA

		inc d
		rst RST_YM_WRITEA

		inc d
		rst RST_YM_WRITEA
	pop bc
	pop de
	pop hl
	jp NMI_execute_command_end

; Command &0B
command_silence_fm:
	push de
		ld d,REG_FM_KEY_ON
		ld e,FM_CH1
		rst RST_YM_WRITEA

		ld d,REG_FM_KEY_ON
		ld e,FM_CH2
		rst RST_YM_WRITEA

		ld d,REG_FM_KEY_ON
		ld e,FM_CH3
		rst RST_YM_WRITEA

		ld d,REG_FM_KEY_ON
		ld e,FM_CH4
		rst RST_YM_WRITEA
	pop de
	jp NMI_execute_command_end

; Command &0C
command_stop_adpcma:
	push de
		ld de,REG_PA_CTRL<<8 | %10111111
		rst RST_YM_WRITEB
	pop de
	jp NMI_execute_command_end

; Command &0F
; Arguments 
;    1. SFX IDX LSB
;    2. LR-CCCCC (play on Left speaker, play on Right speaker, Channel volume)
;    3. channel
command_play_adpcma_sample:
	push af
	push hl
	push de
	push ix
		ld de,REG_P_FLAGS<<8 | %00111111
		rst RST_YM_WRITEB

		ld ix,com_arg_buffer

		; Set sample addr
		ld a,(ix+0) ; load argument 3
		and a,%00001000 ; Get sample MSB
		srl a ; -S--
		srl a ; --S-
		srl a ; ---S
		ld d,a
		ld e,(ix+2) ; load argument 1

		ld a,(ix+0) ; load argument 3
		and a,%00000111 ; Get channel
		call PA_set_sample_addr

		; Set channel volume
		ld d,REG_PA_CVOL
		add a,d
		ld d,a
		ld a,(ix+1) ; load argument 2
		ld e,a 
		rst RST_YM_WRITEB

		; PA play sample
		ld a,(ix+0) ; load argument 3
		and a,%00000111 ; Get channel
		ld h,0
		ld l,a
		ld de,PA_channel_on_masks
		add hl,de

		ld d,REG_PA_CTRL
		ld e,(hl) 
		rst RST_YM_WRITEB
	pop ix
	pop de
	pop hl
	pop af
	jp NMI_execute_command_end

; Command &13
; Arguments:
;   1. Volume
command_set_adpcma_mvol:
	push hl
	push de
		ld hl,com_arg_buffer
		ld d,REG_PA_MVOL
		ld e,(hl) ; Load argument 1
		rst RST_YM_WRITEB
	pop de
	pop hl
	jp NMI_execute_command_end

; Command &14
;   the driver uses timer b to time IRQs.
;   the formula of the frequency is:
;      256 - (s * 4000000 / 1152)
;   for example, to call IRQ 60 times a second,
;   the formula would be:
;      256 - (1/60 * 4000000 / 1152) = 198
;
; Arguments:
;   1. freq 
command_set_irq_freq:
	push hl
	push de
		ld hl,com_arg_buffer
		ld e,(hl)
		call TMB_set_counter_load
	pop de
	pop hl
	jp NMI_execute_command_end

; Command &15
;   == Pitch ==
;     The formula to calculate the note is:
;       ((octave - 2) * 24) + (note*2)
;     for example, to play the note A4,
;     the formula would be:
;       66 = ((4 - 2) * 24) + (9*2)
; Arguments:
;   1. note
;   2. instrument
;   3. AAAA--CC (Attenuator; Channel)
command_play_ssg_note:
	push ix
	push bc
	push af
		ld ix,com_arg_buffer

		ld a,(ix+0)     ; Load argument 3 (channel, volume)
		and a,%00000011 ; get channel
		ld c,(ix+2)     ; Load argument 1 (note)
		;ld b,1         ; do set ssg_base_notes
		call SSG_set_note

		ld b,a      ; backup channel into b
		ld a,(ix+0) ; Load argument 3 (channel, volume)
		and a,&F0   ; get attenuator
		srl a ; -AAAA---
		srl a ; --AAAA--
		srl a ; ---AAAA-
		srl a ; ----AAAA
		ld c,a ; attenuator value
		ld a,b ; channel
		call SSG_set_attenuator
		
		ld c,&0F    ; volume
		call SSG_set_volume

		ld c,(ix+1) ; Load argument 2 (instrument)
		call SSG_set_instrument
	pop af
	pop bc
	pop ix
	jp NMI_execute_command_end

; Command &16
; 
; Arguments:
;   1. -OOONNNN (Octave, Note)
;   2. instrument
;   3. attenuator
;   4. LR------ (Left on, Right on)
;   5. 4321-CCC (Operator slot, channel)
command_play_FM_note:
	push ix
	push af
	push de
	push bc
		ld ix,com_arg_buffer

		; Key Off
		ld d,REG_FM_KEY_ON
		ld a,(ix+0) ; Load argument 5
		and a,%00000111
		ld e,a
		rst RST_YM_WRITEA

		ld c,(ix+1)     ; Load argument 4
		ld a,(ix+0)     ; Load argument 5
		and a,%00000111 ; Get channel
		call FM_set_panning

		ld b,a
		ld c,(ix+3) ; Load argument 2
		call FM_load_instrument

		ld c,(ix+2) ; Load argument 3
		call FM_set_attenuator   

		ld c,(ix+4) ; Load argument 1
		call FM_set_note

		ld d,REG_FM_KEY_ON
		ld e,(ix+0) ; Load argument 5
		rst RST_YM_WRITEA
	pop bc
	pop de
	pop af
	pop ix
	jp NMI_execute_command_end

; Command &17:
; 
; Arguments:
;	1. song
command_play_song:
	push af
	push hl
	push ix
	push de
		ld a,&39
		ld (breakpoint),a

		; Load the pointer to the 
		; assigned buffer in ix
		ld a,(com_buffer_select)
		ld ix,com_buffers        
		cp a,1                                  ; if buffer select 
		jr z,command_play_song_use_first_buffer ; is 1, use 1st buffer
		ld de,ComBuffer ; If it isn't, use the 2nd
		add ix,de       ; buffer

command_play_song_use_first_buffer:
		; Set the assigned buffer
		ld (ix+ComBuffer.mlm_is_play_song_requested),1
		ld a,(com_arg_buffer)
		ld (ix+ComBuffer.mlm_requested_song),a
	pop de
	pop ix
	pop hl
	pop af
	jp NMI_execute_command_end

; Command &18
command_stop_song:
	push af
	push hl
	push ix
	push de
		ld a,&39
		ld (breakpoint),a
		
		; Load the pointer to the 
		; assigned buffer in ix
		ld a,(com_buffer_select)
		ld ix,com_buffers        
		cp a,1                                  ; if buffer select 
		jr z,command_stop_song_use_first_buffer ; is 1, use 1st buffer
		ld de,ComBuffer ; If it isn't, use the 2nd
		add ix,de       ; buffer

command_stop_song_use_first_buffer:
		; Set the assigned buffer
		ld (ix+ComBuffer.mlm_is_stop_song_requested),1
	pop de
	pop ix
	pop hl
	pop af
	jp NMI_execute_command_end