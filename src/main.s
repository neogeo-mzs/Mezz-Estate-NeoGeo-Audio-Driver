; wpset F800,1,w,wpdata==39
; wpset F800,1,w,wpdata==3A && bc == 0201
; trace fm1_regrec.tr,1
; wpset F800,1,w,wpdata==3A,{tracelog "A addr: 0x%02X; data: 0x%02X\n", d, e; go}
; wpset F800,1,w,wpdata==3B,{tracelog "B addr: 0x%02X; data: 0x%02X\n", d, e; go}
; wpset F800,1,w,wpdata==3C,{tracelog "WA addr: 0x%02X;", a; go}
; wpset F800,1,w,wpdata==3D,{tracelog " data: 0x%02X\n", a; go}
; wpset F800,1,w,wpdata==3E,{tracelog "[EVENT] CH%02X $%02X\n", c, a; go }
; wpset F800,1,w,wpdata==39&&(bc>>8)==00,{w@F9A1 = (w@F9A1) + 1; g}
	include "def.inc"

#target rom

#data WRAM,$F800,$800
	include "wram.s"

#code DRIVER_CODE,$0000,$6000
	;org $0000
j_startup:
	di
	jp startup

	org $0008
j_port_write_delay1:
	jp port_write_delay1

	org $0010
j_port_write_delay2:
	jp port_write_delay2

	org $0018
j_port_write_a:
	jp port_write_a

	org $0020
j_port_write_b:
	jp port_write_b

	org $0028
j_port_read_a:
	jp port_read_a

	org $0038
j_IRQ:
	di
	jp IRQ

	db "MZS driver 2.0.0-alpha.1 by StereoMimi"

	org $0066
NMI:
	push af
	push bc
	push de
	push hl
	push ix
	push iy
		in a,(READ_68K)
		or a,a ; cp a,$00
		jr z,do_nothing$
		cp a,$01
		jp z,BCOM_prepare_switch
		cp a,$03
		jp z,BCOM_reset
		
		bit 7,a
		call nz,UCOM_write2buffer

		xor a,$FF
		;ld a,(tmp)
		out (WRITE_68K),a    ; reply to 68k
		out (READ_68K),a     ; clear sound code

do_nothing$:
	pop iy
	pop ix
	pop hl
	pop de
	pop bc
	pop af
	retn

IRQ:
	reti

startup:
	ld sp,$FFFC
	im 1

	; Clear WRAM
	ld hl,WRAM_START
	ld de,WRAM_START+1
	ld bc,WRAM_END-WRAM_START-1
	ld (hl),0
	ldir

	; Set WRAM variables
	ld a,$FF
	ld (master_volume),a

	; Silence YM2610
	call FM_stop
	call PA_reset
	call pb_stop
	call ssg_stop

	; Useless devkit port write (probably?)
	ld a,1
	out ($C0),a
	
	;call set_default_banks
	ld b,0
	call set_banks
	call SFXPS_init
	call UCOM_init

	; Set Timer A to ~60Hz and
	; Timer B to ~60Hz by default
	ld hl,98
	call ta_counter_load_set
	ld de,REG_TMB_COUNTER<<8 | 198
	rst RST_YM_WRITEA

	; Reset timer counters to 0
	ld de,REG_TIMER_CNT<<8 
	rst RST_YM_WRITEA

	; Loads load counters, enables interrupts 
	; and resets flags of timer A and B.
	; https://wiki.neogeodev.org/index.php?title=YM2610_timers
	;ld e,%00111111 ; ADDING TMB CAUSES LAG ISSUES EVERY ~7.8s ?
	ld d,REG_TIMER_CNT
	ld e,%00010101
	rst RST_YM_WRITEA
	out (ENABLE_NMI),a 

main_loop$:
	ei
	; Check the timer A and B flags,
	; and executes their routines
	; if required.
	in a,(4)
	bit 0,a
	call nz,execute_tma_tick
	;call nz,execute_tmb_tick

	call UCOM_handle_command
	call SFXPS_update

	ld a,(is_tma_triggered)
	or a,a ; cp a,0
	jr z,main_loop$

	ld d,REG_TIMER_CNT
	ld e,%00010101
	rst RST_YM_WRITEA
	xor a,a
	ld (is_tma_triggered),a

	jr main_loop$

execute_tmb_tick:
	; Loads load counter, enables interrupts 
	; and resets flags of timer B.
	;ld e,%00111111
	ld e,%00101010
	ld d,REG_TIMER_CNT
	rst RST_YM_WRITEA
	ret

; wpset F800,1,w,wpdata==39,{printf "TMA IRQ ========"; go}
; wpset F800,1,w,wpdata==3A,{printf "TMA TICK --------"; go}
execute_tma_tick:
	call FADE_irq
	call MLM_irq

	ld a,$FF
	ld (is_tma_triggered),a
	ret

