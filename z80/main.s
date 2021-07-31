; wpset F800,1,w,wpdata==39
; trace bst_test.tr,1,noloop
; wpset F800,1,w,wpdata==3A,{tracelog "A addr: 0x%02X; data: 0x%02X\n", d, e; go}
; wpset F800,1,w,wpdata==3B,{tracelog "B addr: 0x%02X; data: 0x%02X\n", d, e; go}

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

	org &0028
j_port_read_a:
	jp port_read_a

	org &0038
j_IRQ:
	di
	jp IRQ

	asciiz "MZS driver v. 6.3-beta by GbaCretin"

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
	ld de,(REG_TIMER_CNT<<8) | TM_CNT_LOAD_TA | TM_CNT_TA_FLG_RESET | TM_CNT_ENABLE_TA_IRQ
	rst RST_YM_WRITEA
	
	call set_default_banks

	out (ENABLE_NMI),a ; This does NOT crash or stop execution

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
		; Set $F000-$F7FF bank to bank $16 (30 *  2K; $F000~$F7FF)
		ld a,&1E
		in a,(&08)
		; Set $E000-$EFFF bank to bank $0A (14 *  4K; $E000~$EFFF)
		ld a,&0E
		in a,(&09)
		; Set $C000-$DFFF bank to bank $04 ( 6 *  8K; $C000~$DFFF)
		ld a,&06
		in a,(&0A)
		; Set $8000-$BFFF bank to bank $02 ( 2 * 16K; $8000~$BFFF)
		ld a,&02
		in a,(&0B)
	pop af
	ret

; Plays a noisy beep on the first FM channel
; and then enters an infinite loop
fm_softlock:
	di              
	call fm_stop

	; Set FM channel 1 registers
	ld d,REG_FM_CH13_FBLOCK
	ld e,&10
	rst RST_YM_WRITEA
	ld d,REG_FM_CH13_FNUM
	ld e,&FF
	rst RST_YM_WRITEA
	ld d,REG_FM_CH13_FBALGO
	ld e,&3F
	rst RST_YM_WRITEA
	ld d,REG_FM_CH13_LRAMSPMS
	ld e,%11000000
	rst RST_YM_WRITEA

	; Set operator 1
	ld d,REG_FM_CH1_OP1_DTMUL
	ld e,&00
	rst RST_YM_WRITEA
	ld d,REG_FM_CH1_OP1_TVOL
	ld e,&00
	rst RST_YM_WRITEA
	ld d,REG_FM_CH1_OP1_KSAR
	ld e,31
	rst RST_YM_WRITEA
	ld d,REG_FM_CH1_OP1_AMDR
	ld e,&00
	rst RST_YM_WRITEA
	ld d,REG_FM_CH1_OP1_SUSR
	ld e,&00
	rst RST_YM_WRITEA
	ld d,REG_FM_CH1_OP1_SLRR
	ld e,15
	rst RST_YM_WRITEA
	ld d,REG_FM_CH1_OP1_ENVGN
	ld e,0
	rst RST_YM_WRITEA

	ld d,REG_FM_KEY_ON
	ld e,&11
	rst RST_YM_WRITEA

	jp $

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

	include "mlm_test_data.s"
	;org MLM_HEADER ; block 1
	;incbin "m1_sdata.bin"

	include "wram.s"
