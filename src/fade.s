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
    jp z,check_overflow$

    ; ...Else, check for underflow.
    or a,a ; cp a,0
    jp z,solve_underflow$  ; mvol has reached 0.
    cp a,c                 ; new_mvol >= old_mvol. (with a negative 
    jp nc,solve_underflow$ ; offset it means an underflow happened)

check_end$:
    ld (master_volume),a
    ld a,$FF 
    ld (do_reset_chvols),a
    ret

solve_underflow$:
    ; Solve underflow (or do nothing if mvol was 0),
    ; then disable fade out and set do_stop_song flag.
    ld a,255
    ld (do_stop_song),a
    xor a,a ; clear a
    ld (FADE_offset),a
    jp check_end$

check_overflow$:
    cp a,255
    jp z,solve_overflow$ ; mvol has reached 255... (fade in needs to be disabled)
    cp a,c                       
    jp nc,check_end$     ; if new_mvol >= old_mvol, no overflow has accured. 

solve_overflow$:
    ; solve overflow (or change nothing if 
    ; mvol was 255), then disable fade in.
    xor a,a ; clear a
    ld (FADE_offset),a
    dec a ; a becomes 255
    jp check_end$