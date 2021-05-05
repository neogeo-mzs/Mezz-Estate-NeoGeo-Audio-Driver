ssg_stop:
	push de
		ld de,(REG_SSG_CHA_VOL<<8) | &00
		rst RST_YM_WRITEA
		ld de,(REG_SSG_CHB_VOL<<8) | &00
		rst RST_YM_WRITEA
		ld de,(REG_SSG_CHC_VOL<<8) | &00
		rst RST_YM_WRITEA

		ld de,(REG_SSG_MIX_ENABLE<<8) | &3F
		rst RST_YM_WRITEA
	pop de
	ret

SSGCNT_init:
	push bc
	push af
	push de
	push hl
		; clear SSGCNT WRAM
		ld hl,SSGCNT_wram_start
		ld de,SSGCNT_wram_start+1
		ld bc,SSGCNT_wram_end-SSGCNT_wram_start-1
		ld (hl),0
		ldir

		ld b,3
SSGCNT_init_loop:
		ld a,b
		dec a

		; Set default volume
		ld c,15
		call SSGCNT_set_vol

		djnz SSGCNT_init_loop
	pop hl
	pop de
	pop af
	pop bc
	ret

; DOESN'T BACKUP REGISTERS!!
SSGCNT_irq:
	ld b,3

SSGCNT_irq_vol_loop:
	dec b
	call SSGCNT_update_volume
	call SSGCNT_update_note
	call SSGCNT_update_channels_mix
	inc b
	djnz SSGCNT_irq_vol_loop

	call SSGCNT_update_mixing
	call SSGCNT_update_noise_tune

	; Update all macros
	ld b,7              ; total amount of macros
	ld de,SSGCNT_macro  ; de = sizeof(SSGCNT_macro)
	ld ix,SSGCNT_macros
SSGCNT_irq_vol_macro_loop:
	call SSGCNT_MACRO_update
	add ix,de
	djnz SSGCNT_irq_vol_macro_loop

	ret

; b: channel (0~2)
SSGCNT_update_volume:
	push hl
	push de
	push af
	push bc
		; Load SSGCNT_channel_enable[ch]
		; in a
		ld hl,SSGCNT_channel_enable
		ld e,b
		ld d,0
		add hl,de
		ld a,(hl)

		; If channel enable is 1, set volume
		; to SSGCNT_volumes[channel]; else
		; set it to 0
		ld c,0
		or a,a ; cp a,0
		jr z,SSGCNT_update_volume_ch_disabled

		; Load SSGCNT_volumes[channel]
		; in c
		ld hl,SSGCNT_volumes
		add hl,de
		ld c,(hl)

SSGCNT_update_volume_ch_disabled:
		; Calculate the register address
		ld a,REG_SSG_CHA_VOL
		add a,b
		ld d,a
		ld e,c

		rst RST_YM_WRITEA
	pop bc
	pop af
	pop de
	pop hl
	ret

; b: channel (0~2)
SSGCNT_update_note:
	push hl
	push de
	push af
		; Load SSGCNT_notes[channel]
		; into l
		ld hl,SSGCNT_notes
		ld e,b
		ld d,0
		add hl,de
		ld l,(hl)

		; Calculate pointer to
		; SSGCNT_note_LUT[note]
		ld h,0
		ld de,SSGCNT_note_LUT
		add hl,hl
		add hl,de

		; Load fine tune and write
		; it to correct register
		ld a,REG_SSG_CHA_FINE_TUNE
		add a,b ; - a += b*2
		add a,b ; /
		ld d,a
		ld e,(hl)
		rst RST_YM_WRITEA

		; Load coarse tune and write
		; it to the correct register
		inc d
		inc hl
		ld e,(hl)
		rst RST_YM_WRITEA
	pop af
	pop de
	pop hl
	ret

