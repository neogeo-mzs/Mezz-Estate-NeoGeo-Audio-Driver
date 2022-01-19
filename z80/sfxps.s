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

		; Reset and mask raised flags
		ld d,REG_P_FLAGS_W
		rst RST_YM_WRITEA

		; Unmask all flags
		ld e,0
		rst RST_YM_WRITEA
    pop de
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
        
        ld hl,PA_channel_on_masks
        ld b,0
        add hl,bc
        ld a,(SFXPS_channel_taken_status)
        or a,(hl)
        ld (SFXPS_channel_taken_status),a
SFXPS_set_channel_as_taken_ret:
    pop af
    pop hl
    pop bc
    ret

SFXPS_set_taken_channels_free:
    push af
        xor a,a
        ld (SFXPS_channel_taken_status),a
    pop af
    ret


; [OUTPUT]
;   a: free channel ($FF if none is found)
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
SFXPS_find_free_channel_loop:
        ; if the channel is free (bit 0 is clear)
        ; then return the channel
        bit 0,a
        jr z,SFXPS_find_free_channel_fchfound

        srl a ; Shift bitflag to the right
        djnz SFXPS_find_free_channel_loop

        ; Else, return $FF
        ld a,$FF
    pop bc
    ret

SFXPS_find_free_channel_fchfound:
        ld a,SFXPS_CHANNEL_COUNT
        sub a,b
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
        ld hl,SFXPS_channel_priorities
        ld a,(SFXPS_channel_taken_status)
        ld e,a ; Keep a copy of the channel taken status in e
SFXPS_find_suitable_channel_loop:
        ; If the channel is taken, skip this 
        ; iteration and check the next channel
        bit 0,a
        jr nz,SFXPS_find_suitable_channel_loop_next

        ; Else, the channel status is busy.
        ; compare the true priorities,
        ; if the priority of the new sample
        ; is higher or equal, return the channel.
        ld a,c
        cp a,(hl) ; if new_priority >= SFXPS_channel_priorities[channel]
        jr nc,SFXPS_find_suitable_channel_loop_bch_found

SFXPS_find_suitable_channel_loop_next:
        inc hl ; Index address of next SFXPS ch. priorities
        ld a,e ; Get channel taken status back
        srl a  ; Shift channel taken status bitflag
        ld e,a ; Update channel taken status copy
        djnz SFXPS_find_suitable_channel_loop

        ; Else, no channel was 
        ; found at all, return $FF
        ld a,$FF
    pop de
    pop hl
    pop bc
    ret

SFXPS_find_suitable_channel_loop_bch_found:
        ld a,SFXPS_CHANNEL_COUNT
        sub a,b
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
        ;   Set the SFXPS ch. playback status to busy
        ;   (SFXPS_channel_playback_status |= PA_channel_on_masks[ch])
        ld hl,PA_channel_on_masks
        ld e,a
        ld d,0
        add hl,de
        ld a,(SFXPS_channel_playback_status)
        or a,(hl)
        ld (SFXPS_channel_playback_status),a

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

        ;   Play the sample (and deal with status flags)
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