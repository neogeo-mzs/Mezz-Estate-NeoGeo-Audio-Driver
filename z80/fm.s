fm_stop:
	push de
		ld de,(REG_FM_KEY_ON<<8) | FM_CH1
		rst RST_YM_WRITEA
		ld e,FM_CH2
		rst RST_YM_WRITEA
		ld e,FM_CH3
		rst RST_YM_WRITEA
		ld e,FM_CH4
		rst RST_YM_WRITEA
	pop de
	ret

; a: fbalgo (--FFFAAA; Feedback, Algorithm)
; c: channel (0~3)
FMCNT_set_fbalgo:
	push de
	push af
		call FMCNT_assert_channel
		ld e,a ; Store value in e

		; If the channel is even then
		; use register $B1, else use $B2
		ld d,REG_FM_CH13_FBALGO
		bit 0,c
		jr z,FMCNT_set_fbalgo_even_ch
		inc d

FMCNT_set_fbalgo_even_ch:
		; If the channel is 0 and 1,
		; use port A, else (channel
		; is 2 and 3) use port B
		bit 1,c
		call z,port_write_a
		call nz,port_write_b
	pop af
	pop de
	ret

; a: fbalgo (--AA-PPP; Ams, Pms)
; c: channel (0~3)
FMCNT_set_amspms:
	push de
	push af
	push hl
		call FMCNT_assert_channel

		; Load channel's Panning, 
		; AMS and PMS from WRAM
		ld hl,FM_channel_lramspms
		ld e,c
		ld d,0
		add hl,de

		; Clear channel's AMS and PMS,
		; And OR the desired AMS and PMS
		ld e,a
		ld a,(hl)
		and a,%11001000 ; LR??-??? -> LR00-000
		or a,e          ; LR00-000 -> LRAA-PPP
		ld (hl),a       ; Store register value in WRAM

		; If the channel is even then
		; use register $B1, else use $B2
		ld d,REG_FM_CH13_LRAMSPMS
		bit 0,c
		jr z,FMCNT_set_fbalgo_even_ch
		inc d

FMCNT_set_amspms_even_ch:
		; If the channel is 0 and 1,
		; use port A, else (channel
		; is 2 and 3) use port B
		bit 1,c
		call z,port_write_a
		call nz,port_write_b
	pop hl
	pop af
	pop de
	ret

; a: fbalgo (LR------; Left and Right)
; c: channel (0~3)
FMCNT_set_panning:
	push de
	push af
	push hl
		call FMCNT_assert_channel

		; Load channel's Panning, 
		; AMS and PMS from WRAM
		ld hl,FM_channel_lramspms
		ld e,c
		ld d,0
		add hl,de

		; Clear channel's AMS and PMS,
		; And OR the desired AMS and PMS
		ld e,a
		ld a,(hl)
		and a,%00111111 ; ??AA-PPP -> 00AA-PPP
		or a,e          ; 00AA-PPP -> LRAA-PPP
		ld (hl),a       ; Store register value in WRAM

		; If the channel is even then
		; use register $B1, else use $B2
		ld d,REG_FM_CH13_LRAMSPMS
		bit 0,c
		jr z,FMCNT_set_fbalgo_even_ch
		inc d

FMCNT_set_panning_even_ch:
		; If the channel is 0 and 1,
		; use port A, else (channel
		; is 2 and 3) use port B
		bit 1,c
		call z,port_write_a
		call nz,port_write_b
	pop hl
	pop af
	pop de
	ret

