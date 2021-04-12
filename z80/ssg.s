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

SSG_irq:
	ld b,3
	
SSG_update_loop:
	ld a,b
	dec a

	call SSG_update_volume

	ld de,ssg_vol_macro_sizes
	call SSG_counter_increment ; Update volume counter

;   Arpeggio macros were implemented, but they sound
;   terrible, so I removed them, use at your own risk.       
;		call SSG_update_pitch
;		ld de,ssg_arp_macro_sizes
;		call SSG_counter_increment ; Update arpeggio counter

	djnz SSG_update_loop
	ret
	
; a:  SSG channel
; bc: pitch (----CCCCFFFFFFFF; Coarse tune, Fine tune)
SSG_set_pitch:
	; Set YM SSG registers
	push af
	push bc
	push de
		sla a ; reg_addr = channel * 2

		; Set fine tune
		ld d,a
		ld e,c
		rst RST_YM_WRITEA

		; Set coarse tune
		inc d
		ld e,b ; source
		rst RST_YM_WRITEA
	pop de
	pop bc
	pop af
	ret

; a: SSG channel
; c: volume (---MVVVV; Mode, Volume)
SSG_set_volume:
	; Sets the volume of the SSG channel
	push af
	push de
	push hl
		; Load attenuator into b
		ld h,0
		ld l,a
		ld de,ssg_vol_attenuators
		add hl,de
		ld b,(hl)

		; Lookup volume from SSG_vol_lut and
		; store it into e
		push af
			; multiply attenuator by 8
			ld a,b
			sla a
			sla a
			sla a

			; Calculate pointer to
			; SSG_vol_lut[attenuator*8]
			ld hl,SSG_vol_lut
			ld d,0
			ld e,a
			add hl,de

			; store SSG_vol_lut[attenuator*8][vol/2]
			; into a
			ld a,c
			srl a
			ld d,0
			ld e,a
			add hl,de
			ld a,(hl)

			; If volume (c) is even, get most significant
			; nibble, if it's odd, get less significant
			; nibble
			bit 0,c
			jp nz,SSG_set_volume_is_odd

			srl a ; -VVVV---
			srl a ; --VVVV--
			srl a ; ---VVVV-
			srl a ; ----VVVV

SSG_set_volume_is_odd:
			and a,&0F

			ld e,a
		pop af

		add a,REG_SSG_CHA_VOL
		ld d,a
		rst RST_YM_WRITEA
	pop hl
	pop de
	pop af
	ret

; a: SSG channel
; c: instrument
SSG_set_instrument:
	push bc
	push hl
	push de
		; == Load volume macro == 
		; Calculate pointer to instrument
		ld h,0 
		ld l,c

		add hl,hl
		add hl,hl
		add hl,hl
		add hl,hl
		add hl,hl ; hl *= 32

		ld de,INSTRUMENTS
		add hl,de

		; ======== Set volume macro ========
		ld e,(hl) ; vol macro size

		inc hl
		ld d,(hl) ; vol loop point

		inc hl
		ld c,(hl) ; vol pointer to macro (lsb)
		inc hl 
		ld b,(hl) ; vol pointer to macro (msb)

		push hl
			ld hl,ssg_vol_macros
			call SSG_set_macro
		pop hl

		; ======== Set other parameters ========
		inc hl
		ld c,(hl)
		call SSG_set_mix_enable
	pop de
	pop hl
	pop bc
	ret

; a:  SSG channel
; bc: pointer to macro
; hl: pointer to counter (macros)
; e:  macro size
; d:  loop position
SSG_set_macro:
	push hl
	push af
		; Calculate pointer to macros[ch]
		push af
		push hl
		push de
			sla a ; ofs = channel*2
			ld d,0
			ld e,a
			add hl,de

			; macros[ch] = pointer_to_macro
			ld (hl),c
			inc hl
			ld (hl),b
		pop de
		pop hl
		pop af

		; Calculate pointer to macro_sizes[ch]
		push de
			ld de,ssg_vol_macro_sizes-ssg_vol_macros
			add hl,de

			ld d,0
			ld e,a
			add hl,de
		pop de

		; macro_sizes[ch] = macro_size
		ld (hl),e 

		push de
			ld de,ssg_vol_macro_counters-ssg_vol_macro_sizes
			add hl,de
		pop de

		; Clear counter
		xor a,a   ; clear af
		ld (hl),a

		; Calculate pointer to macro_loop_pos[ch]
		push de
			ld de,ssg_vol_macro_loop_pos-ssg_vol_macro_counters
			add hl,de
		pop de

		; macro_loop_pos[ch] = macro_loop_pos
		ld (hl),d 

		ld a,d
		cp a,&FF ; if macro_loop_pos != &FF (If loop)
		jp nz,SSG_set_macro_if_loop ; then branch...

		; else macro_loop_pos[ch] = macro_size-1
		dec e
		ld (hl),e

SSG_set_macro_if_loop:
	pop af
	pop hl
	ret

; a: channel
; c: note
SSG_set_note:
	push hl
	push bc
	push af
	push de
		; Set Coarse and Fine tune
		ld e,c ; backup channel in e
		ld h,0
		ld l,c 
		ld bc,SSG_pitch_LUT
		add hl,hl
		add hl,bc

		ld c,(hl) ; fine tune
		inc hl
		ld b,(hl) ; coarse tune
		call SSG_set_pitch

		; Set noise tune
		ld d,REG_SSG_CHN_NOISE_TUNE
		rst RST_YM_WRITEA
	pop de
	pop af
	pop bc
	pop hl
	ret

