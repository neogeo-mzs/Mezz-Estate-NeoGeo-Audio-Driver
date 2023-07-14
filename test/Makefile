include ../Makefile.config

TEST_SRC_PATH  := src
SROM_PATH  := fix
CROMS_PATH := spr
SDATA_PATH := sdata

BUILD_PATH := build
MAME_ROM_PATH=$(HOME)/.mame/roms/neogeo
 
ROM_NAME := homebrew

.PHONY: clean build run debug neosdconv sdata

build: prom srom croms m1rom
	rm -rf build
	mkdir build
	$(MV) $(TEST_SRC_PATH)/prom.bin $(BUILD_PATH)/prom.bin
	$(MV) $(SROM_PATH)/srom.bin $(BUILD_PATH)/srom.bin
	$(MV) $(CROMS_PATH)/c1rom.bin $(BUILD_PATH)/c1rom.bin
	$(MV) $(CROMS_PATH)/c2rom.bin $(BUILD_PATH)/c2rom.bin
	$(MV) m1rom.bin $(BUILD_PATH)/m1rom.bin
	$(CP) vrom.bin $(BUILD_PATH)/vrom.bin
	
	$(CP) $(BUILD_PATH)/prom.bin $(BUILD_PATH)/202-p1.p1
	$(CP) $(BUILD_PATH)/m1rom.bin $(BUILD_PATH)/202-m1.m1
	$(CP) $(BUILD_PATH)/srom.bin $(BUILD_PATH)/202-s1.s1
	$(CP) $(BUILD_PATH)/c1rom.bin $(BUILD_PATH)/202-c1.c1
	$(CP) $(BUILD_PATH)/c2rom.bin $(BUILD_PATH)/202-c2.c2
	$(CP) $(BUILD_PATH)/vrom.bin $(BUILD_PATH)/202-v1.v1

prom: 
	$(MAKE) -C $(TEST_SRC_PATH)

srom:
	$(MAKE) -C $(SROM_PATH)

croms:
	$(MAKE) -C $(CROMS_PATH)

m1rom: 
	$(ROMWAK) /c ../driver.m1 sdata.bin m1rom.tmp.bin
	$(ROMWAK) /p m1rom.tmp.bin m1rom.bin 512 255
	rm m1rom.tmp.bin

clean:
	rm -rfv build history sdata.bin vrom.bin 
	$(MAKE) -C $(TEST_SRC_PATH) clean
	$(MAKE) -C $(SROM_PATH) clean
	$(MAKE) -C $(CROMS_PATH) clean
	$(MAKE) -C $(SDATA_PATH) clean

run: build
	$(RM) -r $(MAME_ROM_PATH)/$(ROM_NAME)
	$(CP) -r $(BUILD_PATH) $(MAME_ROM_PATH)/$(ROM_NAME)
	$(MAME) neogeo $(ROM_NAME) -window -prescale 1 $(mame_args)

debug: build
	$(RM) -rf $(MAME_ROM_PATH)/$(ROM_NAME)
	$(CP) -r $(BUILD_PATH) $(MAME_ROM_PATH)/$(ROM_NAME)
	$(MAME) neogeo $(ROM_NAME) -window -debug $(mame_args)

neosdconv: build
	rm $(BUILD_PATH)/*.bin
	$(NEOSDCONV) -i $(BUILD_PATH) -o $(BUILD_PATH)/build.neo -n homebrew -y 2023 -m "StereoMimi"
	
ifneq ($(strip $(NEOSD_ROM_PATH)),)
	echo "Moving neo rom to SD card"
	rm -f "$(NEOSD_ROM_PATH)/build.neo"
	$(CP) "$(BUILD_PATH)/build.neo" "$(NEOSD_ROM_PATH)/build.neo"
endif

sdata:
	$(MAKE) -C $(SDATA_PATH)
	$(MV) $(SDATA_PATH)/smp/vrom.bin vrom.bin