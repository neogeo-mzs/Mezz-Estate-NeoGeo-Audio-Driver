fm_stop:
	push de
		; Silence all OP4s
		ld e,127
		ld d,REG_FM_CH1_OP1_TVOL+$C
		rst RST_YM_WRITEA ; CH1
		rst RST_YM_WRITEB ; CH3
		inc d
		rst RST_YM_WRITEA ; CH2
		rst RST_YM_WRITEB ; CH4

		; Silence all OP3s
		ld d,REG_FM_CH1_OP1_TVOL+$4
		rst RST_YM_WRITEA ; CH1
		rst RST_YM_WRITEB ; CH3
		inc d
		rst RST_YM_WRITEA ; CH2
		rst RST_YM_WRITEB ; CH4

		; Silence all OP2s
		ld d,REG_FM_CH1_OP1_TVOL+$8
		rst RST_YM_WRITEA ; CH1
		rst RST_YM_WRITEB ; CH3
		inc d
		rst RST_YM_WRITEA ; CH2
		rst RST_YM_WRITEB ; CH4

		; Silence all OP1s
		ld d,REG_FM_CH1_OP1_TVOL
		rst RST_YM_WRITEA ; CH1
		rst RST_YM_WRITEB ; CH3
		inc d
		rst RST_YM_WRITEA ; CH2
		rst RST_YM_WRITEB ; CH4

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

		call fm_stop

		; Set all channel pannings to CENTER
		ld a,PANNING_CENTER
		ld (FM_ch1+FM_Channel.lramspms),a
		ld (FM_ch2+FM_Channel.lramspms),a
		ld (FM_ch3+FM_Channel.lramspms),a
		ld (FM_ch4+FM_Channel.lramspms),a
	pop af
	pop bc
	pop de
	pop hl
	ret

; DOESN'T BACKUP REGISTERS !!!
FMCNT_irq:
	ld b,FM_CHANNEL_COUNT
	ld ix,FM_ch4
	
FMCNT_irq_loop:
	dec b
		; If the channel's enable bit is 0,
		; then continue to the next channel
		ld a,(ix+FM_Channel.enable)
		bit 0,a
		jr z,FMCNT_irq_loop_skip

		; If if FMCNT vol upd. flag is enabled...
		; (This check is executed inside the function
		;  too, this is to save time in most scenarios)
		bit 1,a
		call nz,FMCNT_update_total_levels

		call FMCNT_update_frequency
		call FMCNT_update_pslide

		; Clear all the update bitflags
		ld a,(ix+FM_Channel.enable)
		and a,FMCNT_VOL_UPDATE ^ $FF
		ld (ix+FM_Channel.enable),a 

FMCNT_irq_loop_skip:
		ld de,-FM_Channel.SIZE
		add ix,de
	inc b
	djnz FMCNT_irq_loop
	ret

; b:  channel (0~3)
; ix: address to FMCNT channel data
; DOESN'T BACKUP HL AND DE
;  Adds frequency and pitch offset together
;  and sets the YM2610 registers
FMCNT_update_frequency:
	push af
		push bc
			ld a,(ix+FM_Channel.frequency+1)
			and a,%00111000 ; Mask out F-Num to get the Block
			ld b,a

			; Offset frequency
			ld e,(ix+FM_Channel.frequency+0)
			ld d,(ix+FM_Channel.frequency+1)
			ex hl,de
			ld e,(ix+FM_Channel.pitch_ofs+0)
			ld d,(ix+FM_Channel.pitch_ofs+1)
			add hl,de

			; Clamp frequency floor
			;   if custom clamp disabled or custom clamp
			;   is a ceil clamp, use default value
			bit 7,(ix+FM_Channel.fnum_clamp+1)
			jp z,FMCNT_update_frequency_def_fclamp
			bit 6,(ix+FM_Channel.fnum_clamp+1)
			jp nz,FMCNT_update_frequency_def_fclamp ; custom clamp is ceil...

			; Custom floor clamp
			ld a,(ix+FM_Channel.fnum_clamp+1)
			and a,%00000111 ; Get fnum minimum
			or a,b 
			ld d,a
			ld e,(ix+FM_Channel.fnum_clamp)
			or a,a
			sbc hl,de
			add hl,de
			jp nc,FMCNT_update_frequency_no_fclamp ; if hl >= MIN_FNUM...

			; if the freq is below the custom floor,
			; clear the pitch slide offset...
			xor a,a
			ld (ix+FM_Channel.pslide_ofs+0),a
			ld (ix+FM_Channel.pslide_ofs+1),a

			; ...fix the value and skip the ceil clamp test
			ld hl,de
			jp FMCNT_update_frequency_no_cclamp
