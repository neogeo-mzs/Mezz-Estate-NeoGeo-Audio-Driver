;==============================================================================;
; write45
; Writes data from the de register to ports 4 and 5.

write45:
	; save the previous value of af
	push af

	; the value in d is the address
	ld   a,d
	out  (YM2610_A0),a
	rst  RST_YM_WAIT ; wait for YM2610 to be free

	; the value in e is the data to write
	ld   a,e
	out  (YM2610_A1),a
	rst  RST_YM_WAIT ; wait for YM2610 to be free

	; restore the value of af
	pop  af
	ret

;------------------------------------------------------------------------------;
; write67
; Writes data from the de register to ports 6 and 7.

write67:
	; save the previous value of af
	push af

	; the value in d is the address
	ld   a,d
	out  (YM2610_B0),a
	rst  RST_YM_WAIT ; wait for YM2610 to be free

	; the value in e is the data to write
	ld   a,e
	out  (YM2610_B1),a
	rst  RST_YM_WAIT ; wait for YM2610 to be free

	; restore the value of af
	pop  af
	ret


;==============================================================================;
; SetDefaultBanks
; Sets the default program banks.
; This setup treats the M1 ROM as linear space. (no bankswitching needed)

SetDefaultBanks:
	; Set $F000-$F7FF bank to bank $1E (30 *  2K)
	ld   a,0x1E
	in   a,(8)

	; Set $E000-$EFFF bank to bank $0E (14 *  4K)
	ld   a,0x0E
	in   a,(9)

	; Set $C000-$DFFF bank to bank $06 ( 6 *  8K)
	ld   a,0x06
	in   a,(0xA)

	; Set $8000-$BFFF bank to bank $02 ( 2 * 16K)
	ld   a,0x02
	in   a,(0xB)
	ret

;==============================================================================;
; fm_Stop
; Stops playback on all FM channels.

fm_Stop:
	di
	push af
	ld   a,0x28 ; Slot and Key On/Off
	out  (4),a ; write to port 4 (address 1)
	rst  8 ; wait for YM2610 to be free
	;---------------------------------------------------;
	ld   a,0x01 ; FM Channel 1
	out  (5),a ; write to port 5 (data 1)
	rst  8 ; wait for YM2610 to be free
	;---------------------------------------------------;
	ld   a,0x02 ; FM Channel 2
	out  (5),a ; write to port 5 (data 1)
	rst  8 ; wait for YM2610 to be free
	;---------------------------------------------------;
	ld   a,0x05 ; FM Channel 3
	out  (5),a ; write to port 5 (data 1)
	rst  8 ; wait for YM2610 to be free
	;---------------------------------------------------;
	ld   a,0x06 ; FM Channel 4
	out  (5),a ; write to port 5 (data 1)
	rst  8 ; wait for YM2610 to be free
	pop  af
	ret

;==============================================================================;
; ssg_Stop
; Silences all SSG channels.

ssg_Stop:
	ld   de,0x0800 ; SSG Channel A Volume/Mode
	call write45   ; write to ports 4 and 5
	;-------------------------------------------------;
	ld   de,0x0900 ; SSG Channel B Volume/Mode
	call write45   ; write to ports 4 and 5
	;-------------------------------------------------;
	ld   de,0x0A00 ; SSG Channel C Volume/Mode
	call write45   ; write to ports 4 and 5
	ret

;==============================================================================;
; pcma_Stop
; Stops all ADPCM-A channels.

pcma_Stop:
	di
	ld   de,0x009F ; $009F Dump all ADPCM-A channels (stop sound)
	call write67
	ret

;==============================================================================;
; pcmb_Stop
; Stops the ADPCM-B channel.

pcmb_Stop:
	di
	ld   de,0x1001 ; $1001 Force stop synthesis
	call write45
	dec  e ; $1000 Stop ADPCM-B output
	call write45
	ret



;======================================================
; Other stuff, mainly to interface with i/o

YM_reg_wait:
	push af
.YM_reg_wait_loop:
		in a,(YM2610_A0) ; get status
		bit 7,a          ; is the FM chip still busy?
		jr nz,.YM_reg_wait_loop
	pop af
	ret