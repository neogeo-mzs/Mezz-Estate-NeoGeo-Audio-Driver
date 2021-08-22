# Tools
MAKE  := make
MV    := mv
CP    := cp
RM    := rm
MAME  := mame
GNGEO := ngdevkit-gngeo
ZIP   := zip
LN    := ln 
NEOSDCONV := neosdconv

PROM_PATH  := 68k
M1ROM_PATH := z80
SROM_PATH  := fix
CROMS_PATH := spr
VROM_PATH  := smp

BUILD_PATH := build
MAME_ROM_PATH=$(HOME)/.mame/roms/neogeo
 
ROM_NAME := puzzledp

build: srom croms vrom m1rom prom
	rm -rf build
	mkdir build
	$(MV) $(PROM_PATH)/prom.bin $(BUILD_PATH)/202-p1.bin
	$(MV) $(M1ROM_PATH)/m1rom.bin $(BUILD_PATH)/202-m1.bin
	$(MV) $(SROM_PATH)/srom.bin $(BUILD_PATH)/202-s1.bin
	$(MV) $(CROMS_PATH)/c1rom.bin $(BUILD_PATH)/202-c1.bin
	$(MV) $(CROMS_PATH)/c2rom.bin $(BUILD_PATH)/202-c2.bin
	$(MV) $(VROM_PATH)/vrom.bin $(BUILD_PATH)/202-v1.bin
	
	$(LN) $(BUILD_PATH)/202-p1.bin $(BUILD_PATH)/202-p1.p1
	$(LN) $(BUILD_PATH)/202-m1.bin $(BUILD_PATH)/202-m1.m1
	$(LN) $(BUILD_PATH)/202-s1.bin $(BUILD_PATH)/202-s1.s1
	$(LN) $(BUILD_PATH)/202-c1.bin $(BUILD_PATH)/202-c1.c1
	$(LN) $(BUILD_PATH)/202-c2.bin $(BUILD_PATH)/202-c2.c2
	$(LN) $(BUILD_PATH)/202-v1.bin $(BUILD_PATH)/202-v1.v1

prom: 
	$(MAKE) -C $(PROM_PATH)

m1rom: vrom
	$(MAKE) -C $(M1ROM_PATH)

srom:
	$(MAKE) -C $(SROM_PATH)

croms:
	$(MAKE) -C $(CROMS_PATH)

vrom:
	$(MAKE) -C $(VROM_PATH)
	$(CP) $(VROM_PATH)/adpcma_sample_lut.bin $(M1ROM_PATH)/adpcma_sample_lut.bin
	#$(CP) vrom.bin $(VROM_PATH)
.PHONY: clean prom m1rom srom croms mame mame_debug gngeo gngeo_debug

clean:
	rm -rfv build history
	$(MAKE) -C $(PROM_PATH) clean
	$(MAKE) -C $(M1ROM_PATH) clean
	$(MAKE) -C $(SROM_PATH) clean
	$(MAKE) -C $(CROMS_PATH) clean
	$(MAKE) -C $(VROM_PATH) clean

mame: build
	$(RM) -rf $(MAME_ROM_PATH)/$(ROM_NAME)
	$(CP) -r $(BUILD_PATH) $(MAME_ROM_PATH)/$(ROM_NAME)
	$(MAME) neogeo $(ROM_NAME) -window -prescale 3 $(mame_args)

mame_debug: build
	$(RM) -rf $(MAME_ROM_PATH)/$(ROM_NAME)
	$(CP) -r $(BUILD_PATH) $(MAME_ROM_PATH)/$(ROM_NAME)
	$(MAME) neogeo $(ROM_NAME) -window -prescale 3 -debug $(mame_args)

gngeo: build
	$(ZIP) -r -j $(BUILD_PATH)/puzzledp.zip $(BUILD_PATH)/*.bin
	$(CP) neogeo.zip $(BUILD_PATH)/neogeo.zip 
	$(GNGEO) -i$(BUILD_PATH) --scale=3 --screen320 puzzledp

gngeo_debug: build
	$(ZIP) -r -j $(BUILD_PATH)/puzzledp.zip $(BUILD_PATH)/*.bin
	$(CP) neogeo.zip $(BUILD_PATH)/neogeo.zip 
	$(GNGEO) -i$(BUILD_PATH) --scale=2 --screen320 -D puzzledp

neosdconv: build
	rm $(BUILD_PATH)/*.bin
	$(NEOSDCONV) -i $(BUILD_PATH) -o $(BUILD_PATH)/build.neo -n homebrew -y 2021 -m "Mezz'Estate"
	
ifneq ($(strip $(NEOSD_ROM_PATH)),)
	echo "Moving neo rom to SD card"
	rm -f $(NEOSD_ROM_PATH)/build.neo
	$(CP) $(BUILD_PATH)/build.neo $(NEOSD_ROM_PATH)/build.neo
endif
