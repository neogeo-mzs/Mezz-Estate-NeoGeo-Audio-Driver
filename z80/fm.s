fm_stop:
	push de
		ld de,REG_FM_KEY_ON<<8 | FM_CH1
		rst RST_YM_WRITEA
		ld e,FM_CH2
		rst RST_YM_WRITEA
		ld e,FM_CH3
		rst RST_YM_WRITEA
		ld e,FM_CH4
		rst RST_YM_WRITEA
	pop de
	ret

FMCNT_init:
	push hl
	push de
	push bc
	push af
		call fm_stop

		; clear FM WRAM
		ld hl,FM_wram_start
		ld de,FM_wram_start+1
		ld bc,FM_wram_end-FM_wram_start-1
		ld (hl),0
		ldir

		; set all operator TLs to $7F
		ld hl,FM_operator_TLs
		ld de,FM_operator_TLs+1
		ld bc,FM_CHANNEL_COUNT*FM_OP_COUNT - 1
		ld (hl),$7F
		ldir
		
		ld b,4

FMCNT_init_loop:
		ld c,b
		dec c
		ld a,$7F ; default volume
		call FMCNT_set_volume

		ld a,PANNING_CENTER
		call FMCNT_set_panning
		djnz FMCNT_init_loop
	pop af
	pop bc
	pop de
	pop hl
	ret

; DOESN'T BACKUP REGISTERS !!!
FMCNT_irq:
	ld b,FM_CHANNEL_COUNT
	ld hl,FM_channel_enable+FM_CHANNEL_COUNT-1
	
FMCNT_irq_loop:
	dec b
		; If FM_channel_enable[channel] is 0,
		; then continue to the next channel
		ld a,(hl)
		bit 0,a
		jr z,FMCNT_irq_loop_skip

		bit 2,a                            ; +2 = 4b  | Check for update Frequency flag
		;call nz, FMCNT_update_frequencies ; If it's set call...
		call FMCNT_update_frequencies      ; +3 = 7b  | For now update frequency here regardless
		bit 1,a                            ; +2 = 9b  | Check for update Volume flag
		call nz, FMCNT_update_total_levels ; +3 = 12b | If it's set call...
		;call FMCNT_update_key_on           ; +3 = 15b

FMCNT_irq_loop_skip:
		ld a,(hl)
		and a,1   ; Only keep the enable channel flag
		ld (hl),a ; and store the bitflags back in WRAM
		dec hl
	inc b
	djnz FMCNT_irq_loop
	ret

; b: channel (0~3)
; doesn't backup DE and Flags
FMCNT_update_frequencies:
	push hl
	push bc
		; Calculate address to
		; FM_channel_frequencies[channel]+1
		ld l,b
		ld h,0
		ld de,FM_channel_frequencies+1
		add hl,hl
		add hl,de

		; Set Block and F-Num 2
		ld e,(hl)
		ld d,REG_FM_CH13_FBLOCK
		bit 0,b
		jr z,FMCNT_update_frequencies_even_ch
		inc d
FMCNT_update_frequencies_even_ch:
		; If the channel is 0 and 1,
		; use port A, else (channel
		; is 2 and 3) use port B
		bit 1,b
		call z,port_write_a
		call nz,port_write_b

		; Set F-Num 1
		dec hl
		ld e,(hl)
		dec d ; -\
		dec d ;  | d -= 4
		dec d ;  /
		dec d ; /
		bit 1,b
		call z,port_write_a
		call nz,port_write_b
	pop bc
	pop hl
	ret


; b: channel (0~3)
; (FM_channel_volumes[channel]): volume (0~7F)
; DOESN'T BACKUP DE
FMCNT_update_total_levels:
	push bc
	push hl
		; Load channel algorithm in e
		ld hl,FM_channel_algos
		ld e,b
		ld d,0
		add hl,de
		ld e,(hl)

		ld c,1 ; Prepare operator value

		; Since algorithms below ALGO4 are treated
		; the same, they can quickly be dealt with,
		; without indexing the vector table
		bit 3,e ; It'd normally check bit 2, but the algorithm is multiplied by two
		jp z,FMCNT_update_total_levels_algo_0_1_2_3

		; for all the other algorithms, you have
		; to index the vector table.
		ld hl,FMCNT_tlupdate_vectors-4
		add hl,de
		;add hl,de ; Since the algorithm is stored multiplied by two, there's no need to add twice
		jp (hl)