; hl: pointer to operator data
; c:  channel (0~3)
; b:  operator (0~3)
FMCNT_set_operators:
	push hl
	push de
	push af
		call FMCNT_assert_channel
		call FMCNT_assert_operator

		; Calculate the address to the
		; DTMUL register based on channel
		; and operator
		;	d = operator*4 + is_odd(channel)
		ld a,b
		sla a ; - a *= 4
		sla a ; /
		ld e,a
		ld a,c
		and a,1 ; ???????P -> 0000000P (Parity bit; 0 = Even, 1 = Odd)
		add a,e
		add a,REG_FM_CH1_OP1_DTMUL
		ld d,a

		; Set DT and MUL
		ld e,(hl)
		bit 1,c              ; \
		call z,port_write_a  ; | If the channel is 0 and 1 use port a else use port b
		call nz,port_write_b ; /
		inc hl               ; increment pointer to source
		ld a,&10             ; \
		add a,d              ; | Increment register address
		ld d,a               ; /

		; Store TL in WRAM
		push hl
		push de
			; Calculate address to FM_operator_TLs[channel][0]
			ld a,c
			sla a ; - a *= 4
			sla a ; /
			ld e,a
			ld d,0
			ld a,(hl) ; Store TL in a
			ld hl,FM_operator_TLs
			add hl,de 

			; Calculate address to 
			; FM_operator_TLs[channel][operator],
			; then store TL in said address
			ld e,b
			ld d,0
			add hl,de
			ld (hl),a
		pop de
		pop hl
		inc hl   ; increment pointer to source
		ld a,&10 ; \
		add a,d  ; | Increment register address
		ld d,a   ; /

		; Set the operator registers
		ld b,5 ; operator registers left count
FMCNT_set_operators_loop:
		ld e,(hl)
		bit 1,c              ; \
		call z,port_write_a  ; | If the channel is 0 and 1 use port a else use port b
		call nz,port_write_b ; /

		; Increment pointer to source and register address
		inc hl
		ld a,&10
		add a,d
		ld d,a

		djnz FMCNT_set_operators_loop
	pop af
	pop de
	pop hl
	ret

; a: operator enable (4321----; op 4 enable; op 3 enable; op 2 enable; op 1 enable)
; c: channel (0~3)
FMCNT_set_op_enable:
	push hl
	push bc
	push af
		call FMCNT_assert_channel

		; Store OP enable in WRAM
		ld hl,FM_channel_op_enable
		ld b,0
		add hl,bc
		ld (hl),a
	pop af
	pop bc
	pop hl
	ret

; ixh: note (-OOONNNN; Octave, Note)
; ixl: channel
FMCNT_set_note:
	push hl
	push de
	push af
		ld c,ixl
		call FMCNT_assert_channel

		; Load base pitch from FMCNT_pitch_LUT in bc
		ld a,ixh
		and a,&0F ; -OOONNNN -> 0000NNNN; Get note
		ld e,a
		ld d,0
		ld hl,FMCNT_pitch_LUT
		ld c,(hl)
		inc hl
		ld b,(hl)

		; Set block/octave
		ld a,ixh
		and a,%01110000 ; Get octave (-OOONNNN -> 0OOO0000)
		srl a           ; Get octave in the right position (block needs to be set to octave)
		or a,b          ; OR block with F-Num 2
		ld b,a

		; Store bc in WRAM
		ld h,0
		ld e,ixl
		ld l,e
		ld de,FM_channel_frequencies
		add hl,de
		ld (hl),c
		inc hl
		ld (hl),b
	pop af
	pop de
	pop hl
	ret

; to set the octave you just need to set "block".
; octave 0 = block 1, etc...
; If the note number exceeds the valid maximum, play a B
FMCNT_pitch_LUT:
	;  C    C#   D    D#   E    F    F#   G
	dw 309, 327, 346, 367, 389, 412, 436, 462
	;  G#   A    A#   B
 	dw 490, 519, 550, 583, 583, 583, 583, 583

; a: volume (0 is lowest, 127 is highest)
; c: channel
FMCNT_set_volume:
	push hl
	push bc
	push af
		call FMCNT_assert_channel

		ld b,0
		ld hl,FM_channel_volumes
		add hl,bc
		and a,127 ; Wrap volume inbetween 0 and 127
		ld (hl),a
	pop af
	pop bc
	pop hl
	ret

; c: channel
;	if the channel is invalid (> 3),
;   softlock the program 
FMCNT_assert_channel:
	push af
		ld a,c
		cp a,4 
		jp nc,softlock ; if a >= 4 then softlock
	pop af
	ret

; b: channel
;	if the operator is invalid (> 3),
;   softlock the program 
FMCNT_assert_operator:
	push af
		ld a,b
		cp a,4 
		jp nc,softlock ; if a >= 4 then softlock
	pop af
	ret