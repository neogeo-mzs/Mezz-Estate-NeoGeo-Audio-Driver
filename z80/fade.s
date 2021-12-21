; This is to be called when TMB reaches 0,
; To make fades last the same speed regardless
; of the frequency of the currently playing song
; (Which uses Timer A)
; DOESN'T BACKUP REGISTERS
FDCNT_irqB:
    ; If the fade offset is 0, return
    ld a,(FDCNT_offset)
    or a,a ; cp a,0
    ret z

    ; Add offset to MLM master volume,
    ; then clamp it inbetween 0 and 255
    ld hl,master_volume
    add a,(hl)
    ld hl,FDCNT_offset
    bit 7,(hl)
    jp z,FDCNT_irqB_overflow_check

    ; taking a + b = c and assuming that b < 0, 
    ; then c < a must always be true.
    ld hl,master_volume
    cp a,(hl)
    jp c,FDCNT_irqB_overflow_check_ret
    
    ; Else, an underflow must have happened.
    xor a,a ; ld a,0
    ld (FDCNT_offset),a
FDCNT_irqB_overflow_check_ret:
    ; Store master volume back into WRAM,
    ; and update all channel volumes
    ld (hl),a
    ld a,$FF
    ld (FDCNT_do_reset_chvols),a
    ret

FDCNT_irqB_overflow_check:
    ; taking a + b = c and assuming b is
    ; positive, then c >= a must always be true.
    ld hl,master_volume
    cp a,(hl)
    jp nc,FDCNT_irqB_overflow_check_ret

    ; If that isn't the case, an overflow happened...
    xor a,a ; ld a,0
    ld (FDCNT_offset),a
    ld a,$FF
    jp FDCNT_irqB_overflow_check_ret

; DOESN'T BACKUP REGISTER
FDCNT_irqA:
    ld a,(FDCNT_do_reset_chvols)
    or a,a ; cp a,0
    ret z

    xor a,a
    ld (FDCNT_do_reset_chvols),a
    call MLM_reset_active_chvols
    ret