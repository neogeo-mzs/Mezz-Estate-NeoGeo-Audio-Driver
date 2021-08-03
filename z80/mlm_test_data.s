	org MLM_HEADER ; block 1
MLM_header:
	db 13 ; Song count
	dw MLM_song_pa1-MLM_header
	dw MLM_song_pa2-MLM_header
	dw MLM_song_pa3-MLM_header
	dw MLM_song_pa4-MLM_header
	dw MLM_song_pa5-MLM_header
	dw MLM_song_pa6-MLM_header
	dw MLM_song_fm1-MLM_header
	dw MLM_song_fm2-MLM_header
	dw MLM_song_fm3-MLM_header
	dw MLM_song_fm4-MLM_header
	dw MLM_song_ssg1-MLM_header
	dw MLM_song_ssg2-MLM_header
	dw MLM_song_ssg3-MLM_header

MLM_song_pa1:
	dw MLM_el_pa-MLM_header
	dsw 12, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_pa2
	dw 0
	dw MLM_el_pa-MLM_header
	dsw 11, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_pa3:
	dsw 2,0
	dw MLM_el_pa-MLM_header
	dsw 10, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_pa4:
	dsw 3,0
	dw MLM_el_pa-MLM_header
	dsw 9, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_pa5:
	dsw 4,0
	dw MLM_el_pa-MLM_header
	dsw 8, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_pa6:
	dsw 5,0
	dw MLM_el_pa-MLM_header
	dsw 7, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_el_pa: ; Start in Zone 3
	db &30 | 8 | (8-1) ; Offset volume by -8
	db &80 | 30, 0 ; Play ADPCM-A sample 0 (C)
	db &09                        ; - Jump to sub event list
	dw MLM_sub_el_wait-MLM_HEADER ; /

	db &30 | (6-1) ; Offset volume by +6
	db &80 | 30, 2 ; Play ADPCM-A sample 2 (D)
	db &00 ; End of song

MLM_sub_el_wait:
	db &01, 30
	db &20

MLM_song_fm1:
	dsw 6,0
	dw MLM_el_fm-MLM_header
	dsw 6, 0
	dw 378 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_fm2:
	dsw 7,0
	dw MLM_el_fm-MLM_header
	dsw 5, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_fm3:
	dsw 8,0
	dw MLM_el_fm-MLM_header
	dsw 4, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_fm4:
	dsw 9,0
	dw MLM_el_fm-MLM_header
	dsw 3, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_el_fm:
	db &02,2 ; Set instrument to 2
	db &80 | (8*3), 0 | (5 << 4) ; Play FM note C4 and wait 8*3 ticks
	db &80 | (8*3), 2 | (5 << 4) ; Play FM note D4 and wait 8*3 ticks
	db &80 | (8*3), 4 | (5 << 4) ; Play FM note E4 and wait 8*3 ticks
	db &80 | (8*3), 5 | (5 << 4) ; Play FM note C4 and wait 8*3 ticks
	db &00
	
	; Jump to MLM_el_fm
	db &0B
	dw MLM_el_fm-MLM_header


MLM_song_ssg1:
	dsw 10,0
	dw MLM_el_ssg-MLM_header
	dsw 2, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_ssg2:
	dsw 11,0
	dw MLM_el_ssg-MLM_header
	dw 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header

MLM_song_ssg3:
	dsw 12,0
	dw MLM_el_ssg-MLM_header
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)
	dw MLM_song_instruments-MLM_header
	
MLM_el_ssg:
	db &02,1                  ; Set instrument to 1
	db &38 ; Set SSG volume to 8
	db &80 | 30,2*12 + 0 ; Play SSG note C4 and wait 30 ticks
	db &09                        ; - Jump to sub event list
	dw MLM_sub_el_wait-MLM_HEADER ; /

	db &3F ; Set SSG volume to F
	db &80 | 30,2*12 + 2 ; Play SSG note D4 and wait 30 ticks
 	db &00 ; End of song

MLM_song_instruments:
	; Instrument 0 (ADPCM-A)
	dw OTHER_DATA-MLM_header ; Point to ADPCM-A sample LUT (in Zone 1)
	dsb 30,0 ; padding

	; Instrument 1 (SSG)
	db 1                               ; Mixing: Tone ON; Noise OFF
	db 0                               ; EG enable: OFF
	ds 3                               ; Skip EG information since EG is disabled
	dw &0000                           ; Mix macro      | MLM_odata_mix_macro1-MLM_header
	dw &0000                           ; Volume macro   | MLM_odata_vol_macro1-MLM_header
	dw MLM_odata_arp_macro1-MLM_header ; Arpeggio macro | 
	ds 21 ; Padding
	
	; Instrument 2 (FM)
	fm_ch_data 2,0,0,0                 ; feedback, algorithm, pms, ams
	db &F0                             ; Enable all 4 operators
	fm_op_data 3,1,38,2,31,0,4,6,1,7,0 ; dt,mul,tl,rs,a,am,d,d2,s,r,eg
	fm_op_data 3,0,40,2,31,0,4,5,1,7,0
	fm_op_data 3,0,13,0,31,0,9,5,1,7,0
	fm_op_data 3,1,10,0,31,0,4,3,1,7,0
	dsb 1,0 ; Padding

	; Other data
	org OTHER_DATA
	incbin "adpcma_sample_lut.bin"
MLM_odata_mix_macro1:
	db (30*3)-1 ; Macro length
	db 30       ; Set loop point to 30
	dsb 15,&11  ; 30 frames with tone enabled and noise disabled
	dsb 15,&22  ; 30 frames with tone disabled and noise enabled
	dsb 15,&33  ; 30 frames with tone and noise enabled

MLM_odata_vol_macro1:
	db 24-1 ; Macro length
	db 16   ; Loop point
	;  F E  D C  B A  9 8  7 6  5 4  3 2  1 0
	db &EF, &CD, &AB, &89, &67, &45, &23, &01
	;  2 4  6 8  A C  E F 
	db &42, &86, &CA, &FE

MLM_odata_arp_macro1:
	db 10-1 ; Macro length
	db 2    ; Loop point
	db -2,-2,-1,-1, 0, 0, 1, 1, 2, 2