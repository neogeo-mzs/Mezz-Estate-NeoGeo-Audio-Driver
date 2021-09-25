; Memory map
FIXED       equ $0000
BANK3       equ $8000
BANK2       equ $C000
BANK1       equ $E000
BANK0       equ $F000
WRAM_START  equ $F800
WRAM_END    equ $FFFF

MLM_HEADER  equ FIXED+$4000
MLM_SONG2   equ BANK3
INSTRUMENTS equ BANK2
OTHER_DATA  equ BANK1

; Port map
READ_68K    equ $00
YM2610_A0   equ $04
YM2610_A1   equ $05
YM2610_B0   equ $06
YM2610_B1   equ $07
ENABLE_NMI  equ $08
WRITE_68K   equ $0C
DISABLE_NMI equ $18

; YM2610 SSG defines
REG_SSG_CHA_FINE_TUNE   equ $00
REG_SSG_CHA_COARSE_TUNE equ $01
REG_SSG_CHB_FINE_TUNE   equ $02
REG_SSG_CHB_COARSE_TUNE equ $03
REG_SSG_CHC_FINE_TUNE   equ $04
REG_SSG_CHC_COARSE_TUNE equ $05
REG_SSG_CHN_NOISE_TUNE  equ $06
REG_SSG_MIX_ENABLE     equ $07
REG_SSG_CHA_VOL        equ $08
REG_SSG_CHB_VOL        equ $09
REG_SSG_CHC_VOL        equ $0A
REG_SSG_VOL_ENV        equ $0B
REG_SSG_COARSE_ENV     equ $0C
REG_SSG_VOL_ENV_SHAPE  equ $0D

SSG_CHA equ $00
SSG_CHB equ $01
SSG_CHC equ $02

SSG_MIX_NONE      equ 0
SSG_MIX_TONE      equ 1
SSG_MIX_NOISE     equ 2
SSG_MIX_TONENOISE equ 3

; YM2610 FM registers
REG_FM_LFO_CNT equ $22
REG_FM_KEY_ON  equ $28

REG_FM_CH13_FNUM      equ $A1
REG_FM_CH13_FBLOCK    equ $A5
REG_FM_CH13_FBALGO    equ $B1
REG_FM_CH13_LRAMSPMS  equ $B5

REG_FM_CH24_FNUM     equ $A2
REG_FM_CH24_FBLOCK   equ $A6
REG_FM_CH24_FBALGO   equ $B2
REG_FM_CH24_LRAMSPMS  equ $B6

REG_FM_CH1_OP1_DTMUL equ $31
REG_FM_CH1_OP1_TVOL  equ $41
REG_FM_CH1_OP1_KSAR  equ $51
REG_FM_CH1_OP1_AMDR  equ $61
REG_FM_CH1_OP1_SUSR  equ $71
REG_FM_CH1_OP1_SLRR  equ $81
REG_FM_CH1_OP1_ENVGN equ $91

REG_FM_CH1_OP2_DTMUL equ $39
REG_FM_CH1_OP2_TVOL  equ $49
REG_FM_CH1_OP2_KSAR  equ $59
REG_FM_CH1_OP2_AMDR  equ $69
REG_FM_CH1_OP2_SUSR  equ $79
REG_FM_CH1_OP2_SLRR  equ $89
REG_FM_CH1_OP2_ENVGN equ $99

REG_FM_CH1_OP3_DTMUL equ $35
REG_FM_CH1_OP3_TVOL  equ $45
REG_FM_CH1_OP3_KSAR  equ $55
REG_FM_CH1_OP3_AMDR  equ $65
REG_FM_CH1_OP3_SUSR  equ $75
REG_FM_CH1_OP3_SLRR  equ $85
REG_FM_CH1_OP3_ENVGN equ $95

REG_FM_CH1_OP4_DTMUL equ $3D
REG_FM_CH1_OP4_TVOL  equ $4D
REG_FM_CH1_OP4_KSAR  equ $5D
REG_FM_CH1_OP4_AMDR  equ $6D
REG_FM_CH1_OP4_SUSR  equ $7D
REG_FM_CH1_OP4_SLRR  equ $8D
REG_FM_CH1_OP4_ENVGN equ $9D

; YM2610 Timer Registers
REG_TMA_COUNTER_MSB equ $24
REG_TMA_COUNTER_LSB equ $25 ; ------TT
REG_TMB_COUNTER     equ $26
REG_TIMER_CNT       equ $27

; FM defines
FM_CH1 equ %001
FM_CH2 equ %010
FM_CH3 equ %101
FM_CH4 equ %110

FM_OP1      equ 0
FM_OP2      equ 1
FM_OP3      equ 2
FM_OP4      equ 3
FM_OP_COUNT equ 4

