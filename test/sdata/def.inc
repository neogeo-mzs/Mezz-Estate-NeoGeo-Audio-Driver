; =================== MLM defines ===================
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
PANNING_RIGHT  equ %01000000
PANNING_LEFT   equ %10000000
PANNING_CENTER equ %11000000
SSG_MIX_NONE      equ %00000000
SSG_MIX_TONE      equ %00000001
SSG_MIX_NOISE     equ %00001000
SSG_MIX_TONENOISE equ %00001001

; ================ Instrument macros ================
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

; ================ MLM event macros ================
	macro pa_note sample,time
		db $80 | \time, \sample
	endm

	macro fm_note note,octave,time
		db $80 | \time,(\note & 0x0F) | (\octave<<4) 
	endm

	macro ssg_note note,octave,time
		db $80 | \time,(\octave-2) * 12 + \note
	endm

	macro end_of_el
		db $00
	endm

	macro note_off time
		db $40, \time
	endm

	macro set_inst inst
		db $41, \inst 
	endm

	macro wait_time8 time 
		db $42, \time
	endm

	macro set_vol volume 
		db $43, \volume 
	endm

	macro set_pan panning,time
		db $44, \panning | (\time & 0x3F)
	endm

	macro set_pa_mvol mvol 
		db $45, \mvol
	endm

	macro set_btime base_time 
		db $46, \base_time
	endm

	macro subel_jump address
		db $20
		dw address
	endm

	macro jump address
		db $21
		dw address
	endm

	macro wait_time4 time
		db $10 | (time-1)
	endm

	macro subel_ret
		db $01
	endm

	macro fm_tl_set operator,tl 
		db $48 | operator,tl
	endm

	macro mlm_macro_set index,init_data_addr
		db $30, \index
		dw \init_data_addr
	endm