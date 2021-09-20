; ======== SFX Playback System ========
; ADPCM-A BASED

SFXPS_init:
    push hl
    push de
    push bc
    push af
        ld hl,SFXPS_WRAM_start
        ld de,SFXPS_WRAM_end+1
        ld bc,SFXPS_WRAM_end-SFXPS_WRAM_start-1
        ldir

        ; Load SFX ADPCM-A table ofs in hl,
        ; and calculate the actual address
        ld a,(MLM_HEADER)
        ld l,a
        ld a,(MLM_HEADER+1)
        ld h,a
        ld de,MLM_HEADER
        add hl,de
        inc hl ; Skips sample count, TODO: Add sample id check

        ; Store said address in SFXPS_adpcma_table
        ld a,l
        ld (SFXPS_adpcma_table),a
        ld a,h
        ld (SFXPS_adpcma_table+1),a
    pop af
    pop bc
    pop de
    pop hl
    ret

; Ran in the main loop, not the IRQ
SFXPS_update:
    push af
    push hl
    push bc
    push de
        ld b,SFXPS_CHANNEL_COUNT
        ld hl,SFXPS_channel_statuses+SFXPS_CHANNEL_COUNT-1
SFXPS_update_loop:
        ; If the SFXPS channel status isn't SFXPS_CH_BUSY,
        ; then skip status flag check.
        ld a,(hl)
        dec hl
        cp a,SFXPS_CH_BUSY
        jr nz,SFXPS_update_loop_skip_statf_check

        ; Load the ADPCM channel status flag in a,
        ; and mask away any other channel status flags
        ld a,REG_P_FLAGS_R
        rst RST_YM_READA
        ld de,PA_channel_neg_masks-SFXPS_channel_statuses
        add hl,de
        and a,(hl)
        or a,a     ; Clear carry flag
        sbc hl,de  ; Get back SFXPS_channel_statuses[channel]

        ; If a is 0, then don't set anything
        or a,a ; cp a,0
        jr z,SFXPS_update_loop_skip_statf_check

        ; Else, the sample has stopped playing;
        ; proceed to set the SFXPS ch. status to
        ; SFXPS_CH_FREE and reset the reg. flags
        ld (hl),SFXPS_CH_FREE
        ld e,b
        dec e
        call PA_channel_status_reset
SFXPS_update_loop_skip_statf_check:
        dec hl ; Get address of precedent ch. SFXPS status ready
        djnz SFXPS_update_loop
    pop de
    pop bc
    pop hl
    pop af
    ret
    
; c: channel
;   An invalid SFXPS channel can be used,
;   the function will just do nothing
SFXPS_set_channel_as_taken:
    push bc
    push hl
    push af
        ; If channel isn't a valid SFXPS
        ; channel, just return
        ld a,c
        cp a,SFXPS_CHANNEL_COUNT
        jr nc,SFXPS_set_channel_as_taken_ret
        
        ld hl,SFXPS_channel_statuses
        ld b,0
        add hl,bc
        ld (hl),SFXPS_CH_TAKEN

SFXPS_set_channel_as_taken_ret:
    pop af
    pop hl
    pop bc
    ret

SFXPS_set_taken_channels_free:
    push bc
    push hl
    push af
        ld b,SFXPS_CHANNEL_COUNT
        ld hl,SFXPS_channel_statuses+SFXPS_CHANNEL_COUNT-1
SFXPS_set_taken_channels_free_loop:
        ; If the channel status 
        ; isn't taken, check the
        ; next channel
        
        ld a,(hl)
        dec hl    ; Get pointer to precedent channel's status
        cp a,SFXPS_CH_TAKEN
        jr nz,SFXPS_set_taken_channel_free_next

        ; Else, set the SFXPS ch.
        ; status to free
        ld (hl),SFXPS_CH_FREE
SFXPS_set_taken_channel_free_next:
        djnz SFXPS_set_taken_channels_free_loop
    pop af
    pop hl
    pop bc
    ret


; [OUTPUT]
;   a: free channel ($FF if none is found)
; CHANGES FLAGS!!!
SFXPS_find_free_channel:
    push bc
    push hl
        ld b,SFXPS_CHANNEL_COUNT
        ld hl,SFXPS_channel_statuses+SFXPS_CHANNEL_COUNT-1
        xor a,a ; ld a,SFXPS_CH_FREE
