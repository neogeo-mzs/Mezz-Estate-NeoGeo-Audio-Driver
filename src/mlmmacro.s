; a:  index
; c:  channel
; hl: pointer to mlm macro initialization data
;
; Crashes if said macro index is already busy or
; if the index is out of the valid range
; (0~MLM_MACRO_COUNT-1)
; DOESN'T BACKUP IX, IY, DE and AF
MLMMACRO_start_macro:
    ; Checks if the index is in a valid range
    ld e,MLM_MACRO_COUNT
    cp a,e         ; if index >= MLM_MACRO_COUNT...
    jp nc,softlock ; ...then crash

    ; Calculates pointer to indexed macro,
    ; and checks if it's already busy.
    ld iy,MLM_macros
    rla       ; \
    rla       ;  \
    rla       ;  | a *= 16
    rla       ;  /
    and a,$F0 ; /
    ld e,a
    ld d,0
    add iy,de
    bit MLM_MACRO_ENABLE_BIT,(iy+MLM_Macro.flags)
    jp nz,softlock

    ; Initializes MLM macro's parameters
    ld a,MLM_MACRO_ENABLE
    ld (iy+MLM_Macro.flags),a
    ld (iy+MLM_Macro.channel),c
    ld a,(hl)
    ld (iy+MLM_Macro.command),a
    inc hl
    ld a,(hl)
    ld (iy+MLM_Macro.delay),a
    ld (iy+MLM_Macro.delay_counter),a
    
    ; Initializes the ControlMacro
    push iy
    pop ix
    ld de,MLM_Macro.macro
    add ix,de ; Points IX to MLM_Macro.macro
    inc hl    ; Points HL to the ControlMacro init. data
    call MACRO_set
    ret

; DOESN'T BACKUP AF, BC, DE, IX and IY
MLMMACRO_update_all:
macro_idx set 0
    dup MLM_MACRO_COUNT
        ld ix,MLM_macros+(macro_idx*MLM_Macro.SIZE)
        bit MLM_MACRO_ENABLE_BIT,(ix+MLM_Macro.flags)
        jr z, $+2+74

        ; This block of code is 74 bytes long
            ; Checks if the delay counter is 0,
            ; if it is execute the macro command
            ; and reset the delay counter,
            ; if not, decrease the delay counter by one.
            ; (The delay counter gets decreased in any scenario, 
            ; but it gets overwritten afterwards if needed)
            ld a,(ix+MLM_Macro.delay_counter)
            dec (ix+MLM_Macro.delay_counter) 
            or a,a ; cp a,0
            jr nz,$+2+62

            ; This block of code is 62 bytes long
                ld a,(ix+MLM_Macro.delay)
                ld (ix+MLM_Macro.delay_counter),a

                ld a,(ix+MLM_Macro.channel)
                rla       ; \
                rla       ;  \
                rla       ;  | a *= 16
                rla       ;  /
                and a,$F0 ; /
                ld e,a 
                ld d,0
                ld iy,MLM_channels
                add iy,de

                ld a,(ix+MLM_Macro.channel)
                ld c,a
                ld a,(ix+MLM_Macro.command)
                ld (MLM_macro_command_buffer+0),a

                ld ix,MLM_macros+(macro_idx*MLM_Macro.SIZE)+MLM_Macro.macro
                call BMACRO_read
                ld (MLM_macro_command_buffer+1),a
                call MACRO_update

                ld hl,MLM_macro_command_buffer
                ld e,(iy+MLM_Channel.playback_ptr+0)
                ld d,(iy+MLM_Channel.playback_ptr+1)
                    call MLM_parse_command
                ld (iy+MLM_Channel.playback_ptr+0),e
                ld (iy+MLM_Channel.playback_ptr+1),d
            ; End of 62 bytes long code
        ; End of 74 bytes long code

macro_idx set macro_idx+1
    edup 
    ret