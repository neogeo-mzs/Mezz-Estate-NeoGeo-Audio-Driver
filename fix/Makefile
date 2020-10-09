######## Mezz'Estate Studios NeoGeo SROM Makefile ########

SFILES := mzs_8x8_font.s1

# Tools
ROMWAK := romwak

ROM_PAD_KBS := 128

build: srom.bin 

srom.bin:
	cat $(SFILES) > srom.tmp.bin
	$(ROMWAK) /p srom.tmp.bin $@ $(ROM_PAD_KBS) 0
	rm srom.tmp.bin

.PHONY: clean

clean: 
	rm -fv srom.bin fix.h