; b: channel (0~2)
;	Updates the channel's mixing according to the macros,
;   if the channel's mix macros are disabled this won't
;   do anything, and the mixing values set manually won't
;   be overwritten.
SSGCNT_update_channels_mix:
	push ix
	push de
	push af
	push bc
		; Load channel's mix macro enable in a
		ld ixl,b
		ld ixh,0
		ld de,SSGCNT_mix_macro_A
		add ix,ix ; \
		add ix,ix ; | hl *= 8
		add ix,ix ; /
		add ix,de
		ld a,(ix+SSGCNT_macro.enable)

		; If the selected channel's mix macro is
		; disabled (enable == $00) then return
		or a,a ; cp a,0
		jr z,SSGCNT_update_mixing_macros_return

		call SSGCNT_NMACRO_read ; Stores macro value in a
		brk

		ld ixl,a ; backup macro value in ixl
		ld d,b   ; backup channel in d (channel parameter)

		; Enable tone if the mixing's byte
		; bit 0 is 1, else disable it
		and a,%00000001 ; Get tone enable bit
		ld c,a                    ; Enable/Disable parameter
		ld e,SSGCNT_MIX_EN_TUNE   ; Tune/Noise select parameter
		call SSGCNT_set_mixing

		; Enable noise if the mixing's byte
		; bit 1 is 1, else disable it
		ld a,ixl
		and a,%00000010 ; Get noise enable bit
		srl a
		ld c,a                   ; Enable/Disable parameter
		ld e,SSGCNT_MIX_EN_NOISE ; Tune/Noise select parameter
		call SSGCNT_set_mixing

SSGCNT_update_mixing_macros_return:
	pop bc
	pop af
	pop de
	pop ix
	ret

; This just flips the SSGCNT_mix_flags byte and
; sets the YM2610's registers accordingly
SSGCNT_update_mixing:
	push de
	push af
		ld d,REG_SSG_MIX_ENABLE
		ld a,(SSGCNT_mix_flags)
		xor a,&3F ; Flip all flags, since the SSG mixing register uses negative enable flags
		ld e,a
		rst RST_YM_WRITEA
	pop af
	pop de
	ret

SSGCNT_update_noise_tune:
	push de
	push af
		ld d,REG_SSG_CHN_NOISE_TUNE
		ld a,(SSGCNT_noise_tune)
		ld e,a
		rst RST_YM_WRITEA
	pop af
	pop de
	ret

; a: channel
; c: volume
SSGCNT_set_vol:
	push bc
	push hl
	push af
		ld b,a ; \
		ld a,c ; | Swap a and c
		ld c,b ; /

		ld b,0
		ld hl,SSGCNT_volumes
		add hl,bc
		ld (hl),a
	pop af
	pop hl
	pop bc
	ret

; a: noise tune
; 	Everyone needs a useless
;	subroutine that is there
;	only for consistency!
SSGCNT_set_noise_tune:
	ld (SSGCNT_noise_tune),a
	ret

; a: channel
; c: note
SSGCNT_set_note:
	push bc
	push hl
	push af
		ld b,a ; \
		ld a,c ; | Swap a and c
		ld c,b ; /

		ld b,0
		ld hl,SSGCNT_notes
		add hl,bc
		ld (hl),a
	pop af
	pop hl
	pop bc
	ret

; e: flag type to set/clear (SSGCNT_MIX_EN_TUNE = 0; SSGCNT_MIX_EN_NOISE = 3)
; d: SSG channel (0~2)
; c: 0 if the flag needs to be cleared, 1 if the flag needs to be set
; POSITIVE ENABLE!
SSGCNT_set_mixing:
	push af
	push bc
	push hl
	push de
		; bit <<= ssg_channel + flag_type
		ld a,e
		add a,d
		ld b,a
		call shift_left_c_by_b_bits ; Clears b
		ld a,e   ; \
		add a,d  ; | Calculate b again
		ld b,a   ; /
		ld e,c ; backup bit in e

		; Calculate mask
		;	mask = 1 << (ssg_channel + flag_type)
		ld c,1
		call shift_left_c_by_b_bits

		; mix_flags = ~mask & SSGCNT_mix_flags
		ld hl,SSGCNT_mix_flags
		ld a,c
		xor a,&FF
		and a,(hl)

		; mix_flags |= bit
		or a,e
		ld (hl),a
	pop de
	pop hl
	pop bc
	pop af
	ret

; a: channel
SSGCNT_enable_channel:
	push hl
	push de
		ld hl,SSGCNT_channel_enable
		ld e,a
		ld d,0
		add hl,de
		ld (hl),&FF
	pop de
	pop hl
	ret

; a: channel
SSGCNT_disable_channel:
	push hl
	push de
		ld hl,SSGCNT_channel_enable
		ld e,a
		ld d,0
		add hl,de
		ld (hl),0
	pop de
	pop hl
	ret

