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
    brk
    push af
    push hl
    push bc
    push de
        ld b,FM_CHANNEL_COUNT
        ld hl,SFXPS_channel_statuses+FM_CHANNEL_COUNT-1
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
SFXPS_set_channel_as_taken:
    push bc
    push hl
        ld hl,SFXPS_channel_statuses
        ld b,0
        add hl,bc
        ld (hl),SFXPS_CH_TAKEN
    pop hl
    pop bc
    ret

; c:   channel
; e:   priority
; d:   sample id
; iyl: CVOL (%PP-VVVVV; Panning, Volume)
SFXPS_play_sfx:
    push hl
    push af
    push bc
    push de
    push ix
        ; Check if the channel status:
        ;   If it's taken, return
        ld hl,SFXPS_channel_statuses
        ld b,0
        add hl,bc
        ld a,SFXPS_CH_TAKEN
        cp a,(hl)                ; if SFXPS_CH_TAKEN == SFXPS_channel_statuses[ch]
        jr z,SFXPS_play_sfx_ret  ; then ...

        ;   If it's free (not busy), skip the priority check
        dec a
        cp a,(hl)                            ; if SFXPS_CH_BUSY != SFXPS_channel_statuses[ch]
        jr nz,SFXPS_play_sfx_skip_prio_check ; then ...

        ; Else (channel is busy), check the priority
        ;   Load priority of currently playing sample in e
        ld hl,SFXPS_channel_priorities
        add hl,bc
        ld a,e ; Move new sample priority in a
        ld e,(hl)

        ;   If the priority of the currently playing sample is 
        ;   higher than the priority of the new sample, return
        cp a,e                  ; if new_smp_priority < SFXPS_channel_priorities[ch]
        jr c,SFXPS_play_sfx_ret ; then ...
SFXPS_play_sfx_skip_prio_check:
        ld b,d ; backup sample id in b
        
        ; All the sfx playback conditions have been met, play the sample
        ;   Index SFX ADPCM-A list
        ld h,0    ; \
        ld l,d    ; | ofs = new_smp_id
        add hl,hl ; | ofs *= 4
        add hl,hl ; /
        ld a,(SFXPS_adpcma_table)
        ld e,a
        ld a,(SFXPS_adpcma_table+1)
        ld d,a
        add hl,de

        ;   Set ADPCM-A sample addresses
        push hl ; - ix = hl
        pop ix  ; /
        ld a,c  ; Load channel in a
        call PA_set_sample_addr

        ;   Set CVOL register
        ld d,REG_PA_CVOL
        add a,d
        ld e,iyl
        rst RST_YM_WRITEB

        ;   Play the sample
        ld e,c
        call PA_play_sample

        ; Set the SFXPS status flag to SFXPS_CH_BUSY
        ld hl,SFXPS_channel_priorities
        ld b,0
        add hl,bc
        ld (hl),SFXPS_CH_BUSY
SFXPS_play_sfx_ret:
    pop ix
    pop de
    pop bc
    pop af 
    pop hl
    ret