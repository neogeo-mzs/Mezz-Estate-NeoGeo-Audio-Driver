; ======== SFX Playback System ========
; ADPCM-A BASED

SFXPS_init:
    push hl
    push de
    push bc
    push af
        ld hl,SFXPS_WRAM_start
        ld de,SFXPS_WRAM_start+1
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
    push de
        call SFXPS_update_playback_status

		; Reset and mask raised flags
		ld d,REG_P_FLAGS_W
		rst RST_YM_WRITEA

		; Unmask all flags
		ld e,0
		rst RST_YM_WRITEA

        ; DEBUG: If a channel is being used for SFXPS make an SSG noise
        ; SSG CHC note: A4, CHC Tone enabled
        ;ld de,$38 | ($04 << 8)
        ;rst RST_YM_WRITEA
        ;ld de,$02 | ($05 << 8)
        ;rst RST_YM_WRITEA
        ;ld de,%111011 | ($07 << 8)
        ;rst RST_YM_WRITEA

        ;ld de,$00 | ($0A << 8) ; By default CHC has the volume set to 0

        ;ld a,(SFXPS_channel_playback_status)
        ;or a,a ; cp a,0
        ;jr z,skip_debug$

        ;ld e,$0F ; If no sample is playing, this gets skipped

;skip_debug$:
        ;rst RST_YM_WRITEA 
    pop de
    pop af
    ret

; [OUTPUT]
;   e: ADPCM status register flags
; DOES NOT BACKUP AF, DE
SFXPS_update_playback_status:
    ; Read status register flag 
    ; and store it into WRAM
    in a,(6)
    and a,$3F ; Get ADPCM-A flags
    ld e,a    ; backup status register flag in e

    ; SFXPS_channel_playback_status &= ~flags
    xor a,$FF
    ld d,a
    ld a,(SFXPS_channel_playback_status)
    and a,d
    ld (SFXPS_channel_playback_status),a

    ; Clear the priority and sample id in WRAM
    ; of the samples that stopped playing
    push bc
    push hl
    push de
        ld a,e ; load status register flag back in a
        ld c,0 ; C always stays zero throughout this loop
        ld b,SFXPS_CHANNEL_COUNT
        ld hl,SFXPS_channel_priorities+SFXPS_CHANNEL_COUNT-1
        ld de,SFXPS_channel_sample_ids+SFXPS_CHANNEL_COUNT-1

loop$:
        ; If the sample wasn't stopped this frame, skip
        ; WRAM clear code
        bit 5,a
        jr z,continue_loop$

        ld (hl),c
        ex hl,de
        ld (hl),c
        ex hl,de

continue_loop$:
        sla a  ; Shift status register flag
        dec hl ; Next channel priority
        dec de ; Next channel sample id
        djnz loop$
    pop de
    pop hl
    pop bc
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
        jr nc,return$
        
        ; Set the channel's taken status
        ld hl,PA_channel_on_masks
        ld b,0
        add hl,bc
        ld a,(SFXPS_channel_taken_status)
        or a,(hl)
        ld (SFXPS_channel_taken_status),a

        ; Stop the ADPCM channel, then clear its
        ; SFXPS playback flag
        call PA_stop_sample
        ld a,(hl)
        xor a,$FF
        ld b,a
        ld a,(SFXPS_channel_playback_status)
        and a,b 
        ld (SFXPS_channel_playback_status),a
return$:
    pop af
    pop hl
    pop bc
    ret

SFXPS_set_taken_channels_free:
    push af
    push de
        ; Maybe the status register flag gets cleared
		; when resetting, masking and (especially) unmasking the status flags?
		call SFXPS_update_playback_status

        ; Reset and mask newly untaken channels' status flags
        ld a,(SFXPS_channel_taken_status)
        ld d,REG_P_FLAGS_W
        ld e,a
        rst RST_YM_WRITEA

        ; Unmask said channel status flags
        ld e,0
        rst RST_YM_WRITEA

        ; Stop said channels
        or a,%10000000 ; Set dump bit
		ld e,a
		ld d,REG_PA_CTRL
		rst RST_YM_WRITEB

        ; Clear their taken status
        xor a,a
        ld (SFXPS_channel_taken_status),a
    pop de
    pop af
    ret


; [OUTPUT]
;   a: free channel ($FF if none is found)
; Searches from PA6 to PA1
; CHANGES FLAGS!!!
SFXPS_find_free_channel:
    push bc
        ; By ORing the taken status and playback
        ; status byte, you get a byte in which if the
        ; channel's corresponding bit is clear, then
        ; the channel is free
        ld a,(SFXPS_channel_taken_status)
        ld c,a
        ld a,(SFXPS_channel_playback_status)
        or a,c

        ld b,SFXPS_CHANNEL_COUNT
loop$:
        ; if the channel is free (bit 0 is clear)
        ; then return the channel
        bit 5,a
        jr z,free_channel_found$

        sla a ; Shift bitflag to the left
        djnz loop$

        ; Else, return $FF
        ld a,$FF
    pop bc
    ret

free_channel_found$:
        ld a,b
        dec a
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
;   Searches from PA6 to PA1
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
        ld hl,SFXPS_channel_priorities+SFXPS_CHANNEL_COUNT-1
        ld a,(SFXPS_channel_taken_status)
        ld e,a ; Keep a copy of the channel taken status in e
