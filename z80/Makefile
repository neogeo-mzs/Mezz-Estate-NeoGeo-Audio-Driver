######## Mezz'Estate Studios NeoGeo M1ROM Makefile ########

# Tools
ROMWAK := romwak

SRC := main.s

build: m1rom.bin

m1rom.bin: $(SRC)
	zasm -i $< -o m1rom.tmp.bin -uwy -l listing.txt
	$(ROMWAK) /p m1rom.tmp.bin $@ 128 0
	rm -fv m1rom.tmp.bin

.PHONY: clean

clean:
	rm -rfv m1rom.bin history listing.txt adpcma_sample_lut.bin