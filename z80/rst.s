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
	;brk2
	push af
		ld     a,d
		out    (YM2610_A0),a
		rst RST_YM_DELAY1
		;call port_write_delay1
		ld     a,e
		out    (YM2610_A1),a
		rst RST_YM_DELAY2
		;call port_write_delay2
	pop af
	ret

port_write_b:
	;brk3
	push af
		ld     a,d
		out    (YM2610_B0),a
		rst RST_YM_DELAY1
		;call port_write_delay1
		ld     a,e
		out    (YM2610_B1),a
		rst RST_YM_DELAY2
		;call port_write_delay2
	pop af
	ret

; [INPUT]
;	a: address
; [OUTPUT]
;	a: data
port_read_a:
	out    (YM2610_A0),a
	rst RST_YM_DELAY1
	;call port_write_delay1
	in    a,(YM2610_A1)
	rst RST_YM_DELAY2
	;call port_write_delay2
	ret