FMCNT_update_frequency_no_fclamp:

			; Clamp frequency ceiling
			;   if custom clamp disabled or custom clamp
			;   is a ceil clamp, use default value
			bit 7,(ix+FM_Channel.fnum_clamp+1)
			jp z,FMCNT_update_frequency_def_cclamp
			bit 6,(ix+FM_Channel.fnum_clamp+1)
			jp z,FMCNT_update_frequency_def_cclamp ; custom clamp is floor...

			; Custom ceiling clamp
			ld a,(ix+FM_Channel.fnum_clamp+1)
			and a,%00000111 ; Get fnum minimum
			or a,b 
			ld d,a
			ld e,(ix+FM_Channel.fnum_clamp)
			or a,a
			sbc hl,de
			add hl,de
			jp c,FMCNT_update_frequency_no_cclamp ; if hl < MAX_FNUM...

			; clear the pitch slide offset...
			xor a,a
			ld (ix+FM_Channel.pslide_ofs+0),a
			ld (ix+FM_Channel.pslide_ofs+1),a
			ld hl,de
FMCNT_update_frequency_no_cclamp:
		pop bc

		; Write frequency to registers
		; CH1, CH3 (b = 0, 2): $A5
		; CH2, CH4 (b = 1, 3): $A6
		ld a,b
		and a,%00000001
		add a,REG_FM_CH13_FBLOCK

		; Write to Block & F-Num 2 register
		ld e,h 
		ld d,a
		bit 1,b
		call z,port_write_a
		call nz,port_write_b

		; Write to F-Num 1 register
		ld a,-4  ; \
		add a,d  ; | d -= 4
		ld d,a   ; / 
		ld e,l
		bit 1,b
		call z,port_write_a
		call nz,port_write_b
	pop af
	ret

FMCNT_update_frequency_def_fclamp:
	ld a,b
	or a,FMCNT_MIN_FNUM >> 8
	ld d,a
	ld e,FMCNT_MIN_FNUM & $FF
	or a,a
	sbc hl,de
	add hl,de
	jp nc,FMCNT_update_frequency_no_fclamp ; if hl >= MIN_FNUM...
	
	xor a,a
	ld (ix+FM_Channel.pslide_ofs+0),a
	ld (ix+FM_Channel.pslide_ofs+1),a
	ld hl,de
	jp FMCNT_update_frequency_no_cclamp

FMCNT_update_frequency_def_cclamp:
	ld a,b
	or a,FMCNT_MAX_FNUM >> 8
	ld d,a
	ld e,FMCNT_MAX_FNUM & $FF
	or a,a
	sbc hl,de
	add hl,de
	jp c,FMCNT_update_frequency_no_cclamp ; if hl < MAX_FNUM...

	xor a,a
	ld (ix+FM_Channel.pslide_ofs+0),a
	ld (ix+FM_Channel.pslide_ofs+1),a
	ld hl,de
	jp FMCNT_update_frequency_no_cclamp

; ix: address to FMCNT channel data
; b:  channel (0~3)
; DOESN'T BACKUP AF, HL AND DE
; Adds the pitch slide offset to
; the pitch offset
FMCNT_update_pslide:
	ld e,(ix+FM_Channel.pitch_ofs+0)
	ld d,(ix+FM_Channel.pitch_ofs+1)
	ex hl,de
	ld e,(ix+FM_Channel.pslide_ofs+0)
	ld d,(ix+FM_Channel.pslide_ofs+1)
	add hl,de
	ex hl,de
	ld (ix+FM_Channel.pitch_ofs+0),e
	ld (ix+FM_Channel.pitch_ofs+1),d
	ret

