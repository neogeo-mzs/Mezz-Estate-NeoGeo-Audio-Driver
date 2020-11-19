# Tools
MAKE  := make
MV    := mv
CP    := cp
RM    := rm
MAME  := mame
GNGEO := ngdevkit-gngeo
ZIP   := zip

PROM_PATH  := 68k
M1ROM_PATH := z80
SROM_PATH  := fix
CROMS_PATH := spr
VROM_PATH  := smp

BUILD_PATH := build
MAME_ROM_PATH=$(HOME)/.mame/roms/neogeo
 
ROM_NAME := homebrew

build: srom croms vrom m1rom prom
	rm -rf build
	mkdir build
	$(MV) $(PROM_PATH)/prom.bin $(BUILD_PATH)/prom.bin
	$(MV) $(M1ROM_PATH)/m1rom.bin $(BUILD_PATH)/m1rom.bin
	$(MV) $(SROM_PATH)/srom.bin $(BUILD_PATH)/srom.bin
	$(MV) $(CROMS_PATH)/c1rom.bin $(BUILD_PATH)/c1rom.bin
	$(MV) $(CROMS_PATH)/c2rom.bin $(BUILD_PATH)/c2rom.bin
	$(MV) $(VROM_PATH)/vrom.bin $(BUILD_PATH)/vrom.bin
	
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
	$(ZIP) -r -j $(BUILD_PATH)/homebrew.zip $(BUILD_PATH)/*.bin
	$(CP) neogeo.zip $(BUILD_PATH)/neogeo.zip 
	$(GNGEO) -i$(BUILD_PATH) --scale=3 homebrew

gngeo_debug: build
	$(ZIP) -r -j $(BUILD_PATH)/homebrew.zip $(BUILD_PATH)/*.bin
	$(CP) neogeo.zip $(BUILD_PATH)/neogeo.zip 
	$(GNGEO) -i$(BUILD_PATH) --scale=1 -D homebrew