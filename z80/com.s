;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                 BIOS COMMANDS                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BCOM_prepare_switch:
	di			; Disable interrupts
    xor  a
    out  ($0C),a            ; Clear both buffers
    out  ($00),a
    ; Silence YM2610 here
    ld   sp,$FFFC           ; Reset SP
    ld   hl,stayinram
    push hl
    retn                    ; RETN to stayinram

stayinram:
    ld   hl,$FFFD
    ld   (hl),$C3	        ; (FFFD)=$C3, opcode for JP
    ld   ($FFFE),hl	        ; (FFFE)=$FFFD (makes "JP FFFD")
    ei
    ld   a,$01
    out  ($0C),a            ; Tell 68k that we're ready
    jp   $FFFD              ; Quickly jump to RAM loop

BCOM_reset:
	di			; Disable interrupts
	ld   sp,$FFFF		; Clear call stack
	ld   hl,0
	push hl
	retn			; RETN to 0

BCOM_bios10:
	ld sp,$fffc
	ld hl,$0e35
	push hl
	retn


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                 USER COMMANDS                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

UCOM_init:
    push af
        ld a,$DF
        ld (com_sfxps_buffered_cvol),a
        xor a,a ; ld a,0
        ld (com_sfxps_buffered_prio),a
    pop af
    ret
    
; a: byte
UCOM_write2buffer:
    push af
    push bc
    push hl
    push de
        ld b,a ; backup byte in b

        ; Calculate address to
        ; com_buffer[com_buffer_idx_w]
        ; and store it into hl
        ld hl,com_buffer
        ld a,(com_buffer_idx_w)
        and a,COM_BUFFER_LENGTH-1
        sla a  ; a *= 2
        ld d,0
        ld e,a
        add hl,de

        ; If the byte is the command word's MSB,
        ; then increment the address by one
        ld a,(com_buffer_byte_significance)
        and a,1 ; Wrap the byte significance inbetween 0 and 1
        ld e,a
        add hl,de

        ld (hl),b ; Store byte into buffer

        ; If the byte is the command word's MSB,
        ; then that means a command was fully 
        ; loaded. Proceed to increment com_buffer_idx_w
        ; by 1 (and wrap it around if it exceeds the
        ; buffer's maximum size)
        ld a,(com_buffer_idx_w)
        add a,e
        and a,COM_BUFFER_LENGTH-1
        ld (com_buffer_idx_w),a

        ; Flip the buffer byte significance
        ld a,e
        xor a,1
        ld (com_buffer_byte_significance),a
    pop de
    pop hl
    pop bc
    pop af
    ret

UCOM_handle_command:
    push af
    push bc
    push hl
        ; If the user communication buffers are equal,
        ; that means there are no new commands to run.
        ld a,(com_buffer_idx_w) ; $F841
        ld b,a
        ld a,(com_buffer_idx_r) ; $F842
        cp a,b 
        jr z,UCOM_handle_command_return

        ; Load command into bc, then
        ; parse and execute it.
        sla a  ; \
        ld c,a ; | bc = com_buffer_idx_r*2
        ld b,0 ; /
        ld hl,com_buffer
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)

        call UCOM_run_command

        ; Set the current command
        ; word t$ $0080 (NOP)
        ld (hl),$00
        dec hl
        ld (hl),$80

        ; Increment com_buffer_idx_r
        srl a ; a /= 2
        inc a
        and a,COM_BUFFER_LENGTH-1
        ld (com_buffer_idx_r),a

UCOM_handle_command_return:
    pop hl
    pop bc
    pop af
    ret

; b: parameter
; c: command
UCOM_run_command:
    push af
    push bc
    push hl
    push de
        ; parameter &= UCOM_MASK (%01111111)
        ld a,b
        and a,UCOM_MASK
        ld b,a

        ; command &= UCOM_MASK (%01111111)
        ld a,c
        and a,UCOM_MASK
        ld c,a

        ; hl = &UCOM_command_vectors[command]
        sla a ; a *= 2
        ld e,a
        ld d,0
        ld hl,UCOM_command_vectors
        add hl,de

        ; hl *= hl; 
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl

        jp (hl)

UCOM_run_command_return:
    pop de
    pop hl
    pop bc
    pop af
    ret

UCOM_command_vectors:
    dw UCOM_CMD_nop,               UCOM_CMD_play_song
    dw UCOM_CMD_stop_song,         UCOM_CMD_sfxps_buffer_cvol
    dw UCOM_CMD_sfxps_buffer_prio, UCOM_CMD_sfxps_play_smp
    dup 122
        dw UCOM_CMD_invalid
    edup

UCOM_CMD_nop:
    jp UCOM_run_command_return

; b: song
; c: $01
UCOM_CMD_play_song:
    push af
        ld a,b
        call MLM_play_song
    pop af
    jp UCOM_run_command_return

; b: $00
; c: $02
UCOM_CMD_stop_song:
    call MLM_stop
    jp UCOM_run_command_return

; b: %0LRVVVVV
; c: $03
UCOM_CMD_sfxps_buffer_cvol:
    push af
    push de
        ; Format %1LRVVVVV to %LR0VVVVV
        ld a,b
        and a,%01100000 ; %0LRVVVVV -> %0LR00000
        sla a           ; %0LR00000 -> %LR000000
        ld e,a
        ld a,b
        and a,%00011111 ; %0LRVVVVV -> %000VVVVV
        or a,e          ; %000VVVVV -> %LR0VVVVV
        ld (com_sfxps_buffered_cvol),a
    pop de
    pop af
    jp UCOM_run_command_return

; b: %0PPPPPPP
; c: $04
UCOM_CMD_sfxps_buffer_prio:
    push af
        ld a,b
        ld (com_sfxps_buffered_prio),a
    pop af
    jp UCOM_run_command_return

; b: %0SSSSSSS
; c: $05
UCOM_CMD_sfxps_play_smp:
    push bc
    push iy
    push af
        ld a,(com_sfxps_buffered_cvol)
        ld iyl,a
        ld a,(com_sfxps_buffered_prio)
        ld c,a
        call SFXPS_play_sfx
    pop af
    pop iy
    pop bc
    jp UCOM_run_command_return

UCOM_CMD_invalid:
    call softlock