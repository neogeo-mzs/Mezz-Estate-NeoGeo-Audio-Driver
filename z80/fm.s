fm_stop:
	push de
		ld de,(REG_FM_KEY_ON<<8) | FM_CH1
		rst RST_YM_WRITEA
		ld e,FM_CH2
		rst RST_YM_WRITEA
		ld e,FM_CH3
		rst RST_YM_WRITEA
		ld e,FM_CH4
		rst RST_YM_WRITEA
	pop de
	ret