; wpset F800,1,w,wpdata==39
; wpset F800,1,w,wpdata==3A && bc == 0201
; trace fm1_regrec.tr,1
; wpset F800,1,w,wpdata==3A,{tracelog "A addr: 0x%02X; data: 0x%02X\n", d, e; go}
; wpset F800,1,w,wpdata==3B,{tracelog "B addr: 0x%02X; data: 0x%02X\n", d, e; go}
; wpset F800,1,w,wpdata==3C,{tracelog "WA addr: 0x%02X;", a; go}
; wpset F800,1,w,wpdata==3D,{tracelog " data: 0x%02X\n", a; go}
; wpset F800,1,w,wpdata==39&&(bc>>8)==00,{w@F9A1 = (w@F9A1) + 1; g}
	include "def.inc"

#target rom

#data WRAM,$F800,$800
	include "wram.s"

#code DRIVER_CODE,$0000,$4000
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

	db "MZS driver v. 7.4-beta by GbaCretin"

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
		jr z,NMI_do_nothing
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

NMI_do_nothing:
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

	; Silence YM2610
	call fm_stop
	call PA_reset
	call pb_stop
	call ssg_stop

	; Useless devkit port write (probably?)
	ld a,1
	out ($C0),a
	
	;call set_default_banks
	ld b,2
	call set_banks
	call SFXPS_init
	call UCOM_init

	ld hl,98
	call ta_counter_load_set

	; Reset timer counters to 0
	ld de,REG_TIMER_CNT<<8 
	rst RST_YM_WRITEA

	; Loads Load counter to TA counter and resets TA flags
	ld e,TM_CNT_LOAD_TA | TM_CNT_TA_FLG_RESET | TM_CNT_ENABLE_TA_IRQ
	rst RST_YM_WRITEA

	out (ENABLE_NMI),a 

main_loop:
	; Check the timer A flag, if so, 
	; execute the timer based functions
	in a,(4)
	bit 0,a
	call nz,execute_tma_tick

	call UCOM_handle_command
	call SFXPS_update
	jr main_loop

execute_tma_tick:
	; Increment base time counter, and if it's
	; not equal to the song's base time, only
	; update the YM2610 timer flags
	ld a,(IRQ_tick_time_counter) ; \
	inc a                        ; | MLM_base_time_counter++
	ld (IRQ_tick_time_counter),a ; /
	ld c,a ; Backup base time counter in c
	ld a,(IRQ_tick_base_time)
	cp a,c
	jr nz,execute_tma_tick_skip ; If MLM_base_time_counter != MLM_base_time return

	; Else, clear the counter and carry on executing the tick
	xor a,a ; ld a,0
	ld (IRQ_tick_time_counter),a

	call MLM_irq
	call FMCNT_irq
	call SSGCNT_irq

execute_tma_tick_skip:
	ld e,TM_CNT_LOAD_TA | TM_CNT_TA_FLG_RESET | TM_CNT_ENABLE_TA_IRQ 
	ld d,REG_TIMER_CNT
	rst RST_YM_WRITEA
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
		brk

		; If the selected bank has already
		; been switched into place, return
		ld a,(current_bank)
		cp a,b
		jp z,set_banks_ret

		; Store bank in WRAM
		ld a,b
		ld (current_bank),a

		; z3 = b * 2
		sla a
		in a,($0B)

		; z2 = z3 * 2 + 2
		sla a
		add a,2
		in a,($0A)

		; z1 = z2 * 2 + 2
		sla a
		add a,2
		in a,($09)

		; z0 = z1 * 2 + 2
		sla a
		add a,2
		in a,($08)
		
set_banks_ret:
	pop af
	ret

; Plays a noisy beep on the first FM channel
; and then enters an infinite loop
fm_softlock:
	di              
	call fm_stop

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
	include "math.s"
	include "sfxps.s"

	;org MLM_HEADER ; block 1
	;incbin "m1rom_sdata.bin"
	include "mlm_test_data.s"