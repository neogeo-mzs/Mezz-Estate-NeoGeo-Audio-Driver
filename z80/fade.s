; DOESN'T BACKUP REGISTERS  
FADE_irq:
    ; If the fade offset is 0, 
    ; the fade system is disabled.
    ld a,(FADE_offset)
    or a,a
    ret z

    ld b,a  ; store fade ofs in b
    ld a,(master_volume)
    ld c,a  ; backup old mvol in c
    add a,b ; new mvol is in a

    ; If FADE_offset is positive, check for overflow...
    bit 7,b 
    jp z,FADE_irq_check_overflow

    ; ...Else, check for underflow.
    or a,a ; cp a,0
    jp z,FADE_irq_solve_underflow  ; mvol has reached 0.
    cp a,c                         ; new_mvol >= old_mvol. (with a negative 
    jp nc,FADE_irq_solve_underflow ; offset it means an underflow happened)

FADE_irq_cend:
    ld (master_volume),a
    ld a,$FF 
    ld (do_reset_chvols),a
    ret

FADE_irq_solve_underflow:
    ; Solve underflow (or do nothing if mvol was 0),
    ; then disable fade out and set do_stop_song flag.
    ld a,255
    ld (do_stop_song),a
    xor a,a ; clear a
    ld (FADE_offset),a
    jp FADE_irq_cend

FADE_irq_check_overflow:
    cp a,255
    jp z,FADE_irq_solve_overflow ; mvol has reached 255... (fade in needs to be disabled)
    cp a,c                       
    jp nc,FADE_irq_cend          ; if new_mvol >= old_mvol, no overflow has accured. 

FADE_irq_solve_overflow:
    ; solve overflow (or change nothing if 
    ; mvol was 255), then disable fade in.
    xor a,a ; clear a
    ld (FADE_offset),a
    dec a ; a becomes 255
    jp FADE_irq_cend