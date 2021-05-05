	org &4000 ; block 1
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


MLM_song_fm1:
	dsw 6,0
	dw MLM_el_fm-MLM_header
	dsw 6, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_song_fm2:
	dsw 7,0
	dw MLM_el_fm-MLM_header
	dsw 5, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_song_fm3:
	dsw 8,0
	dw MLM_el_fm-MLM_header
	dsw 4, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_song_fm4:
	dsw 9,0
	dw MLM_el_fm-MLM_header
	dsw 3, 0
	dw 98 ; Timer A frequency
	db 1  ; base time (0 is invalid)

MLM_el_fm:
	db &76 ; Invalid command
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
	db &02,1             ; Set instrument to 1
	db &80 | 127,2*12 + 0 ; Play SSG note C4
	db &01, 15           ; Note off and wait 30 ticks
	db &80 | 15,2*12 + 2 ; Play SSG note D4
	db &00 ; End of song

	; Instruments
	org &8000

	; Instrument 0 (ADPCM-A)
	dw &E000 ; Point to ADPCM-A sample LUT (in Zone 1)
	dsb 30,0 ; padding

	; Instrument 1 (SSG)
	db 1  ; Mixing: Tone ON; Noise OFF
	db 0  ; EG enable: OFF
	ds 3  ; Skip EG information since EG is disabled
	dw MLM_odata_mix_macro1-&A000 + OTHER_DATA
	ds 4 ; Data that will be used later
	ds 21 ; Padding
	 
	; Other data
	org &A000
	incbin "adpcma_sample_lut.bin"
MLM_odata_mix_macro1:
	db (30*3)-1 ; Macro length
	db 30       ; Set loop point to 30
	dsb 15,&11  ; 30 frames with tone enabled and noise disabled
	dsb 15,&22  ; 30 frames with tone disabled and noise enabled
	dsb 15,&33  ; 30 frames with tone and noise enabled

MLM_odata_mix_macro2:
	db 1-1 ; Macro length
	db &FF ; Disable looping
	db &02 ; 1 frame with tone disabled and noise enabled

MLM_odata_vol_macro1:
	db 22-1 ; Macro length
	db 13   ; Loop point
	db &21, &43, &65, &87, &A9, &CB, &ED, &FF, &EF, &DD, &DD