FMCNT_update_total_levels_ret:
	pop hl
	pop bc
	ret

FMCNT_update_total_levels_algo_0_1_2_3:
		call FMCNT_update_modulator_tl ; OP1
		inc c
		call FMCNT_update_modulator_tl ; OP2
		inc c
		call FMCNT_update_modulator_tl ; OP3
		inc c
		call FMCNT_update_carrier_tl   ; OP4
	pop hl
	pop bc
	ret

; b: channel (0~3)
;   Indexed by FM channel algorithm
FMCNT_tlupdate_vectors:
	dw FMCNT_tlupdate_algo4,       FMCNT_tlupdate_algo5_6
	dw FMCNT_tlupdate_algo5_6,     FMCNT_tlupdate_algo7

FMCNT_tlupdate_algo4:
	call FMCNT_update_modulator_tl ; OP1
	inc c
	call FMCNT_update_carrier_tl   ; OP2
	inc c
	call FMCNT_update_modulator_tl ; OP3
	inc c
	call FMCNT_update_carrier_tl   ; OP4
	jp FMCNT_update_total_levels_ret

FMCNT_tlupdate_algo5_6:
	call FMCNT_update_modulator_tl ; OP1
	inc c
	call FMCNT_update_carrier_tl   ; OP2
	inc c
	call FMCNT_update_carrier_tl   ; OP3
	inc c
	call FMCNT_update_carrier_tl   ; OP4
	jp FMCNT_update_total_levels_ret

FMCNT_tlupdate_algo7:
	call FMCNT_update_carrier_tl   ; OP1
	inc c
	call FMCNT_update_carrier_tl   ; OP2
	inc c
	call FMCNT_update_carrier_tl   ; OP3
	inc c
	call FMCNT_update_carrier_tl   ; OP4
	jp FMCNT_update_total_levels_ret

; c: operator (1~4)
; b: channel (0~3)
; DOESN'T BACKUP DE
;	This calculates the Total Level
;   relative to the channel volume,
;   and then sets the register based
;   on the result of said calculation.
FMCNT_update_carrier_tl:
	push hl
	push af
		; Load current op's TL from WRAM
		; into a, then invert its least
		; significant 7 bits
		ld h,0
		ld l,b
		ld de,FM_operator_TLs-1 ; Operator indexing starts from 1 instead than 0
		add hl,hl               ; - hl *= 4
		add hl,hl               ; /
		add hl,de               ; calculate address to FM_operator_TLs[channel]-1
		ld e,c
		ld d,0
		add hl,de               ; calculate address to FM_operator_TLs[channel][operator]
		ld a,(hl)
		xor a,$7F               ; lowest 127 highest 0 -> lowest 0 highest 127

		; Load volume from WRAM into e
		ld l,b
		ld h,0
		ld de,FM_channel_volumes
		add hl,de
		ld e,(hl)

		; Multiply the op TL by the volume,
		; store it into hl, then divide it by 127.
		; The result will be stored in hl, but h
		; should be always equal to zero. 
		push bc
			ld h,a
			call H_Times_E
			ld c,127
			call RoundHL_Div_C
		pop bc

		; Invert the result's least 
		; significant 7 bits
		ld a,l
		xor a,$7F

		; Load OP register offset in d
		ld h,0
		ld l,c
		ld de,FM_op_register_offsets_LUT-1
		add hl,de
		ld d,(hl)

		; If channel is odd (1 and 3) 
		; add 1 to register offset.
		; Finally, proceed to add
		; TL register address ($41)
		ld e,a ; Move TL in E
		ld a,b
		and a,1
		add a,d
		add a,REG_FM_CH1_OP1_TVOL
		ld d,a

		; If the channel is 0 and 1 write 
		; to port a, else write to port b
		bit 1,b              
		call z,port_write_a  
		call nz,port_write_b
	pop af
	pop hl
	ret

