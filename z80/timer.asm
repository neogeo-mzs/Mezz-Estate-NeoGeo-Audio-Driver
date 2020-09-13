; Timer A set counter load
; bc: counter
TMA_set_counter_load:
	push de
	push bc
		; Writes LSBs of counter to the YM2610
		ld d,REG_TMA_COUNTER_LSB
		ld e,c
		rst RST_YM_WRITEA

		; Writes MSBs of counter to the YM2610
		ld d,REG_TMA_COUNTER_MSB
		ld e,b
		rst RST_YM_WRITEA

		; clear Timer A counter and
		; copy load timer value into
		; the counter
		ld d,REG_TIMER_CNT
		ld e,%00010101
		rst RST_YM_WRITEA
	pop bc
	pop de
	ret

; Timer B set counter load
; e: counter
TMB_set_counter_load:
	push de
		; Writes LSBs of counter to the YM2610
		ld d,REG_TMB_COUNTER ; reg address
		rst RST_YM_WRITEA

		; clear Timer B counter and
		; copy load timer value into
		; the counter
		ld d,REG_TIMER_CNT
		ld e,%00101010
		rst RST_YM_WRITEA
	pop de
	ret