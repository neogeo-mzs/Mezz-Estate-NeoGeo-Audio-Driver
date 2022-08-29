ssg_stop:
	push de
		ld de,REG_SSG_CHA_VOL<<8 | $00
		rst RST_YM_WRITEA
		ld de,REG_SSG_CHB_VOL<<8 | $00
		rst RST_YM_WRITEA
		ld de,REG_SSG_CHC_VOL<<8 | $00
		rst RST_YM_WRITEA

		ld de,REG_SSG_MIX_ENABLE<<8 | $3F
		rst RST_YM_WRITEA
	pop de
	ret

; a: channel
; c: note
SSG_set_note:
    push de
    push hl
    push af
        ; Index LUT
        ld e,c
        ld d,0
        ld hl,SSG_note_LUT 
        add hl,de 
        add hl,de 
        
        ; Write to YM2610 registers
        sla a  ; a *= 2 (CH0 FINE TUNE: $00; CH1 ...: $02; CH2 ...: $04)
        ld d,a 
        ld e,(hl)
        rst RST_YM_WRITEA ; Fine tune
        inc d 
        inc hl 
        ld e,(hl)
        rst RST_YM_WRITEA ; Coarse tune
    pop af
    pop hl
    pop de
    ret

; a: channel
; c: volume (in 0~255 range)
SSG_set_volume:
    push de
    push af
        ld d,a ; load ch in d
        ld a,c ; load vol in a

        ; Adapt volume to SSG register range
        rrca 
        rrca 
        rrca 
        rrca 
        and a,$0F

        ; Write to YM2610 register 
        ld e,a
        ld a,REG_SSG_CHA_VOL
        add a,d 
        ld d,a
        rst RST_YM_WRITEA
    pop af 
    pop de
    ret

; a: channel
; c: mixing
SSG_set_mixing:
    push bc
    push de
    push af
        ; Depending on the channel used, shift 
        ; the mix flags and mask to the left
        ;   CHA: ----N--T
        ;   CHB: ---N--T-
        ;   CHC: --N--T--
        ld b,a
        call shift_left_c_by_b_bits
        ld e,c ; backup result in e
        ld b,a 
        ld c,%1001
        call shift_left_c_by_b_bits
        
        ; AND buffered mix flag with inverted mask
        ; (resets the flags for that channel),
        ; and then OR the new flags.
        ld d,a ; backup channel in d
        ld a,(SSG_mix_flags_buffer)
        ld b,a
        ld a,c
        xor a,$3F ; invert mask
        and a,b   ; AND inverted mask and buffered mix flags
        or a,e    ; OR new flags
        ld (SSG_mix_flags_buffer),a 

        xor a,$3F
        ld e,a ; load mix flags in e
        ld d,REG_SSG_MIX_ENABLE
        rst RST_YM_WRITEA
    pop af
    pop de
    pop bc
    ret

; a: channel
; Loads flags from the inst mix buffer,
; and writes to the actual buffer and YM2610
; accordingly
SSG_set_mixing_from_inst:
    push bc
    push de
    push af
        ; Depending on the channel used, shift 
        ; the mix mask to the left
        ;   CHA: ----N--T
        ;   CHB: ---N--T-
        ;   CHC: --N--T--
        ld b,a 
        ld c,%1001
        call shift_left_c_by_b_bits
        
        ; Load inst mix flags from WRAM and mask it
        ld d,a ; backup channel in d
        ld a,(SSG_inst_mix_flags)
        ld b,a
        ld a,c
        and a,b   ; AND mask and inst mix flags
        ld e,a    ; store result in e

        ; AND buffered mix flag with inverted mask
        ; (resets the flags for that channel),
        ; and then OR the new flags.
        ld a,(SSG_mix_flags_buffer)
        ld b,a
        ld a,c
        xor a,$3F ; invert mask
        and a,b   ; AND inverted mask and buffered mix flags
        or a,e    ; OR new flags
        ld (SSG_mix_flags_buffer),a 

        xor a,$3F
        ld e,a ; load mix flags in e
        ld d,REG_SSG_MIX_ENABLE
        rst RST_YM_WRITEA
    pop af
    pop de
    pop bc
    ret

; a: channel
; c: mixing
; Sets SSG inst mix flags in WRAM,
; doesn't write to any registers.
SSG_set_inst_mixing:
    push bc
    push de
    push af
        ; Depending on the channel used, shift 
        ; the mix flags and mask to the left
        ;   CHA: ----N--T
        ;   CHB: ---N--T-
        ;   CHC: --N--T--
        ld b,a
        call shift_left_c_by_b_bits
        ld e,c ; backup result in e
        ld b,a 
        ld c,%1001
        call shift_left_c_by_b_bits
        
        ; AND buffered mix flag with inverted mask
        ; (resets the flags for that channel),
        ; and then OR the new flags.
        ld d,a ; backup channel in d
        ld a,(SSG_inst_mix_flags)
        ld b,a
        ld a,c
        xor a,$3F ; invert mask
        and a,b   ; AND inverted mask and buffered mix flags
        or a,e    ; OR new flags
        ld (SSG_inst_mix_flags),a
    pop af
    pop de
    pop bc
    ret

SSG_note_LUT:
	incbin "ssg_pitch_lut.bin"

SSG_vol_LUT:
	incbin "ssg_vol_lut.bin"