; c: operator (1~4)
; b: channel (0~3)
; DOESN'T BACKUP DE
;	This just sets the operator's
;   Total Level without modifying it.
FMCNT_update_modulator_tl:
	push hl
	push af
		; Load current op's TL from WRAM into a
		ld h,0
		ld l,b
		ld de,FM_operator_TLs-1 ; Operator indexing starts from 1 instead than 0
		add hl,hl               ; - hl *= 4
		add hl,hl               ; /
		add hl,de               ; calculate address to FM_operator_TLs[channel]-1
		ld e,c
		ld d,0
		add hl,de               ; calculate address to FM_operator_TLs[channel][operator]
		ld a,(hl)

		; Load OP register offset in d
		ld h,0
		ld l,c
		ld de,FM_op_register_offsets_LUT-1
		add hl,de
		ld d,(hl)

		; If channel is odd (1 and 3) 
		; add 1 to register offset.
		; Finally, proceed to add
		; TL register address ($41)
		ld e,a ; Move TL in E
		ld a,b
		and a,1
		add a,d
		add a,REG_FM_CH1_OP1_TVOL
		ld d,a

		; If the channel is 0 and 1 write 
		; to port a, else write to port b
		bit 1,b              
		call z,port_write_a  
		call nz,port_write_b
	pop af
	pop hl
	ret

FM_op_register_offsets_LUT:
	db $00,$08,$04,$0C

; b: channel (0~3)
; DOESN'T BACKUP AF and DE
FMCNT_update_key_on: ; When this is called for FM CH2 (b = 1), instead than working the intended 4 times it only does 2 times, why?
	push hl
		; Load channel's key on enable from WRAM
		ld hl,FM_channel_key_on
		ld e,b
		ld d,0
		add hl,de
		ld e,(hl)

		; If the value is 0, then don't
		; write to the key on register
		ld a,e
		or a,a ; cp a,0
		jr z,FMCNT_update_key_on_ret

		; Else, set channel key on enable to 0 and...
		xor a,a ; ld a,0
		ld (hl),a

		; write to the YM2610 key on register...
		;   Load OP enable from WRAM in a
		ld hl,FM_channel_op_enable
		ld e,b
		add hl,de
		ld a,(hl)
		and a,$F0 ; Clear the lower nibble just in case

		;   Calculate address to correct FM channel id
		ld hl,FM_channel_LUT
		add hl,de

		;   Proceed to stop the FM channel
		ld e,(hl)
		ld d,REG_FM_KEY_ON
		rst RST_YM_WRITEA
		
		;   OR the FM channel id and the OP enable 
		;   nibble, then store the result in e and
		;   write it to the FM Key On YM2610 register
		or a,(hl)
		ld e,a
		ld d,REG_FM_KEY_ON
		rst RST_YM_WRITEA

FMCNT_update_key_on_ret:
	pop hl
	ret

