;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                 ADPCM-A                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

pa_stop:
	push de
		ld de,(REG_PA_CTRL<<8) | &9F
		rst RST_YM_WRITEB
	pop de
	ret

; a:  channel
; de: sample id (-------SSSSSSSSS; Sample)
PA_set_sample_addr:
	push hl
	push de
	push af
	push bc
		ex de,hl

		add hl,hl   ; sample_addr_ofs = sample_id*4
		add hl,hl
		ld de,ADPCMA_SMPS
		add hl,de   ; sample_addr_ptr = sample_addr_ofs + pa_sample_LUT

		add a,REG_PA_STARTL

		ld d,a     ; Register address
		ld e,(hl)  ; Source
		rst RST_YM_WRITEB ; Write start addr LSB

		add a,REG_PA_STARTH-REG_PA_STARTL
		inc hl
		ld d,a     ; Register address
		ld e,(hl)  ; Source
		rst RST_YM_WRITEB ; Write start addr MSB

		add a,REG_PA_ENDL-REG_PA_STARTH

		inc hl
		ld d,a    ; Register address
		ld e,(hl) ; Source
		rst RST_YM_WRITEB ; Write end addr LSB

		add a,REG_PA_ENDH-REG_PA_ENDL
		inc hl
		ld d,a    ; Register address
		ld e,(hl) ; Source
		rst RST_YM_WRITEB ; Write end addr MSB
	pop bc
	pop af
	pop de
	pop hl
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
		; Load panning from 
		; MLM_channel_pannings[channel]
		; and OR it with the volume
		push af
			ld h,0
			ld l,a
			ld de,MLM_channel_pannings
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
		; Load volume from
		; MLM_channel_volumes[channel]
		; and OR it with the panning
		push af
			ld h,0
			ld l,a
			ld de,MLM_channel_volumes
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