; b:  channel (0~3)
; ix: address to FMCNT channel data
; (FM_channel_volumes[channel]): volume (0~7F)
; DOESN'T BACKUP DE
FMCNT_update_total_levels:
	push bc
	push hl
	push af
		; if the FMCNT vol enable flag
		; isn't set, return
		ld a,(ix+FM_Channel.enable)
		bit 1,a
		jp z,FMCNT_update_total_levels_ret
		
		; If it is set, clear volume flag
		; and proceed with the function
		and a,FMCNT_VOL_UPDATE ^ $FF
		ld (ix+FM_Channel.enable),a

		ld e,(ix+FM_Channel.algo)
		ld c,1 ; Prepare operator value

		; Since algorithms below ALGO4 are treated
		; the same, they can quickly be dealt with,
		; without indexing the vector table
		bit 3,e ; It'd normally check bit 2, but the algorithm is multiplied by two
		jp z,FMCNT_update_total_levels_algo_0_1_2_3

		; for all the other algorithms, you have
		; to index the vector table.
		ld hl,FMCNT_tlupdate_vectors-8
		ld d,0
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

; c:  operator (1~4)
; b:  channel (0~3)
; ix: &FM_ch[chs] 
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

		; Load scaled volume from LUT
		ld e,(ix+FM_Channel.volume)
		ld d,0
		ld l,a
		ld h,0
		xor a,a ; \
		srl h   ;  \
		rr l    ;   | hl *= 128
		rra     ;   /
		ld h,l  ;  /
		ld l,a  ; /
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

; a:  fbalgo (--FFFAAA; Feedback, Algorithm)
; c:  channel (0~3)
; ix: Pointer to FMCNT channel data
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
		rlca ; algorithm *= 2
		ld (ix+FM_Channel.algo),a

		; Set FM volume update flag
		ld a,(ix+FM_Channel.enable)
		or a,FMCNT_VOL_UPDATE
		ld (ix+FM_Channel.enable),a
	pop hl
	pop af
	pop de
	ret

; a: amspms (--AA-PPP; Ams, Pms)
; c: channel (0~3)
; ix: Pointer to FMCNT channel data
FMCNT_set_amspms:
	push de
	push af
	push hl
		; Clear channel's AMS and PMS,
		; And OR the desired AMS and PMS.
		; then load OR result in e
		ld e,a
		ld a,(ix+FM_Channel.lramspms)
		and a,%11001000               ; LR??-??? -> LR00-000
		or a,e                        ; LR00-000 -> LRAA-PPP
		ld (ix+FM_Channel.lramspms),a ; Store register value in WRAM
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
	push ix
		; Calculate address to
		; FMCNT channel data
		push af
			ld a,c
			rlca ; -\
			rlca ;  | a *= 16
			rlca ;  /
			rlca ; /
			ld e,a
			ld d,0
			ld ix,FM_ch1
			add ix,de
		pop af

		; Clear channel's AMS and PMS,
		; And OR the desired AMS and PMS
		ld e,a
		ld a,(ix+FM_Channel.lramspms)
		and a,%00111111               ; ??AA-PPP -> 00AA-PPP
		or a,e                        ; 00AA-PPP -> LRAA-PPP
		ld (ix+FM_Channel.lramspms),a ; Store register value in WRAM

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
	pop ix
	pop af
	pop de
	ret

; hl: pointer to operator data
; c:  channel (0~3)
; b:  operator (0~3)
; ix: Pointer to FMCNT channel data
FMCNT_set_operator:
	push hl
	push de
	push af
	push bc
		push hl
			ld a,(ix+FM_Channel.enable)
			or a,FMCNT_VOL_UPDATE
			ld (ix+FM_Channel.enable),a
			
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

