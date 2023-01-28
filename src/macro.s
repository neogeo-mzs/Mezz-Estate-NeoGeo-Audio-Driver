; [INPUT]
; 	ix: pointer to macro
; [OUTPUT]
;	a:  Current macro value
; CHANGES FLAGS!!
BMACRO_read:
	push hl
	push de
		; a = macro.data[macro.curr_pt]
		ld l,(ix+ControlMacro.data)
		ld h,(ix+ControlMacro.data+1)
		ld e,(ix+ControlMacro.curr_pt)
		ld d,0
		add hl,de
		ld a,(hl)
	pop de
	pop hl
	ret

; [INPUT]
; 	ix: pointer to macro
; [OUTPUT]
;	a:  Current macro value
; CHANGES FLAGS!!
NMACRO_read:
	push hl
	push de
		; Load byte containing the value
		; by adding to the macro data 
		; pointer curr_pt divided by two
		ld l,(ix+ControlMacro.data)
		ld h,(ix+ControlMacro.data+1)
		ld a,(ix+ControlMacro.curr_pt)
		srl a
		ld e,a ; e = macro.curr_pt / 2
		ld d,0
		add hl,de
		ld a,(hl)

		; If macro.curr_pt is even, then
		; return the least significant nibble,
		; else return the most significant one.
		bit 0,(ix+ControlMacro.curr_pt)
		jr z,even_point$

		srl a ; \
		srl a ;  | a >>= 4
		srl a ;  | (VVVV---- => 0000VVVV)
		srl a ; /

even_point$:
		and a,$0F
	pop de
	pop hl
	ret

; ix: pointer to macro
MACRO_update:
	push af
		; If macro.loop_pt is bigger or equal 
		; than the actual length, set it to
		; the length minus 1 (remember that
		; the length is always stored 
		; decremented by one)
		ld a,(ix+ControlMacro.length)
		cp a,(ix+ControlMacro.loop_pt)
		jr nc,valid_loop_point$ ; if macro.length >= macro.loop_pt ...

		ld (ix+ControlMacro.loop_pt),a ; macro.loop_pt = macro.length (length is stored decremented by 1)

valid_loop_point$:
		; increment macro.curr_pt, if it
		; overflows set it to macro.loop_pt
		inc (ix+ControlMacro.curr_pt)
		cp a,(ix+ControlMacro.curr_pt)
		jr nc,return$ ; if macro.length >= macro.curr_pt

		ld a,(ix+ControlMacro.loop_pt)
		ld (ix+ControlMacro.curr_pt),a

return$:
	pop af
	ret

; ix: pointer to macro
; hl: pointer to macro initialization data
;    if hl is equal to MLM_HEADER, 
;    the macro will NOT be set
MACRO_set:
	push af
	push hl
	push de
		; Disable macro, if needed it'll be 
		; enabled later in the function
		ld (ix+ControlMacro.enable),$00

		; If the address to the macro initialization data is
		; equal to MLM_HEADER, then return from the subroutine
		;   if address is equal to offset + MLM_HEADER; then
		;   when the offset will be 0 the address will be MLM_HEADER
		push hl
		ld de,MLM_HEADER
		or a,a    ; Clear carry flag
		sbc hl,de ; cp hl,de
		pop hl
		jr z,return$

		; Set macro's length
		ld a,(hl)
		ld (ix+ControlMacro.length),a

		; Set macro's loop point
		inc hl
		ld a,(hl)
		ld (ix+ControlMacro.loop_pt),a

		; Set macro's data pointer
		inc hl
		ld (ix+ControlMacro.data),l
		ld (ix+ControlMacro.data+1),h

		; Set other variables
		ld (ix+ControlMacro.enable),$FF ; Enable macro again
		ld (ix+ControlMacro.curr_pt),0
return$:
	pop de
	pop hl
	pop af
	ret