SFXPS_find_free_channel_loop:
        ; if the channel is free ($00),
        ; return the channel
        cp a,(hl) 
        jr z,SFXPS_find_free_channel_fchfound

        dec hl ; Index address of precedent SFXPS ch. status
        djnz SFXPS_find_free_channel_loop

        ; Else, return $FF
        ld a,$FF
    pop hl
    pop bc
    ret

SFXPS_find_free_channel_fchfound:
        ld a,b
        dec a
    pop hl
    pop bc
    ret

; [INPUT]
;   c: priority
; [OUTPUT]
;   a: channel ($FF if none is found)
; CHANGES FLAGS!!!
;   First searches for a free channel,
;   if none is available, it goes through
;   the busy channels and checks their priority.
SFXPS_find_suitable_channel:
    ; If a free channel is found, return it
    call SFXPS_find_free_channel
    cp a,$FF
    ret nz

    ; Else, search through the busy channels
    ; and based on their priorities, choose
    ; a channel. If none is found, return $FF
    push bc
    push hl
    push de
        ld b,SFXPS_CHANNEL_COUNT
        ld hl,SFXPS_channel_statuses+SFXPS_CHANNEL_COUNT-1
        ld de,SFXPS_channel_priorities-SFXPS_channel_statuses
SFXPS_find_suitable_channel_loop:
        ; If the channel status isn't busy,
        ; then it must be taken, skip
        ; the priority check altogether
        ld a,(hl)
        dec a     ; cp a,SFXPS_BUSY
        jr nz,SFXPS_find_suitable_channel_loop_next

        ; Else, the channel status is busy.
        ; compare the true priorities,
        ; if the priority of the new sample
        ; is higher or equal, return the channel.
        add hl,de ; Get SFXPX_channel_priorities[ch]
        ld a,c
        cp a,(hl) ; if new_priority >= SFXPS_channel_priorities[channel]
        jr nc,SFXPS_find_suitable_channel_loop_bch_found

        or a,a    ; Clear carry flag
        sbc hl,de ; Get SFXPS_channel_statuses[ch]
SFXPS_find_suitable_channel_loop_next:
        dec hl ; Index address of precedent SFXPS ch. status
        djnz SFXPS_find_suitable_channel_loop

        ; Else, no channel was 
        ; found at all, return $FF
        ld a,$FF
    pop de
    pop hl
    pop bc
    ret

SFXPS_find_suitable_channel_loop_bch_found:
        ld a,b
        dec a
    pop de
    pop hl
    pop bc
    ret

; c:   priority
; b:   sample id
; iyl: CVOL (%PP-VVVVV; Panning, Volume)
SFXPS_play_sfx:
    push af
    push bc
    push hl
    push de
    push ix
        ; Find a suitable channel, if
        ; none is found return.
        call SFXPS_find_suitable_channel
        cp a,$FF
        jr z,SFXPS_play_sfx_ret

        ; Else, there's a channel the 
        ; sample can be played in.
        ;   Set the SFXPS ch. status to busy
        ld hl,SFXPS_channel_statuses
        ld e,a
        ld d,0
        add hl,de
        ld (hl),SFXPS_CH_BUSY

        ;   Store the new priority in WRAM
        ld hl,SFXPS_channel_priorities
        add hl,de
        ld (hl),c

        ;   Index SFX ADPCM-A list
        ld h,0    ; \
        ld l,b    ; | ofs = new_smp_id
        add hl,hl ; | ofs *= 4
        add hl,hl ; /
        push de
            ld a,(SFXPS_adpcma_table)
            ld e,a
            ld a,(SFXPS_adpcma_table+1)
            ld d,a
            add hl,de
        pop de

        ;   Set ADPCM-A sample addresses
        push hl ; - ix = hl
        pop ix  ; /
        ld a,e ; Load channel in a
        call PA_set_sample_addr

        ;   Set CVOL register
        ld a,REG_PA_CVOL
        add a,e
        ld d,a
        ld e,iyl
        rst RST_YM_WRITEB

        ;   Play the sample
        sub a,REG_PA_CVOL ; Get channel back
        ld e,a
        call PA_play_sample
        
SFXPS_play_sfx_ret:
    pop ix
    pop de
    pop hl
    pop bc
    pop af
    ret