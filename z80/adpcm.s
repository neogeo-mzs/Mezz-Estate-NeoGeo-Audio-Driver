;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                 ADPCM-A                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PA_stop:
	push de
		ld de,(REG_PA_CTRL<<8) | &BF
		rst RST_YM_WRITEB
	pop de
	ret

PA_reset:
	push de
	push bc
	push af
		call PA_stop

		; Set volumes to &1F and panning
		; to center for every channel
		ld b,6
		ld d,REG_PA_CVOL
		ld e,PANNING_CENTER | &1F
PA_reset_loop:
		rst RST_YM_WRITEB
		inc d
		djnz PA_reset_loop

		; Set master volume to &3F
		ld de,(REG_PA_MVOL<<8) | &3F
		rst RST_YM_WRITEB
	pop af
	pop bc
	pop de
	ret
; a:  channel (0: ADPCM-A 1, ..., 5: ADPCM-A 6)
; ix: source (smp start LSB; smp start MSB; smp end LSB; smp start MSB)
PA_set_sample_addr:
	push af
	push de
		ld d,REG_PA_STARTL
		add a,d
		ld d,a
		ld e,(ix+0)
		rst RST_YM_WRITEB

		add a,REG_PA_STARTH-REG_PA_STARTL
		ld d,a
		ld e,(ix+1)
		rst RST_YM_WRITEB

		add a,REG_PA_ENDL-REG_PA_STARTH
		ld d,a
		ld e,(ix+2)
		rst RST_YM_WRITEB

		add a,REG_PA_ENDH-REG_PA_ENDL
		ld d,a
		ld e,(ix+3)
		rst RST_YM_WRITEB
	pop de
	pop af
	ret

; c: channel
PA_stop_sample:
	push hl
	push bc
	push af
	push de
		ld hl,PA_channel_on_masks
		ld b,0
		add hl,bc
		ld e,(hl)

		set 7,e   ; Set dump bit
		ld d,REG_PA_CTRL
		rst RST_YM_WRITEB
	pop de		
	pop af
	pop bc
	pop hl
	ret

; a: channel
; c: volume
PA_set_channel_volume:
	push de
	push hl
		; Store volume in 
		; PA_channel_volumes[channel]
		ld h,0
		ld l,a
		ld de,PA_channel_volumes
		add hl,de
		ld (hl),c

		; Load panning from 
		; PA_channel_pannings[channel]
		; and OR it with the volume
		push af
			ld h,0
			ld l,a
			ld de,PA_channel_pannings
			add hl,de
			ld e,(hl)
			ld a,c
			or a,e ; ORs the volume and panning
			ld e,a
		pop af

		; Set CVOL register
		push af
			add a,REG_PA_CVOL
			ld d,a
		pop af
		rst RST_YM_WRITEB
	pop hl
	pop de
	ret

; a: channel
; c: panning (0: none, 64: right, 128: left, 192: both)
PA_set_channel_panning:
	push hl
	push de
	push bc
		; Store panning in 
		; PA_channel_pannings[channel]
		ld h,0
		ld l,a
		ld de,PA_channel_pannings
		add hl,de
		ld (hl),c

		; Load volume from
		; MLM_channel_volumes[channel]
		; and OR it with the panning
		push af
			ld h,0
			ld l,a
			ld de,PA_channel_volumes
			add hl,de
			ld a,(hl)
			or a,c
			ld e,a
		pop af

		; Set CVOL register
		push af
			add a,REG_PA_CVOL
			ld d,a
		pop af
		rst RST_YM_WRITEB
	pop bc
	pop de
	pop hl
	ret

PA_channel_on_masks:
	db %00000001,%00000010,%00000100,%00001000,%00010000,%00100000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                 ADPCM-B                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

pb_stop:
	push de
		ld de,(REG_PB_CTRL<<8) | &01
		rst RST_YM_WRITEB

		dec e
		rst RST_YM_WRITEB
	pop de
	ret