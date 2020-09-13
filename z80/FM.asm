; b: channel
; c: instrument
; resets the volume of all operators.
FM_load_instrument:
	push hl
	push de
	push af
	push bc
		;;;;;; Calculate pointer to instrument ;;;;;;
		ld h,0 
		ld l,c

		add hl,hl
		add hl,hl
		add hl,hl
		add hl,hl
		add hl,hl ; hl *= 32

		ld de,INSTRUMENTS
		add hl,de

		;;;;;; Set channel registers ;;;;;;
		ld d,REG_FM_CH13_FBALGO
		ld e,(hl)

		; if channel is even (is CH2 or CH4), then
		; increment REG_FM_CH13_FBALGO, this results
		; in REG_FM_CH24_FBALGO
		bit 0,b
		jp nz,FM_load_instrument_chnl_is_odd
		inc d

FM_load_instrument_chnl_is_odd:
		; if the channel is CH1 or CH2, then write to 
		; port A, else write to port B
		bit 2,b
		call z,write45
		call nz,write67

		inc hl
		ld a,(hl)

		push hl
		push de
			dec b

			ld d,0
			ld e,b
			ld hl,FM_pannings
			add hl,de
			or a,(hl)
			
			inc b
		pop de
		pop hl

		ld e,a

		inc d
		inc d
		inc d
		inc d

		bit 2,b
		call z,write45
		call nz,write67

		;;;;;; Set operator registers ;;;;;;
		inc hl
		
		ld a,b

		ld c,FM_OP1
		call FM_set_operator
		inc c
		call FM_set_operator
		inc c
		call FM_set_operator
		inc c
		call FM_set_operator
	pop bc
	pop af
	pop de
	pop hl
	ret

; [INPUT]
;   a: channel
;   c: operator
;   hl: source
; [OUTPUT]
;   hl: source+7
;   
;   resets the operator's volume
FM_set_operator:
	push de
	push bc
	push ix
		; Calculate FM_base_total_levels offset
		;
		;  base_total_level = 
		;    FM_base_total_levels + ch*4 + op
		push hl
		push af
			; load hl (source) in ix
			ex de,hl
			ld ixh,d
			ld ixl,e

			dec a
			sla a
			sla a
			ld d,0
			ld e,a
			ld hl,FM_base_total_levels
			add hl,de
			ld d,0
			ld e,c
			add hl,de

			ld a,(ix+1)
			ld (hl),a
		pop af
		pop hl

		; Lookup base register address
		push hl
			ld h,0
			ld l,c
			ld de,FM_op_base_address_LUT
			add hl,de
			ld d,(hl)

			; if channel is even (is CH2 or CH4), then
			; increment base register address.
			bit 0,a
			jp nz,FM_set_operator_chnl_is_odd
			inc d

FM_set_operator_chnl_is_odd:
		pop hl

		ld b,7

FM_set_operator_loop:
		ld e,(hl)

		bit 2,a
		call z,write45
		call nz,write67

		push af
			ld a,d
			add a,&10
			ld d,a
		pop af

		inc hl

		djnz FM_set_operator_loop
		; dec b
		; jr z,FM_set_operator_loop
	pop ix
	pop bc
	pop de
	ret

; b: channel
; c: -OOONNNN (Octave; Note)
FM_set_note:
	push hl
	push de
	push af
		; Lookup F-Number from FM_pitch_LUT
		; and store it into a
		ld a,c
		and a,&0F
		sla a
		ld h,0
		ld l,a
		ld de,FM_pitch_LUT+1 ; Get most significant byte first
		add hl,de
		ld e,(hl)

		; Set block and MSBs of F-Num
		ld a,c
		srl a   ; -OOO---- -> --OOO---
		or a,e
		ld e,a

		; Calculate channel register address
		;   if channel is even (is CH2 or CH4), then
		;   increment REG_FM_CH13_FBLOCK, this results
		;   in REG_FM_CH24_FBLOCK
		ld d,REG_FM_CH13_FBLOCK
		bit 0,b
		jp nz,FM_set_note_chnl_is_odd
		inc d

FM_set_note_chnl_is_odd:
		; if the channel is CH1 or CH2, then write to 
		; port A, else write to port B
		bit 2,b
		call z,write45
		call nz,write67

		dec d
		dec d
		dec d
		dec d

		dec hl
		ld e,(hl)

		bit 2,b
		call z,write45
		call nz,write67
	pop af
	pop de
	pop hl
	ret

; a: channel
; c: attenuator
FM_set_attenuator:
	push bc
	push hl
	push de
	push ix
		; Index FM_base_total_levels[ch][3]
		push af
			dec a
			sla a
			sla a
			ld d,0
			ld e,a
			ld hl,FM_base_total_levels+3
			add hl,de
		pop af

		ld b,4

FM_set_attenuator_loop:
		; ixl = TL * (127 - AT) / 127 + AT
		push hl
		push af
			ld a,127
			sub a,c

			push bc
				ld e,(hl)
				ld h,a
				call H_Times_E

				ld c,127
				call RoundHL_Div_C
			pop bc

			ld a,c
			add a,l
			
			ld ixl,a
		pop af
		pop hl

		; Lookup operator base address from
		; FM_op_base_address_LUT, then use it
		; to calculate the correct operator
		; register address and store it into d
		push bc
		push hl
		push af
			ld hl,FM_op_base_address_LUT
			ld d,0
			ld e,b
			add hl,de

			ld d,(hl)

			bit 0,a
			jr nz,FM_set_attenuator_loop_op_is_odd
			inc d

FM_set_attenuator_loop_op_is_odd:
			ld a,d
			add a,&10
			ld d,a
		pop af
		pop hl
		pop bc

		ld e,ixl
		bit 2,a
		call z,write45
		call nz,write67

		dec hl

		djnz FM_set_attenuator_loop
	pop ix
	pop de
	pop hl
	pop bc
	ret

; a: channel
; c: panning (0: none, 64: right, 128: left, 192: both)
FM_set_panning:
	push hl
	push de
	push af
		dec a
		ld d,0
		ld e,a
		ld hl,FM_pannings
		add hl,de

		ld (hl),c
	pop af
	pop de
	pop hl
	ret

; a: channel
FM_stop_channel:
	push af
	push de
		ld d,REG_FM_KEY_ON
		and a,%00000111
		ld e,a
		rst RST_YM_WRITEA
	pop de
	pop af
	ret

FM_op_base_address_LUT:
	db &31,&39,&35,&3D

; to set the octave you just need to set "block".
; octave 0 = block 0, etc...
FM_pitch_LUT:
	;  C     C#    D     D#    E     F     F#    G
	dw &026A,&028E,&02B5,&02DE,&030A,&0338,&0368,&039D
	;  G#    A     A#    B
	dw &03D4,&040E,&044C,&048D

FM_channel_LUT:
	db FM_CH1, FM_CH2, FM_CH3, FM_CH4