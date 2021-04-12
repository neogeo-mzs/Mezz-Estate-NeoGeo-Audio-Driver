port_write_delay1:
	ret

port_write_delay2:
	push bc     
	push de     
	push hl     
	pop  hl     
	pop  de     
	pop  bc
	ret

port_write_a:
	push af
		ld     a,d
		out    (YM2610_A0),a
		rst RST_YM_DELAY1
		ld     a,e
		out    (YM2610_A1),a
		rst RST_YM_DELAY2
	pop af
	ret

port_write_b:
	push af
		ld     a,d
		out    (YM2610_B0),a
		rst RST_YM_DELAY1
		ld     a,e
		out    (YM2610_B1),a
		rst RST_YM_DELAY2
	pop af
	ret