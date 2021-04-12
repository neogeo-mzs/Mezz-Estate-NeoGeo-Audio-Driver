IRQ: ; MLM_2CH_mode
	push af
	push bc
	push de
	push hl
	push ix
	push iy
		call IRQ_handle_commands
		call MLM_irq

        ; data = TM_CNT_LOAD_TA | TM_CNT_ENABLE_TA_IRQ | TM_CNT_TA_FLG_RESET
        ; data |= *EXT_2CH_mode
        ld e,TM_CNT_LOAD_TA | TM_CNT_ENABLE_TA_IRQ | TM_CNT_TA_FLG_RESET
        ld a,(EXT_2CH_mode)
        or a,e
        ld e,a

        ld d,REG_TIMER_CNT
		rst RST_YM_WRITEA
	pop iy
	pop ix
	pop hl
	pop de
	pop bc
	pop af
	ei
	ret

; bc: word
IRQ_write2buffer:
    push af
    push bc
    push hl
    push de
        ; Calculate address to
        ; IRQ_buffer[IRQ_buffer_idx_w]
        ; and store it into hl
        ld hl,IRQ_buffer
        ld a,(IRQ_buffer_idx_w)
        and a,IRQ_BUFFER_LENGTH-1
        sla a  ; a *= 2
        ld d,0
        ld e,a
        add hl,de

        ; Store word into buffer
        ld (hl),c
        inc hl
        ld (hl),b

        ; increment buffer write
        ld a,(IRQ_buffer_idx_w)
        inc a
        and a,IRQ_BUFFER_LENGTH-1
        ld (IRQ_buffer_idx_w),a
    pop de
    pop hl
    pop bc
    pop af
    ret

IRQ_handle_commands:
    push af
    push bc
    push hl
IRQ_handle_command_loop:
        ; If the user communication buffers are equal,
        ; that means there are no new commands to run.
        ld a,(IRQ_buffer_idx_w) ; $F841
        ld b,a
        ld a,(IRQ_buffer_idx_r) ; $F842
        cp a,b 
        jr z,IRQ_handle_command_return

        ; Load command into bc, then
        ; parse and execute it.
        sla a  ; \
        ld c,a ; | bc = IRQ_buffer_idx_r*2
        ld b,0 ; /
        ld hl,IRQ_buffer
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)

        call IRQ_run_command

        ; Set the current command
        ; word to $0000 (NOP)
        ld (hl),&00
        dec hl
        ld (hl),&00

        ; Increment IRQ_buffer_idx_r
        srl a ; a /= 2
        inc a
        and a,IRQ_BUFFER_LENGTH-1
        ld (IRQ_buffer_idx_r),a

        jr IRQ_handle_command_loop

IRQ_handle_command_return:
    pop hl
    pop bc
    pop af
    ret

; b: parameter
; c: command
IRQ_run_command:
    push af
    push bc
    push hl
    push de
        ; hl = &IRQ_command_vectors[command]
        ld l,c
        ld h,0
        ld de,IRQ_command_vectors
        add hl,hl
        add hl,de

        ; hl *= hl; 
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl

        jp (hl)

IRQ_run_command_return:
    pop de
    pop hl
    pop bc
    pop af
    ret

IRQ_command_vectors:
    dw IRQ_CMD_nop,           IRQ_CMD_mlm_play_song
    dw IRQ_CMD_mlm_stop_song, IRQ_CMD_invalid
    dsw 256-4,IRQ_CMD_invalid

IRQ_CMD_nop:
    jp IRQ_run_command_return

; b: song
IRQ_CMD_mlm_play_song:
    push af
    	ld a,b
    	call MLM_play_song
    pop af
    jp IRQ_run_command_return

IRQ_CMD_mlm_stop_song:
    call MLM_stop
    jp IRQ_run_command_return

IRQ_CMD_invalid:
    call softlock