######## Mezz'Estate Studios NeoGeo M1ROM Makefile ########

# Tools
VASM   := vasmz80_oldstyle
ROMWAK := romwak

SRC := main.s
VASM_FLAGS := -Fbin -nosym

build: m1rom.bin

m1rom.bin: $(SRC)
	$(VASM) $< $(VASM_FLAGS) -o m1rom.tmp.bin -L listing.txt
	$(ROMWAK) /p m1rom.tmp.bin $@ 64 0
	rm -fv m1rom.tmp.bin

.PHONY: clean

clean:
	rm -rfv m1rom.bin history listing.txt adpcma_sample_lut.bin