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
    ld hl,MLM_master_volume
    add a,(hl)
    ld hl,FDCNT_offset
    bit 7,(hl)
    jp z,FDCNT_irqB_overflow_check

    ; taking a + b = c and assuming that b < 0, 
    ; then c < a must always be true.
    ld hl,MLM_master_volume
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
    ld hl,MLM_master_volume
    cp a,(hl)
    jp nc,FDCNT_irqB_overflow_check_ret

    ; If that isn't the case, an overflow happened...
    ; or math broke and the apocalypse is coming.
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

    ; MLM_set_channel_volume handles scaling
    ; the volume based on the master volume
    ; by itself, while saving the original 
    ; channelvolume in WRAM, not the scaled 
    ; one (that'd cause issues).
    ld c,0
    ld ix,MLM_channel_volumes
    ld hl,MLM_channel_control
    brk
FDCNT_irqA_loop_cnt set 0
    dup CHANNEL_COUNT
        bit 0,(hl)
        jr z,$+8                      ; +2 = 2b
        ld a,(ix+FDCNT_irqA_loop_cnt) ; +3 = 5b
        call MLM_set_channel_volume   ; +3 = 8b

        inc hl
        inc c
FDCNT_irqA_loop_cnt set FDCNT_irqA_loop_cnt+1
    edup
    ret