fast_beep:
	push de
		ld de, 0040h	        ;Channel 1 frequency: 2kHz
		rst RST_YM_WRITEA
		ld de, 0100h
		rst RST_YM_WRITEA

		ld de, REG_SSG_VOL_ENV<<8 | $0F		;EG period: $50F
		rst RST_YM_WRITEA
		ld de, REG_SSG_COARSE_ENV<<8 | $05 
		rst RST_YM_WRITEA

		ld de, REG_SSG_CHA_VOL<<8 | $10		;Channel's 1 amplitude is tied to the EG
		rst RST_YM_WRITEA
		ld de, REG_SSG_VOL_ENV_SHAPE<<8 | $08		;EG shape: Repetitive ramp down
		rst RST_YM_WRITEA
		ld de, REG_SSG_MIX_ENABLE<<8 | $0E		;All channels except 1 are off
		rst RST_YM_WRITEA
	pop de
	ret

play_sample:
	push de
		ld de,REG_PA_MVOL<<8 | $3F
		rst RST_YM_WRITEB
		ld de,REG_PA_CVOL<<8 | %11000000 | $1F
		rst RST_YM_WRITEB
		ld de,REG_PA_STARTL<<8 | $00
		rst RST_YM_WRITEB
		ld de,REG_PA_STARTH<<8 | $00
		rst RST_YM_WRITEB
		ld de,REG_PA_ENDL<<8 | $40
		rst RST_YM_WRITEB
		ld de,REG_PA_ENDH<<8 | $00
		rst RST_YM_WRITEB
		ld de,REG_PA_CTRL<<8 | 1
		rst RST_YM_WRITEB
	pop de
	ret

; b: 32kb bank
set_banks:
	push af
	push bc
		; If the selected bank has already
		; been switched into place, return
		ld a,(current_bank)
		cp a,b
		jp z,return$

		; Store bank in WRAM
		ld a,b
		ld (current_bank),a

		; z3 = b * 2
		sla a
		ld c,a
		in a,($0B)

		; z2 = z3 * 2 + 2
		ld a,c
		sla a
		add a,2
		ld c,a
		in a,($0A)

		; z1 = z2 * 2 + 2
		ld a,c
		sla a
		add a,2
		ld c,a
		in a,($09)

		; z0 = z1 * 2 + 2
		ld a,c
		sla a
		add a,2
		in a,($08)
		
return$:
	pop bc
	pop af
	ret

; Plays a noisy beep on the first FM channel
; and then enters an infinite loop
fm_softlock:
	di              
	call FM_stop

	; Set FM channel 1 registers
	ld d,REG_FM_CH13_FBLOCK
	ld e,$10
	rst RST_YM_WRITEA
	ld d,REG_FM_CH13_FNUM
	ld e,$FF
	rst RST_YM_WRITEA
	ld d,REG_FM_CH13_FBALGO
	ld e,$3F
	rst RST_YM_WRITEA
	ld d,REG_FM_CH13_LRAMSPMS
	ld e,%11000000
	rst RST_YM_WRITEA

	; Set operator 1
	ld d,REG_FM_CH1_OP1_DTMUL
	ld e,$00
	rst RST_YM_WRITEA
	ld d,REG_FM_CH1_OP1_TVOL
	ld e,$00
	rst RST_YM_WRITEA
	ld d,REG_FM_CH1_OP1_KSAR
	ld e,31
	rst RST_YM_WRITEA
	ld d,REG_FM_CH1_OP1_AMDR
	ld e,$00
	rst RST_YM_WRITEA
	ld d,REG_FM_CH1_OP1_SUSR
	ld e,$00
	rst RST_YM_WRITEA
	ld d,REG_FM_CH1_OP1_SLRR
	ld e,15
	rst RST_YM_WRITEA
	ld d,REG_FM_CH1_OP1_ENVGN
	ld e,0
	rst RST_YM_WRITEA

	ld d,REG_FM_KEY_ON
	ld e,$11
	rst RST_YM_WRITEA

	jp $

softlock:
	call ssg_stop

	ld d,REG_SSG_CHC_FINE_TUNE
	ld e,$FF
	rst RST_YM_WRITEA

	ld d,REG_SSG_CHC_COARSE_TUNE
	ld e,$05
	rst RST_YM_WRITEA

	ld d,REG_SSG_CHN_NOISE_TUNE
	ld e,$08
	rst RST_YM_WRITEA

	ld d,REG_SSG_CHN_NOISE_TUNE
	ld e,$08
	rst RST_YM_WRITEA

	ld d,REG_SSG_MIX_ENABLE
	ld e,%11011011
	rst RST_YM_WRITEA

	ld d,REG_SSG_CHC_VOL
	ld e,$0A
	rst RST_YM_WRITEA

	jp $

	include "rst.s"
	include "com.s"
	include "ssg.s"
	include "adpcm.s"
	include "fm.s"
	include "timer.s"
	include "mlm.s"
	include "mlmcom.s"
	include "mlmmacro.s"
	include "math.s"
	include "sfxps.s"
	include "macro.s"
	include "fade.s"