loop$:
        ; If the channel is taken, skip this 
        ; iteration and check the next channel
        bit 5,a
        jr nz,loop_next$

        ; Else, the channel status is busy.
        ; compare the true priorities,
        ; if the priority of the new sample
        ; is higher or equal, return the channel.
        ld a,c
        cp a,(hl) ; if new_priority >= SFXPS_channel_priorities[channel]
        jr nc,busy_channel_found$

loop_next$:
        dec hl ; Index address of next SFXPS ch. priorities
        ld a,e ; Get channel taken status back
        sla a  ; Shift channel taken status bitflag
        ld e,a ; Update channel taken status copy
        djnz loop$

        ; Else, no channel was 
        ; found at all, return $FF
        ld a,$FF
    pop de
    pop hl
    pop bc
    ret

busy_channel_found$:
        ld a,b
        dec a
    pop de
    pop hl
    pop bc
    ret

; [INPUT]
;   c: priority
;   b: sample id
; [OUTPUT]
;   a: channel ($FF if none is found)
; CHANGES FLAGS!!!
;   Searches for a channel currently playing,
;   or that has just played, the specified sample, 
;   if none satisfy this condition, it returns
;   a channel based on its busy status and priority.
;   Searches from PA6 to PA1
SFXPS_find_retrig_channel:
    push hl
    push bc
    push de
        ; Go through all channels and find a busy 
        ; channel playing the specified sample
        ld a,(SFXPS_channel_taken_status)
        ld e,a ; Backup taken status in e
        ld a,b ; Load sample id in a
        ld c,b ; Backup sample id in c
        ld b,SFXPS_CHANNEL_COUNT
        ld hl,SFXPS_channel_sample_ids+SFXPS_CHANNEL_COUNT-1
loop$:
        ; If channel is taken, check next channel
        bit 5,e
        jp nz,loop_next$
        cp a,(hl) ; if smp_id == sample_ids[ch] ...
        jp z,retriggerable_channel_found$ ; then...

loop_next$:
        dec hl
        ld a,e ; load taken status in a
        sla a  ; shift taken status to make the next channel the 5th bit
        ld e,a ; load taken status back in e
        ld a,c ; Load sample id backup in a
        djnz loop$
    pop de
    pop bc
    pop hl

    ; If none are found...
    jp SFXPS_find_suitable_channel

retriggerable_channel_found$:
        ld a,b
        dec a
    pop de
    pop bc
    pop hl
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
        jr z,return$

        ; Store the sample id in WRAM
        ld hl,SFXPS_channel_sample_ids
        ld e,a
        ld d,0
        add hl,de
        ld (hl),b

        ; Set the SFXPS ch. playback status to busy
        ; (SFXPS_channel_playback_status |= PA_channel_on_masks[ch])
        ld hl,PA_channel_on_masks
        add hl,de
        ld a,(SFXPS_channel_playback_status)
        or a,(hl)
        ld (SFXPS_channel_playback_status),a

        ; Store the new priority in WRAM
        ld hl,SFXPS_channel_priorities
        add hl,de
        ld (hl),c

        ; Index SFX ADPCM-A list
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

        ; Set ADPCM-A sample addresses
        push hl ; - ix = hl
        pop ix  ; /
        ld a,e ; Load channel in a
        call PA_set_sample_addr

        ; Set CVOL register
        ld a,REG_PA_CVOL
        add a,e
        ld d,a
        ld e,iyl
        rst RST_YM_WRITEB

        ; Play the sample (and deal with status flags)
        sub a,REG_PA_CVOL ; Get channel back
        ld e,a
        call PA_play_sample
        
return$:
    pop ix
    pop de
    pop hl
    pop bc
    pop af
    ret

; c:   priority
; b:   sample id
; iyl: CVOL (%PP-VVVVV; Panning, Volume)
SFXPS_retrigger_sfx:
    push af
    push bc
    push hl
    push de
    push ix
        call SFXPS_find_retrig_channel
        cp a,$FF
        jr z,return$

        ; Store the sample id in WRAM
        ld hl,SFXPS_channel_sample_ids
        ld e,a
        ld d,0
        add hl,de
        ld (hl),b

        ; Set the SFXPS ch. playback status to busy
        ; (SFXPS_channel_playback_status |= PA_channel_on_masks[ch])
        ld hl,PA_channel_on_masks
        add hl,de
        ld a,(SFXPS_channel_playback_status)
        or a,(hl)
        ld (SFXPS_channel_playback_status),a

        ; Store the new priority in WRAM
        ld hl,SFXPS_channel_priorities
        add hl,de
        ld (hl),c

        ; Index SFX ADPCM-A list
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

        ; Set ADPCM-A sample addresses
        push hl ; - ix = hl
        pop ix  ; /
        ld a,e ; Load channel in a
        call PA_set_sample_addr

        ; Set CVOL register
        ld a,REG_PA_CVOL
        add a,e
        ld d,a
        ld e,iyl
        rst RST_YM_WRITEB

        ; Play the sample (and deal with status flags)
        sub a,REG_PA_CVOL ; Get channel back
        ld e,a
        call PA_retrigger_sample
        
return$:
    pop ix
    pop de
    pop hl
    pop bc
    pop af
    ret