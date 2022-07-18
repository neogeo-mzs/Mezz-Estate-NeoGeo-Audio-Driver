; DOESN'T BACKUP REGISTERS  
FADE_irq:
    ; If the fade offset is 0, 
    ; the fade system is disabled.
    ld a,(FADE_offset)
    or a,a
    ret z

    ld b,a
    ld a,(master_volume)
    add a,b

    ; if the result overflowed, clamp it
    ; and clear the fade offset.
    ; if the result underflowed, clamp it,
    ; clear the fade offset and buffer a song stop.
    ld b,a
    bit 7,a
    jr nz,FADE_irq

    jr nc,FADE_irq_cend ; - B7: 0; CARRY: 0 (  +2 + +4 = +6   OK)

    xor a,a
    ld (FADE_offset),a
    ld b,255            ; \
    jr FADE_irq_cend    ; - B7: 0; CARRY: 1 (+254 + +4 = +2   NOT OK, SHOULD BE 255)
FADE_irq_bit7_set:
    jr c,FADE_irq_cend  ; - B7: 1; CARRY: 1 (+254 + -4 = +250 OK)

    ld (do_stop_song),a ; since b7 is 1, a is guaranteed to not be 0
    xor a,a
    ld (FADE_offset),a

    ld b,0              ; \
    jr FADE_irq_cend    ; - B7: 1; CARRY: 0 (  +2 + -4 = +254 NOT OK, SHOULD BE 0)

FADE_irq_cend:
    ld a,b
    ld (master_volume),a

    ld a,$FF 
    ld (do_reset_chvols),a
    ret