; iyh: note (-OOONNNN; Octave, Note)
; iyl: channel
; ix:  pointer to FMCNT channel data
FMCNT_set_note:
	push hl
	push de
	push af
	push bc
		; Load base pitch from FMCNT_pitch_LUT in bc
		ld a,iyh
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
		ld a,iyh
		and a,%01110000 ; Get octave (-OOONNNN -> 0OOO0000)
		srl a           ; Get octave in the right position (block needs to be set to octave)
		or a,b          ; OR block with F-Num 2
		ld b,a

		; Store pitch in WRAM
		ld (ix+FM_Channel.frequency+0),c ; F-Num 1
		ld (ix+FM_Channel.frequency+1),b ; Block and F-Num 2

		; Reset pitch offset
		xor a,a ; ld a,0
		ld (ix+FM_Channel.pitch_ofs+0),a
		ld (ix+FM_Channel.pitch_ofs+1),a

		; WRITE TO REGISTERS DIRECTLY DO NOT BUFFER IN WRAM FOR NO ABSOLUTE REASON
		; Write Block and F-Num 2 
		ld e,b 
		ld d,REG_FM_CH13_FBLOCK
		ld a,iyl
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
	pop bc
	pop af
	pop de
	pop hl
	ret

; [INPUT]
;   d: note (%-OOONNNN Octave; Note)
;   e: block
; [OUTPUT]
;   hl: note's pitch
; DOESN'T BACKUP AF
; To convert an FM pitch from block to block-1,
; multiply the FNum by 2, and viceversa.
FMCNT_get_note_with_block:
	push bc
		; Load note in c and octave in b
		ld a,d
		and a,$0F
		ld c,a
		ld a,d
		and a,%01110000
		rrca ; -\
		rrca ;  | 0OOO0000 >> 00000OOO
		rrca ;  /
		rrca ; /
		ld b,a

		; Load FNum in hl
		push bc
			ld hl,FMCNT_pitch_LUT
			ld b,0
			add hl,bc
			add hl,bc
			ld c,(hl)
			inc hl
			ld b,(hl)
			ld hl,bc
		pop bc

		; If the octave and block are equal, return.
		; If the octave is bigger than the block, 
		; shift FNum to the left until they're equal.
		; If the opposite is true, do the same but
		; shift FNum to the right.
		ld a,b
		cp a,e
		jp z,FMCNT_get_note_with_block_equal      ; if equal...
		jp nc,FMCNT_get_note_with_block_lower_blk ; if octave > block...

		; Else (octave < block)...
FMCNT_get_note_with_block_hiblk_loop:
		srl_hl ; shift hl to the right until octave == block
		inc a
		cp a,b 
		jp nz,FMCNT_get_note_with_block_hiblk_loop

FMCNT_get_note_with_block_equal:
		; OR the block and the FNum to obtain the final pitch
		rlca
		rlca
		rlca
		or a,h
		ld h,a
	pop bc
	ret

FMCNT_get_note_with_block_lower_blk:
	add hl,hl ; shift hl to the left until octave == block
	dec a
	cp a,b
	jp nz,FMCNT_get_note_with_block_lower_blk
	jp FMCNT_get_note_with_block_equal	

; Compatible with deflemask
; octave 0 = block 0, etc...
FMCNT_pitch_LUT:
	;  C     C#    D     D#    E     F     F#    G     
	dw $269, $28E, $2B5, $2DE, $30A, $338, $369, $39D 
	;  G#    A     A#    B
	dw $3D4, $40E, $44C, $48D, $48D, $48D, $48D, $48D
	; 

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
	push hl
	push de
		; Calculate address to FM_Channel.enable
		ld a,c
		rlca    ; \
		rlca    ;  \
		rlca    ;  | offset = channel*16
		rlca    ;  /
		and $F0 ; /
		ld l,a
		ld h,0
		ld de,FM_ch1+FM_Channel.enable
		add hl,de

		ld (hl),1
	pop de
	pop hl
	pop af
	ret

FM_channel_LUT:
	db FM_CH1, FM_CH2, FM_CH3, FM_CH4

FM_vol_LUT:
	incbin "fm_vol_lut.bin"