; [INPUT]
; 	ix: pointer to macro
; [OUTPUT]
;	a:  Current macro value
; CHANGES FLAGS!!
SSGCNT_BMACRO_read:
	push hl
	push de
		; a = macro.data[macro.curr_pt]
		ld l,(ix+SSGCNT_macro.data)
		ld h,(ix+SSGCNT_macro.data+1)
		ld e,(ix+SSGCNT_macro.curr_pt)
		ld d,0
		add hl,de
		ld a,(hl)
	pop de
	pop hl
	ret

; [INPUT]
; 	ix: pointer to macro
; [OUTPUT]
;	a:  Current macro value
; CHANGES FLAGS!!
SSGCNT_NMACRO_read:
	push hl
	push de
		; Load byte containing the value
		; by adding to the macro data 
		; pointer curr_pt divided by two
		ld l,(ix+SSGCNT_macro.data)
		ld h,(ix+SSGCNT_macro.data+1)
		ld a,(ix+SSGCNT_macro.curr_pt)
		srl a
		ld e,a ; e = macro.curr_pt / 2
		ld d,0
		add hl,de
		ld a,(hl)

		; If macro.curr_pt is even, then
		; return the least significant nibble,
		; else return the most significant one.
		bit 0,e
		jr z,SSGCNT_NMACRO_read_even_pt

		srl a ; \
		srl a ;  | a >>= 4
		srl a ;  | (VVVV---- => 0000VVVV)
		srl a ; /

SSGCNT_NMACRO_read_even_pt:
		and a,&0F
	pop de
	pop hl
	ret

; ix: pointer to macro
SSGCNT_MACRO_update:
	push af
		; If macro.loop_pt is bigger or equal 
		; than the actual length, set it to
		; the length minus 1 (remember that
		; the length is always stored 
		; decremented by one)
		ld a,(ix+SSGCNT_macro.length)
		cp a,(ix+SSGCNT_macro.loop_pt)
		jr nc,SSGCNT_MACRO_update_valid_loop_pt ; if macro.length >= macro.loop_pt ...

		ld (ix+SSGCNT_macro.loop_pt),a ; macro.loop_pt = macro.length (length is stored decremented by 1)
SSGCNT_MACRO_update_valid_loop_pt:

		; increment macro.curr_pt, if it
		; overflows set it to macro.loop_pt
		inc (ix+SSGCNT_macro.curr_pt)
		cp a,(ix+SSGCNT_macro.curr_pt)
		jr nc,SSGCNT_MACRO_update_return ; if macro.length >= macro.curr_pt

		ld a,(ix+SSGCNT_macro.loop_pt)
		ld (ix+SSGCNT_macro.curr_pt),a

SSGCNT_MACRO_update_return:
	pop af
	ret

; ix: pointer to macro
; hl: pointer to macro initialization data
SSGCNT_MACRO_set:
	push af
	push hl
	push de
		; Disable macro, if needed it'll be 
		; enabled later in the function
		ld (ix+SSGCNT_macro.enable),&00

		; If the pointer to the macro initialization 
		; data is &0000, then return from the subroutine
		ld de,0
		or a,a    ; Clear carry flag
		sbc hl,de ; cp hl,de
		jr z,SSGCNT_MACRO_set_return

		; Set macro's length
		ld a,(hl)
		ld (ix+SSGCNT_macro.length),a

		; Set macro's loop point
		inc hl
		ld a,(hl)
		ld (ix+SSGCNT_macro.loop_pt),a

		; Set macro's data pointer
		inc hl
		ld (ix+SSGCNT_macro.data),l
		ld (ix+SSGCNT_macro.data+1),h

		; Set other variables
		ld (ix+SSGCNT_macro.enable),&FF
		ld (ix+SSGCNT_macro.curr_pt),0
SSGCNT_MACRO_set_return:
	pop de
	pop hl
	pop af
	ret

; a: channel
;  Set's all channel's macros
SSGCNT_start_channel_macros:
	push ix
	push de
		; Calculate address to channel's mix macro,
		; and set macro.curr_pt to 0
		ld ixl,a
		ld ixh,0
		ld de,SSGCNT_mix_macro_A
		add ix,ix ; \
		add ix,ix ; | ix *= 8
		add ix,ix ; /
		add ix,de
		ld (ix+SSGCNT_macro.curr_pt),0

		; TODO: other macros
	pop de
	pop ix
	ret

; ==== LOOKUP TABLES ====
SSGCNT_note_LUT:
	incbin "ssg_pitch_lut.bin"

SSGCNT_vol_LUT:
	incbin "ssg_vol_lut.bin"
	