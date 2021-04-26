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
	inc b
	djnz SSGCNT_irq_vol_loop

	call SSGCNT_update_mixing
	call SSGCNT_update_noise_tune
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
; NEGATIVE ENABLE!
SSGCNT_set_mixing:
	push af
	push bc
	push hl
		; bit <<= ssg_channel + flag_type
		ld a,e
		add a,d
		ld b,a
		call shift_left_c_by_b_bits

		; mix_flags = ~bit & SSGCNT_mix_flags
		ld hl,SSGCNT_mix_flags
		ld a,c
		xor a,&FF
		and a,(hl)

		; mix_flags |= bit
		or a,c
		ld (hl),a
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

; ==== LOOKUP TABLES ====
SSGCNT_note_LUT:
	incbin "ssg_pitch_lut.bin"