; This is to be called when TMB reaches 0,
; To make fades last the same speed regardless
; of the frequency of the currently playing song
; (Which uses Timer A)
; DOESN'T BACKUP REGISTERS
FDCNT_irq:
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
    jp z,FDCNT_irq_overflow_check

    ; taking a + b = c and assuming that b < 0, 
    ; then c < a must always be true.
    ld hl,MLM_master_volume
    cp a,(hl)
    jp c,FDCNT_irq_overflow_check_ret
    ld a,0 ; Else, an underflow must have happened.

FDCNT_irq_overflow_check_ret:
    ; Store master volume back into WRAM,
    ; and update all channel volumes
    ld (hl),a

    ; MLM_set_channel_volume handles scaling
    ; the volume based on the master volume
    ; by itself, while saving the original 
    ; channelvolume in WRAM, not the scaled 
    ; one (that'd cause issues).
    ld c,0
    ld hl,MLM_channel_volumes
    dup CHANNEL_COUNT
        ld a,(hl) 
        call MLM_set_channel_volume
        inc hl
        inc c
    edup
    ret

FDCNT_irq_overflow_check:
    ; taking a + b = c and assuming b is
    ; positive, then c >= a must always be true.
    ld hl,MLM_master_volume
    cp a,(hl)
    jp nc,FDCNT_irq_overflow_check_ret

    ; If that isn't the case, an overflow happened...
    ; or math broke and the apocalypse is coming.
    ld a,$FF
    jp FDCNT_irq_overflow_check_ret