; a: SSG channel
; de: pointer to counter (macro_sizes)
SSG_counter_increment:
	push af
	push bc
	push hl
	push de
		; c = macro_sizes[channel]
		ld h,0
		ld l,a
		add hl,de
		ld c,(hl)

		; macro_sizes + 3 = macro_counters
		ld hl,3
		add hl,de
		ex de,hl  

		ld b,a ; backup channel into b

		; a = ++macro_counters[channel]
		ld h,0
		ld l,a
		add hl,de
		ld a,(hl)
		inc a
		ld (hl),a

		cp a,c                         ; If macro_counter < macro_size                         
		jp c,SSG_counter_increment_end ;     then branch...

		push hl
			; macro_counters + 3 = macro_loop_pos
			ld hl,3
			add hl,de
			ex de,hl

			; a = macro_loop_pos[channel]
			ld h,0
			ld l,b
			add hl,de
			ld a,(hl)
		pop hl

		; macro_counters[ch] = macro_loop_pos[ch]
		ld (hl),a

SSG_counter_increment_end:
	pop de
	pop hl
	pop bc
	pop af
	ret

; a: SSG channel
SSG_update_volume:
	push hl
	push af
	push bc
	push de
	push ix
		; Calculate pointer to ssg_vol_macro_counters[ch]
		ld h,0
		ld l,a
		ld de,ssg_vol_macro_counters
		add hl,de
		ld c,(hl) ; c = ssg_vol_macro_counters[ch]

		ld ixl,a ; backup channel

		; Calculate pointer to ssg_vol_macros[ch]
		sla a ; ofs = channel*2
		ld h,0
		ld l,a
		ld de,ssg_vol_macros
		add hl,de

		; Load pointer to macro into de
		ld e,(hl)
		inc hl
		ld d,(hl)

		ld a,0
		add a,e
		add a,d
		jp c,SSG_do_update_volume  ; if macro_ptr == NULL then
		jp z,SSG_update_volume_end ;   branch...
		 
		                           ; else update OPNB registers
SSG_do_update_volume:		
		; Calculate pointer to the needed
		; macro value, and dereference it
		ld a,c
		srl a  ; ofs = counter / 2
		ld h,0
		ld l,a
		add hl,de ; ptr = macro + ofs
		ld a,(hl)

		; If the counter is odd, load the right nibble
		; (----NNNN), if it's not load the left nibble
		; (NNNN----)
		bit 0,c                             ; if is_odd(counter) then
		jp nz,SSG_update_volume_cntr_is_odd ;   branch
											; else...
		      ; NNNN----
		srl a ; -NNNN---
		srl a ; --NNNN--
		srl a ; ---NNNN-
		srl a ; ----NNNN

SSG_update_volume_cntr_is_odd:
		and a,&0F ; Get right nibble
		ld c,a

		ld a,ixl ; channel
		call SSG_set_volume 

SSG_update_volume_end:
	pop ix
	pop de
	pop bc
	pop af
	pop hl
	ret

; a: channel
; c: attenuator value
SSG_set_attenuator:
	push hl
	push de
		ld h,0
		ld l,a
		ld de,ssg_vol_attenuators
		add hl,de
		ld (hl),c
	pop de
	pop hl
	ret

; a: channel
SSG_stop_note:
	push bc
	push hl
	push af
		ld h,0
		ld l,a
		ld bc,ssg_vol_macros
		add hl,hl
		add hl,bc
		ld (hl),0
		inc hl
		ld (hl),0

		ld c,0
		call SSG_set_volume
	pop af
	pop hl
	pop bc
	ret

; a: channel
; c: mix (0: none, 1: tone, 2: noise, 3: tone and noise)
SSG_set_mix_enable:
	push af
	push bc
	push de
	push hl
		ld d,a ; backup channel in d
		ld e,c ; backup mix enum in e
		
		ld a,(ssg_mix_enable_flags)

		; clear_flag = 
		;    (SSG_mix_enable_clear_LUT[ch] <<l ch)
		; mix_en_flags &= clear_flag
		ld h,0
		ld l,e
		ld bc,SSG_mix_enable_clear_LUT
		add hl,bc
		ld c,(hl)
		ld b,d
		call shift_left_c_by_b_bits_1
		and a,c

		; set_flag =
		;    (SSG_mix_enable_set_LUT[ch] << ch)
		; mix_en_flags |= set_flag
		ld h,0
		ld l,e
		ld bc,SSG_mix_enable_set_LUT
		add hl,bc
		ld c,(hl)
		ld b,d
		call shift_left_c_by_b_bits
		or a,c

		ld (ssg_mix_enable_flags),a

		ld e,a
		ld d,REG_SSG_MIX_ENABLE
		rst RST_YM_WRITEA
	pop hl
	pop de
	pop bc
	pop af
	ret

SSG_mix_enable_clear_LUT:
	db %11111111, %11111110, %11110111, %11110110

SSG_mix_enable_set_LUT:
	db %00001001, %00001000, %00000001, %00000000

SSG_vol_lut:
	incbin "ssg_vol_lut.bin"

; LUT containing the pitch of each note from C2 to B7
SSG_pitch_LUT:
	incbin "ssg_pitch_lut.bin"