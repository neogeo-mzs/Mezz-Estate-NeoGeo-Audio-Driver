; wpset F800,1,w,wpdata==39

	include "def.inc"

INSTRUMENTS equ 0
ADPCMA_SMPS equ 0
MLM_START   equ BANK3+&2000

j_startup:
	di
	jp startup

	org &0008
j_port_write_delay1:
	jp port_write_delay1

	org &0010
j_port_write_delay2:
	jp port_write_delay2

	org &0018
j_port_write_a:
	jp port_write_a

	org &0020
j_port_write_b:
	jp port_write_b

	org &0038
j_IRQ:
	di
	jp IRQ

	ascii "MZS Deflemask VGM driver by GbaCretin"

	org &0066
NMI:
	push af
	push bc
	push de
	push hl
	push ix
	push iy
		in a,(READ_68K)

		or a,a ; cp a,&00
		jr z,NMI_do_nothing
		cp a,&01
		jp z,BCOM_prepare_switch
		cp a,&03
		jp z,BCOM_reset
		
		bit 7,a
		call nz,UCOM_write2buffer

		xor a,&FF
		;ld a,(tmp)
		out (WRITE_68K),a    ; reply to 68k
		out (READ_68K),a     ; clear sound code

NMI_do_nothing:
	pop iy
	pop ix
	pop hl
	pop de
	pop bc
	pop af
	retn

startup:
	ld sp,&FFFC
	im 1

	; Clear WRAM
	ld hl,WRAM_START
	ld de,WRAM_START+1
	ld bc,WRAM_END-WRAM_START-1
	ld (hl),0
	ldir

	; Silence YM2610
	call fm_stop
	call pa_stop
	call pb_stop
	call ssg_stop

	; Useless devkit port write (probably?)
	ld a,1
	out (&C0),a

	ld hl,98
	call ta_counter_load_set
	ld de,(REG_TIMER_CNT<<8) | %10101
	rst RST_YM_WRITEA
	
	call set_default_banks

	out (ENABLE_NMI),a

main_loop:
	ei
	call UCOM_handle_command
	jr main_loop

fast_beep:
	push de
		ld de, 0040h	        ;Channel 1 frequency: 2kHz
		rst RST_YM_WRITEA
		ld de, 0100h
		rst RST_YM_WRITEA

		ld de, (REG_SSG_VOL_ENV<<8) | &0F		;EG period: $50F
		rst RST_YM_WRITEA
		ld de, (REG_SSG_COARSE_ENV<<8) | &05 
		rst RST_YM_WRITEA

		ld de, (REG_SSG_CHA_VOL<<8) | &10		;Channel's 1 amplitude is tied to the EG
		rst RST_YM_WRITEA
		ld de, (REG_SSG_VOL_ENV_SHAPE<<8) | &08		;EG shape: Repetitive ramp down
		rst RST_YM_WRITEA
		ld de, (REG_SSG_MIX_ENABLE<<8) | &0E		;All channels except 1 are off
		rst RST_YM_WRITEA
	pop de
	ret

play_sample:
	push de
		ld de,(REG_PA_MVOL<<8) | &3F
		rst RST_YM_WRITEB
		ld de,(REG_PA_CVOL<<8) | %11000000 | &1F
		rst RST_YM_WRITEB
		ld de,(REG_PA_STARTL<<8) | &00
		rst RST_YM_WRITEB
		ld de,(REG_PA_STARTH<<8) | &00
		rst RST_YM_WRITEB
		ld de,(REG_PA_ENDL<<8) | &40
		rst RST_YM_WRITEB
		ld de,(REG_PA_ENDH<<8) | &00
		rst RST_YM_WRITEB
		ld de,(REG_PA_CTRL<<8) | 1
		rst RST_YM_WRITEB
	pop de
	ret

set_default_banks:
	push af
		; Set $F000-$F7FF bank to bank $1E (30 *  2K)
		ld a,&1E
		in a,(&08)
		; Set $E000-$EFFF bank to bank $0E (14 *  4K)
		ld a,&0E
		in a,(&09)
		; Set $C000-$DFFF bank to bank $02 ( 2 *  8K)
		ld a,&02
		in a,(&0A)
		; Set $8000-$BFFF bank to bank $00 ( 0 * 16K)
		ld a,&00
		in a,(&0B)
	pop af
	ret

; Plays a noisy beep on the SSG channel C
; and then enters an infinite loop
softlock:
	call ssg_stop

	ld d,REG_SSG_CHC_FINE_TUNE
	ld e,&FF
	rst RST_YM_WRITEA

	ld d,REG_SSG_CHC_COARSE_TUNE
	ld e,&05
	rst RST_YM_WRITEA

	ld d,REG_SSG_CHN_NOISE_TUNE
	ld e,&08
	rst RST_YM_WRITEA

	ld d,REG_SSG_CHN_NOISE_TUNE
	ld e,&08
	rst RST_YM_WRITEA

	ld d,REG_SSG_MIX_ENABLE
	ld e,%11011011
	rst RST_YM_WRITEA

	ld d,REG_SSG_CHC_VOL
	ld e,&0A
	rst RST_YM_WRITEA

	jp $

	include "rst.s"
	include "com.s"
	include "ssg.s"
	include "adpcm.s"
	include "fm.s"
	include "timer.s"
	include "mlm.s"
	include "math.s"
	include "irq.s"

	org &2000 ; block 1
MLM_header:
	dw MLM_song_0-MLM_header

MLM_song_0:
	dw MLM_el_pa-MLM_header
	dsw 12, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_el_pa: ; Start in Zone 3
	; YM2610 4 port a writes
	db &32, &00,&38       ; Set CHA fine tune
	db      &01,&02       ; Set CHA coarse tune
	db      &07,%00111110 ; Set CHA mixing
	db      &08,10        ; SSG CHA volume
	db &03,60             ; wait 1 second
	;db &22, &00, &00, &03 ; bankswitch current zone to bank 3, then flip zones and jump to address $000

	; YM2610 2 port a writes
	db &30,&00,&38 ; Set CHA fine tune
	db     &01,&03 ; Set CHA coarse tune
	db &03,60

	; YM2610 2 port a writes
	db &30,&00,&38 ; Set CHA fine tune
	db     &01,&04 ; Set CHA coarse tune
	db &03,60

	db &21, (MLM_el_pa - &2000) & &FF, (MLM_el_pa - &2000) >> 8 ; Jump in current zone

	;db &22, &00, &00, &02 ; bankswitch current zone to bank 3, then flip zones and jump to address $000

	org &6000 ; block 3

	; YM2610 2 port a writes
	db &30,&00,&38 ; Set CHA fine tune
	db     &01,&05 ; Set CHA coarse tune
	db &03,60

	db &22,&07,&00, &03 ; bankswitch current zone to bank 4, then flip zones and jump to address $009 (MLM_el_pa_loop)
	
	include "wram.s"
