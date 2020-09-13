;Inputs:
;     H,E
;Outputs:
;     HL is the product
;     D,B are 0
;     A,E,C are preserved
;Size:  38 bytes
;Speed: 198+6b+9p-7s, b is the number of bits set in the input H, p is if it is odd, s is the upper bit of h
;   average is 226.5 cycles (108.5 cycles saved)
;   max required is 255 cycles (104 cycles saved)
H_Times_E:
     ld d,0      ;1600   7   7
     ld l,d      ;6A     4   4
     ld b,8      ;0608   7   7
           ;      
     sla h   ;   8
     jr nc,$+3   ;3001  12-b
     ld l,e   ;6B    --

     add hl,hl   ;29    11
     jr nc,$+3   ;3001  12+6b
     add hl,de   ;19    --

     add hl,hl   ;29    11
     jr nc,$+3   ;3001  12+6b
     add hl,de   ;19    --

     add hl,hl   ;29    11
     jr nc,$+3   ;3001  12+6b
     add hl,de   ;19    --

     add hl,hl   ;29    11
     jr nc,$+3   ;3001  12+6b
     add hl,de   ;19    --

     add hl,hl   ;29    11
     jr nc,$+3   ;3001  12+6b
     add hl,de   ;19    --

     add hl,hl   ;29    11
     jr nc,$+3   ;3001  12+6b
     add hl,de   ;19    --

     add hl,hl   ;29   11
     ret nc      ;D0   11+15p
     add hl,de   ;19   --
     ret         ;C9   --

;Inputs:
;     HL is the numerator
;     C is the denominator
;Outputs:
;     A is the remainder
;     B is 0
;     C is not changed
;     DE is not changed
;     HL is the quotient
;
HL_Div_C:
       ld b,16
       xor a
         add hl,hl
         rla
         cp c
         jr c,$+4
           inc l
           sub c
         djnz $-7
       ret

;Inputs:
;     HL is the numerator
;     C is the denominator
;Outputs:
;     A is twice the remainder of the unrounded value 
;     B is 0
;     C is not changed
;     DE is not changed
;     HL is the rounded quotient
;     c flag set means no rounding was performed
;            reset means the value was rounded
;
RoundHL_Div_C:
       ld b,16
       xor a
         add hl,hl
         rla
         cp c
         jr c,$+4
           inc l
           sub c
         djnz $-7
       add a,a
       cp c
       jr c,$+3
         inc hl
       ret

DE_Div_BC:          ;1281-2x, x is at most 16
     ld a,16        ;7
     ld hl,0        ;10
     jp $+5         ;10
DivLoop:
       add hl,bc    ;--
       dec a        ;64
       ret z        ;86

       sla e        ;128
       rl d         ;128
       adc hl,hl    ;240
       sbc hl,bc    ;240
       jr nc,DivLoop ;23|21
       inc e        ;--
       jp DivLoop+1