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
		; clear FM WRAM
		ld hl,FM_wram_start
		ld de,FM_wram_start+1
		ld bc,FM_wram_end-FM_wram_start-1
		ld (hl),0
		ldir

		; set all operator TLs to $7F
		;ld hl,FM_operator_TLs
		;ld de,FM_operator_TLs+1
		;ld bc,FM_CHANNEL_COUNT*FM_OP_COUNT - 1
		;ld (hl),$7F
		;ldir
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

		; If if FMCNT vol upd. flag is enabled...
		; (This check is executed inside the function
		;  too, this is to save time in most scenarios)
		bit 1,a
		call nz,FMCNT_update_total_levels

		bit 2,a
		call nz,FMCNT_update_pitch_slide

		; Clear all the update bitflags
		ld a,(hl)
		and a,FMCNT_VOL_UPDATE ^ $FF
		ld (hl),a 

FMCNT_irq_loop_skip:
		dec hl
	inc b
	djnz FMCNT_irq_loop
	ret

; b: channel (0~3)
; (FM_channel_volumes[channel]): volume (0~7F)
; DOESN'T BACKUP DE
FMCNT_update_total_levels:
	push bc
	push hl
	push af
		; if the FMCNT vol enable flag
		; isn't set, return
		ld hl,FM_channel_enable
		ld d,0
		ld e,b
		add hl,de
		ld a,(hl)
		bit 1,a
		jp z,FMCNT_update_total_levels_ret
		
		; If it is set, clear volume flag
		; and proceed with the function
		and a,FMCNT_VOL_UPDATE ^ $FF
		ld (hl),a
		
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
		ld hl,FMCNT_tlupdate_vectors-8
		add hl,de
		;add hl,de ; Since the algorithm is stored multiplied by two, there's no need to add twice
		jp (hl)
FMCNT_update_total_levels_ret:
	pop af
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
	pop af
	pop hl
	pop bc
	ret

; b: channel (0~3)
;   Indexed by FM channel algorithm
;   COULD BE MADE FASTER WITH JP INSTRUCTIONS
FMCNT_tlupdate_vectors:
	jr FMCNT_tlupdate_algo4
	jr FMCNT_tlupdate_algo5_6
	jr FMCNT_tlupdate_algo5_6
	jr FMCNT_tlupdate_algo7

FMCNT_tlupdate_algo4:
		call FMCNT_update_modulator_tl ; OP1
		inc c
		call FMCNT_update_carrier_tl   ; OP2
		inc c
		call FMCNT_update_modulator_tl ; OP3
		inc c
		call FMCNT_update_carrier_tl   ; OP4
	pop af
	pop hl
	pop bc
	ret

FMCNT_tlupdate_algo5_6:
		call FMCNT_update_modulator_tl ; OP1
		inc c
		call FMCNT_update_carrier_tl   ; OP2
		inc c
		call FMCNT_update_carrier_tl   ; OP3
		inc c
		call FMCNT_update_carrier_tl   ; OP4
	pop af
	pop hl
	pop bc
	ret

FMCNT_tlupdate_algo7:
		call FMCNT_update_carrier_tl   ; OP1
		inc c
		call FMCNT_update_carrier_tl   ; OP2
		inc c
		call FMCNT_update_carrier_tl   ; OP3
		inc c
		call FMCNT_update_carrier_tl   ; OP4
	pop af
	pop hl
	pop bc
	ret

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

		; Load scaled volume from LUT
		ld l,a
		ld h,0
		xor a,a ; \
		srl h   ;  \
		rr l    ;   | hl *= 128
		rra     ;   /
		ld h,l  ;  /
		ld l,a  ; /
		ld d,0
		add hl,de
		ld de,FM_vol_LUT
		add hl,de
		ld a,(hl)

		; Invert the result's least 
		; significant 7 bits
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
; DOESN'T BACKUP DE, IX, AF
FMCNT_update_pitch_slide:
	push hl
	push bc
		; Load pitch slide offset from WRAM into hl
		ld ix,FM_pitch_slide_ofs
		ld c,b
		ld b,0
		add ix,bc
		add ix,bc
		ld e,(ix+0)
		ld d,(ix+1)
		ld a,d ; Load MSB in a to check sign of offset later
		ex hl,de
		
		; Load current pitch from WRAM into de
		ld ix,FM_channel_frequencies
		add ix,bc
		add ix,bc
		ld e,(ix+0)
		ld d,(ix+1)

		; Offset pitch 
		add hl,de
		ex hl,de
		call FMCNT_check_fnum_overunderflow

		; Store pitch back into WRAM
		ld (ix+0),e
		ld (ix+1),d
		ex hl,de
		
		; Write Block and F-Num 2 to YM2610
		ld e,h
		ld d,REG_FM_CH13_FBLOCK
		bit 0,c
		jr z,FMCNT_update_pitch_slide_even_ch
		inc d
