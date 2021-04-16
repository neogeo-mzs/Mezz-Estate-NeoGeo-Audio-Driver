; wpset F800,1,w,wpdata==39

	include "def.inc"

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
	call PA_reset
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
		; Set $F000-$F7FF bank to bank $16 (22 *  2K; $B000~$B7FF)
		ld a,&16
		in a,(&08)
		; Set $E000-$EFFF bank to bank $0A (10 *  4K; $A000~$AFFF)
		ld a,&0A
		in a,(&09)
		; Set $C000-$DFFF bank to bank $04 ( 4 *  8K; $8000~$9FFF)
		ld a,&04
		in a,(&0A)
		; Set $8000-$BFFF bank to bank $01 ( 1 * 16K; $4000~$7FFF)
		ld a,&01
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

	org &4000 ; block 1
MLM_header:
	db 9 ; Song count
	dw MLM_song_pa1-MLM_header
	dw MLM_song_pa2-MLM_header
	dw MLM_song_pa3-MLM_header
	dw MLM_song_pa4-MLM_header
	dw MLM_song_pa5-MLM_header
	dw MLM_song_pa6-MLM_header
	dw MLM_song_ssg1-MLM_header
	dw MLM_song_ssg2-MLM_header
	dw MLM_song_ssg3-MLM_header

MLM_song_pa1:
	dw MLM_el_pa-MLM_header
	dsw 12, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_song_pa2
	dw 0
	dw MLM_el_pa-MLM_header
	dsw 11, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_song_pa3:
	dsw 2,0
	dw MLM_el_pa-MLM_header
	dsw 10, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_song_pa4:
	dsw 3,0
	dw MLM_el_pa-MLM_header
	dsw 9, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_song_pa5:
	dsw 4,0
	dw MLM_el_pa-MLM_header
	dsw 8, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_song_pa6:
	dsw 5,0
	dw MLM_el_pa-MLM_header
	dsw 7, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_el_pa: ; Start in Zone 3
	db &80 | 60, 0 ; Play ADPCM-A sample 0 (C)
	db &80 | 60, 2 ; Play ADPCM-A sample 2 (D)
	db &00 ; End of song

MLM_song_ssg1:
	dsw 10,0
	dw MLM_el_ssg-MLM_header
	dsw 2, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_song_ssg2:
	dsw 11,0
	dw MLM_el_ssg-MLM_header
	dw 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_song_ssg3:
	dsw 12,0
	dw MLM_el_ssg-MLM_header
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_el_ssg:
	db &76 ; Invalid command
	db &80 | 60,4*12 + 0 ; Play SSG note C4
	db &80 | 60,4*12 + 2 ; Play SSG note D4
	db &00 ; End of song

	; Instruments
	org &8000

	; Instrument 0 (ADPCM-A)
	dw &E000 ; Point to ADPCM-A sample LUT (in Zone 1)
	dsb 30,0 ; padding

	; Other data
	org &A000
	incbin "adpcma_sample_lut.bin"

	include "wram.s"