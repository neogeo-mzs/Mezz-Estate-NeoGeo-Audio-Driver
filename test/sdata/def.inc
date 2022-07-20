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