FMCNT_update_pitch_slide_even_ch:
		bit 1,c
		call z,port_write_a
		call nz,port_write_b

		; Write F-Num 1 to YM2610
		ld e,l
		dec d ; -\
		dec d ;  | d -= 4
		dec d ;  /
		dec d ; /
		bit 1,c
		call z,port_write_a
		call nz,port_write_b
	pop bc
	pop hl
	ret

; [INPUT]
;   bc: channel
;   de: new pitch
;   ix: &FM_channel_frequencies[ch]
; [OUTPUT]
;   de: clamped pitch
; DOESN'T BACKUP AF
FMCNT_check_fnum_overunderflow:
	push hl
		; Load original frequency MSB,
		; then AND away the fnum2 to 
		; obtain the block, store it into l
		ld a,(ix+1)
		and a,%00111000 ; $00BBBFFF -> $00BBB000
		ld l,a
		
		; Obtain block of the new pitch, store it in a
		ld a,d
		and a,%00111000 ; $00BBBFFF -> $00BBB000

		; If new_block == old_block return
		cp a,l
		jp z,FMCNT_check_fnum_overunderflow_ret

		; If new_block < old_block, then
		; an underflow happened.
		jp c,FMCNT_solve_fnum_underflow

		; Else, an overflow happened
		; Set pitch to $7FF with the old block
		ld de,$07FF
		ld a,d ; -- return $7FF | old_block
		or a,l ;  /
		ld d,a ; /

FMCNT_check_fnum_overunderflow_ret:
	pop hl
	ret	

FMCNT_solve_fnum_underflow:
		; Return $001 with old block
		ld e,1
		ld d,l
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
	push iy
		ld c,ixl

		; Calculate pointer to FM_channel_frequencies[ch]
		ld iy,FM_channel_frequencies
		ld b,0
		add iy,bc
		add iy,bc

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
		;add a,%00010000 ; Increment octave by 1
		srl a           ; Get octave in the right position (block needs to be set to octave)
		or a,b          ; OR block with F-Num 2
		ld b,a

		; Store pitch in WRAM
		ld (iy+0),c ; F-Num 1
		ld (iy+1),b ; Block and F-Num 2 

		; WRITE TO REGISTERS DIRECTLY DO NOT BUFFER IN WRAM FOR NO ABSOLUTE REASON
		; Write Block and F-Num 2 
		ld e,b 
		ld d,REG_FM_CH13_FBLOCK
		ld a,ixl
		bit 0,a 
		jr z,FMCNT_set_note_even_ch
		inc d
FMCNT_set_note_even_ch:
		bit 1,a 
		call z,port_write_a
		call nz,port_write_b

		; Set F-Num 1
		ld e,c
		dec d ; -\
		dec d ;  | d -= 4
		dec d ;  /
		dec d ; /
		bit 1,a
		call z,port_write_a
		call nz,port_write_b
	pop iy
	pop bc
	pop af
	pop de
	pop hl
	ret

; Taken straight from deflemask's vgm output
; octave 0 = block 0, etc...
FMCNT_pitch_LUT:
	;  C     C#    D     D#    E     F     F#    G     
	dw $269, $28E, $2B5, $2DE, $30A, $338, $369, $39D 
	;  G#    A     A#    B
	dw $3D4, $40E, $44C, $48D, $48D, $48D, $48D, $48D
	; 
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
FMCNT_enable_channel:
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
FMCNT_disable_channel:
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

FM_vol_LUT:
	incbin "fm_vol_lut.bin"