; a: fbalgo (--FFFAAA; Feedback, Algorithm)
; c: channel (0~3)
FMCNT_set_fbalgo:
	push de
	push af
	push hl
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

		; Store algorithm in WRAM
		; (It's multiplied by 2 to make some other code faster)
		and a,%00000111 ; --FFFAAA -> 00000AAA
		ld hl,FM_channel_algos
		ld e,c
		ld d,0
		add hl,de
		sla a ; algorithm *= 2
		ld (hl),a

		; Set FM volume update flag
		ld hl,FM_channel_enable
		add hl,de
		ld a,(hl)
		or a,FMCNT_VOL_UPDATE
		ld (hl),a
	pop hl
	pop af
	pop de
	ret

; a: amspms (--AA-PPP; Ams, Pms)
; c: channel (0~3)
FMCNT_set_amspms:
	push de
	push af
	push hl
		; Load channel's Panning, 
		; AMS and PMS from WRAM
		ld hl,FM_channel_lramspms
		ld e,c
		ld d,0
		add hl,de

		; Clear channel's AMS and PMS,
		; And OR the desired AMS and PMS.
		; then load OR result in e
		ld e,a
		ld a,(hl)
		and a,%11001000 ; LR??-??? -> LR00-000
		or a,e          ; LR00-000 -> LRAA-PPP
		ld (hl),a       ; Store register value in WRAM
		ld e,a

		; If the channel is even then
		; use register $B1, else use $B2
		ld d,REG_FM_CH13_LRAMSPMS
		bit 0,c
		jr z,FMCNT_set_amspms_even_ch
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

; a: panning (LR------; Left and Right)
; c: channel (0~3)
FMCNT_set_panning:
	push de
	push af
	push hl
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
		jr z,FMCNT_set_panning_even_ch
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
FMCNT_set_operator:
	push hl
	push de
	push af
	push bc
		push hl
			; Set FMCNT volume update flag
			ld hl,FM_channel_enable
			ld e,c
			ld d,0
			add hl,de 
			ld a,(hl)
			or a,FMCNT_VOL_UPDATE
			ld (hl),a
			
			; Load OP register offset in a, then 
			; add said offset to DTMUL base address.
			; After that, move result to d
			ld h,0
			ld l,b
			ld de,FM_op_register_offsets_LUT
			add hl,de
			ld a,(hl)
			add a,REG_FM_CH1_OP1_DTMUL
			ld d,a
		pop hl

		; If channel is odd (1 and 3) 
		; increment register address.
		ld a,c
		and a,1
		add a,d
		ld d,a

		; Set DT and MUL
		ld e,(hl)
		bit 1,c              ; \
		call z,port_write_a  ; | If the channel is 0 and 1 use port a else use port b
		call nz,port_write_b ; /
		inc hl               ; increment pointer to source
		ld a,$10             ; \
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
		ld a,$10 ; \
		add a,d  ; | Increment register address
		ld d,a   ; /

		; Set the operator registers
		ld b,5 ; operator registers left count
FMCNT_set_operator_loop:
		ld e,(hl)
		bit 1,c              ; \
		call z,port_write_a  ; | If the channel is 0 and 1 use port a else use port b
		call nz,port_write_b ; /

		; Increment pointer to source and register address
		inc hl
		ld a,$10
		add a,d
		ld d,a

		djnz FMCNT_set_operator_loop
	pop bc
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
	push bc
		ld c,ixl
		; Load base pitch from FMCNT_pitch_LUT in bc
		ld a,ixh
		and a,$0F ; -OOONNNN -> 0000NNNN; Get note
		ld l,a
		ld h,0
		ld de,FMCNT_pitch_LUT
		add hl,hl
		add hl,de
		ld c,(hl)
		inc hl
		ld b,(hl)

		; Set block/octave
		ld a,ixh
		and a,%01110000 ; Get octave (-OOONNNN -> 0OOO0000)
		add a,%00010000 ; Increment octave by 1
		srl a           ; Get octave in the right position (block needs to be set to octave)
		or a,b          ; OR block with F-Num 2
		ld b,a

		; Store bc in WRAM
		ld h,0
		ld e,ixl
		ld l,e
		ld de,FM_channel_frequencies
		add hl,hl
		add hl,de
		ld (hl),c
		inc hl
		ld (hl),b
	pop bc
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
; c: channel (0~3)
FMCNT_set_volume:
	push hl
	push bc
	push af
		; Store volume in WRAM
		ld b,0
		ld hl,FM_channel_volumes
		add hl,bc
		and a,127 ; Wrap volume inbetween 0 and 127
		ld (hl),a

		; set channel volume update flag
		ld hl,FM_channel_enable
		add hl,bc
		ld a,(hl)
		or a,FMCNT_VOL_UPDATE
		ld (hl),a
	pop af
	pop bc
	pop hl
	ret

; c: channel
FMCNT_play_channel:
	push af
	push hl
	push de
		; Load from WRAM the enabled operators
		ld hl,FM_channel_op_enable
		ld e,c
		ld d,0
		add hl,de
		ld a,(hl)

		; Calculate address to correct FM channel id
		ld hl,FM_channel_LUT
		add hl,de

		; Proceed to stop the FM channel
		ld e,(hl)
		ld d,REG_FM_KEY_ON
		rst RST_YM_WRITEA

		; OR the FM channel id and the OP enable 
		; nibble, then store the result in e and
		; write it to the FM Key On YM2610 register
		or a,(hl)
		ld e,a
		rst RST_YM_WRITEA
	pop de
	pop hl
	pop af
	ret

; c: channel
FMCNT_stop_channel:
	push af
	push de
	push hl
		; Load channel bit from LUT 
		ld hl,FM_channel_LUT
		ld e,c 
		ld d,0
		add hl,de

		; Stop FM channel
		ld e,(hl)
		ld d,REG_FM_KEY_ON
		rst RST_YM_WRITEA
	pop hl
	pop de
	pop af
	ret

; c: channel (0~3)
FM_enable_channel:
	push af
	push bc
	push hl
		ld b,0
		ld hl,FM_channel_enable
		add hl,bc
		ld (hl),1
	pop hl
	pop bc
	pop af
	ret

; c: channel (0~3)
FM_disable_channel:
	push af
	push bc
	push hl
		ld b,0
		ld hl,FM_channel_enable
		add hl,bc
		ld (hl),$00
	pop hl
	pop bc
	pop af
	ret

FM_channel_LUT:
	db FM_CH1, FM_CH2, FM_CH3, FM_CH4