; ADPCM-A defines
REG_PA_CTRL		equ $00
REG_PA_MVOL		equ $01
REG_PA_CVOL		equ $08
REG_PA_STARTL	equ $10
REG_PA_STARTH	equ $18
REG_PA_ENDL		equ $20
REG_PA_ENDH		equ $28

; ADPCM-B defines
REG_PB_CTRL		equ $10
REG_PB_LRSEL	equ $11
REG_PB_STARTL	equ $12
REG_PB_STARTH	equ $13
REG_PB_ENDL		equ $14
REG_PB_ENDH		equ $15
REG_PB_FREQL	equ $19
REG_PB_FREQH	equ $1A
REG_PB_VOL		equ $1B
REG_P_FLAGS_W	equ $1C
REG_P_FLAGS_R   equ $06

; RSTs
RST_YM_DELAY1 equ $08
RST_YM_DELAY2 equ $10
RST_YM_WRITEA equ $18
RST_YM_WRITEB equ $20
RST_YM_READA equ $28

; Timer control
TM_CNT_LOAD_TA       equ %00000001
TM_CNT_LOAD_TB       equ %00000010
TM_CNT_ENABLE_TA_IRQ equ %00000100
TM_CNT_ENABLE_TB_IRQ equ %00001000
TM_CNT_TA_FLG_RESET  equ %00010000
TM_CNT_TB_FLG_RESET  equ %00100000
TM_CNT_2CH_MODE      equ %01000000
TM_CNT_CSM_MODE      equ %10000000

; MLM defines
NOTE_C  equ $0
NOTE_CS equ $1
NOTE_D  equ $2
NOTE_DS equ $3
NOTE_E  equ $4
NOTE_F  equ $5
NOTE_FS equ $6
NOTE_G  equ $7
NOTE_GS equ $8
NOTE_A  equ $9
NOTE_AS equ $A
NOTE_B  equ $B

PANNING_NONE   equ %00000000
PANNING_R      equ %01000000
PANNING_L      equ %10000000
PANNING_CENTER equ %11000000

CHANNEL_COUNT     equ 13
PA_CHANNEL_COUNT  equ 6
FM_CHANNEL_COUNT  equ 4
SSG_CHANNEL_COUNT equ 3

MLM_CH_PA1  equ 0
MLM_CH_PA2  equ 1
MLM_CH_PA3  equ 2
MLM_CH_PA4  equ 3
MLM_CH_PA5  equ 4
MLM_CH_PA6  equ 5
MLM_CH_FM1  equ 6
MLM_CH_FM2  equ 7
MLM_CH_FM3  equ 8
MLM_CH_FM4  equ 9
MLM_CH_SSG1 equ 10
MLM_CH_SSG2 equ 11
MLM_CH_SSG3 equ 12

; Should always be a multiple of 2
; and also be smaller than 128
COM_BUFFER_LENGTH equ 32

UCOM_MASK         equ %01111111

; SSG driver definitions (driver into 
; the driver??? change name later)
SSGCNT_MIX_EN_TUNE	equ 0
SSGCNT_MIX_EN_NOISE	equ 3

SFXPS_CH_FREE  equ $00
SFXPS_CH_BUSY  equ $01
SFXPS_CH_TAKEN equ $02

SFXPS_CHANNEL_COUNT equ PA_CHANNEL_COUNT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                    MACROS                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	macro srl_hl
		srl h
		rr l
	endm

	macro brk
		push af
		ld a,$39
		ld (breakpoint),a
		pop af
	endm

	macro brk2
		push af
		ld a,$3A
		ld (breakpoint),a
		pop af
	endm

	macro brk3
		push af
		ld a,$3B
		ld (breakpoint),a
		pop af
	endm

	macro fm_ch_data fb,algo,ams,pms
		.db \algo | (\fb << 3)
		.db \pms | (\ams << 4)
	endm

	; deflemask:      dt,mul,tl,rs,a, am,d, d2,s, r, eg
	macro fm_op_data dt,mul,tl,ks,ar,am,dr,sr,sl,rr,eg
		.db \mul | (\dt << 4)
		.db \tl
		.db \ar | (\ks << 6)
		.db \dr | (\am << 7)
		.db \sr
		.db \rr | (\sl << 4)
		.db \eg
	endm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                    STRUCT                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ControlMacro.enable  equ 0
ControlMacro.length  equ 1
ControlMacro.data    equ 2
ControlMacro.loop_pt equ 4
ControlMacro.curr_pt equ 5
ControlMacro.SIZE    equ 8

;	macro ControlMacro
;enable 	.ds 1 ; u8
;length 	.ds 1 ; u8
;data 	.ds 2 ; void*
;loop_pt	.ds 1 ; u8
;curr_pt	.ds 1 ; u8 (Current point)
;pad 	.ds 2 ; u8[2] 
;	endm

	macro ControlMacro
	.ds 1+1+2+1+1+2
	endm