    include "def.inc"

#target rom

#code SDATA_FBANK,$6000,$2000
MLM_header:
	dw MLM_odata_smp_lut-MLM_header ; Point to ADPCM-A sample table
	db 13 ; Song count
	.long (MLM_song_pa1-MLM_header) << 8 | 0
	.long (MLM_song_pa2-MLM_header) << 8 | 0
	.long (MLM_song_pa3-MLM_header) << 8 | 0
	.long (MLM_song_pa4-MLM_header) << 8 | 0
	.long (MLM_song_pa5-MLM_header) << 8 | 0
	.long (MLM_song_pa6-MLM_header) << 8 | 0
	.long (MLM_song_fm1-MLM_header) << 8 | 1
	.long (MLM_song_fm2-MLM_header) << 8 | 1
	.long (MLM_song_fm3-MLM_header) << 8 | 1
	.long (MLM_song_fm4-MLM_header) << 8 | 1
	.long (MLM_song_ssg1-MLM_header) << 8 | 2
	.long (MLM_song_ssg2-MLM_header) << 8 | 2
	.long (MLM_song_ssg3-MLM_header) << 8 | 2

MLM_song_instruments:
	; Instrument 0 (ADPCM-A)
	dw MLM_odata_smp_lut-MLM_header ; Point to ADPCM-A sample LUT (in Zone 1)
	ds 30,0 ; padding

	; Instrument 1 (SSG)
	db SSG_MIX_TONE                    ; Mixing: Tone ON; Noise OFF
	db 0                               ; EG enable: OFF
	ds 3                               ; Skip EG information since EG is disabled
	ds 27 ; Padding
	
	; Instrument 2 (FM)
	fm_ch_data 2,0,0,0                 ; feedback, algorithm, pms, ams
	db $F0                             ; Enable all 4 operators
	fm_op_data 3,1,38,2,31,0,4,6,1,7,0 ; dt,mul,tl,rs,a,am,d,d2,s,r,eg
	fm_op_data 3,0,40,2,31,0,4,5,1,7,0
	fm_op_data 3,0,13,0,31,0,9,5,1,7,0
	fm_op_data 3,1,10,0,31,0,4,3,1,7,0
	ds 1,0 ; Padding

MLM_odata_smp_lut:
	incbin "adpcma_sample_lut.bin"
MLM_odata_mix_macro1:
	db (30*3)-1 ; Macro length
	db 30       ; Set loop point to 30
	ds 15,$11  ; 30 frames with tone enabled and noise disabled
	ds 15,$22  ; 30 frames with tone disabled and noise enabled
	ds 15,$33  ; 30 frames with tone and noise enabled

MLM_odata_vol_macro1:
	db 24-1 ; Macro length
	db 16   ; Loop point
	;  F E  D C  B A  9 8  7 6  5 4  3 2  1 0
	db $EF, $CD, $AB, $89, $67, $45, $23, $01
	;  2 4  6 8  A C  E F 
	db $42, $86, $CA, $FE

MLM_odata_arp_macro1:
	db 10-1 ; Macro length
	db 2    ; Loop point
	db -2,-2,-1,-1, 0, 0, 1, 1, 2, 2

#code SDATA_BANK0,$8000,$8000
MLM_song_pa1:
	dw MLM_el_pa-MLM_header
	ds 12*2, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_pa2
	dw 0
	dw MLM_el_pa-MLM_header
	ds 11*2,0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_pa3:
	ds 2*2,0
	dw MLM_el_pa-MLM_header
	ds 10*2,0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_pa4:
	ds 3*2,0
	dw MLM_el_pa-MLM_header
	ds 9*2,0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_pa5:
	ds 4*2,0
	dw MLM_el_pa-MLM_header
	ds 8*2,0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_pa6:
	ds 5*2,0
	dw MLM_el_pa-MLM_header
	ds 7*2,0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_el_pa: ; Start in Zone 3
	pa_note NOTE_C,30
	note_off 30
	pa_note NOTE_D,30
	note_off 30
	jump MLM_el_pa-MLM_header

#code SDATA_BANK1,$8000,$8000
MLM_song_fm1:
	ds 6*2,0
	dw MLM_el_fm-MLM_header
	ds 6*2,0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_fm2:
	ds 7*2,0
	dw MLM_el_fm-MLM_header
	ds 5*2,0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_fm3:
	ds 8*2,0
	dw MLM_el_fm-MLM_header
	ds 4*2,0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_fm4:
	ds 9*2,0
	dw MLM_el_fm-MLM_header
	ds 3*2,0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_el_fm:
	set_inst 2
	set_pan PANNING_CENTER,0
	fm_note NOTE_C,4,24
	fm_note NOTE_D,4,24
	note_off 30
	set_vol $E8
	set_pan PANNING_LEFT,0
	fm_note NOTE_E,4,24
	set_pan PANNING_RIGHT,0
	fm_note NOTE_C,4,24
	note_off 30
	jump MLM_el_fm-MLM_header

#code SDATA_BANK2,$8000,$8000
MLM_song_ssg1:
	ds 10*2,0
	dw MLM_el_ssg-MLM_header
	ds 2*2,0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_ssg2:
	ds 11*2,0
	dw MLM_el_ssg-MLM_header
	dw 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_ssg3:
	ds 12*2,0
	dw MLM_el_ssg-MLM_header
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header
	
MLM_el_ssg:
	set_inst 1
	ssg_note NOTE_C,4,24
	ssg_note NOTE_D,4,24
	end_of_el

MLM_ssg_pmacro:
	db 16-1 ; Length:     16
	db 8    ; Loop point: 8
	db 0,  8,  16, 32, 48, 64, 80, 96
	db 127, 80, 127, 80, 127, 80, 127, 80 