# Tools
MAKE   := make
MV     := mv
CP     := cp
RM     := rm
DD     := dd
ZASM   := zasm
ROMWAK := romwak
PYTHON := python3

SRC_PATH  := src
SRC_MAIN  := $(SRC_PATH)/main.s
SRC_OUT   := driver.m1
LIST_PATH := $(SRC_PATH)/listing.txt
SCRIPT_PATH := scripts

.PHONY: clean build

build: LUT
	$(ZASM) -i $(SRC_MAIN) -o $(SRC_OUT).tmp -uwy -l ./$(LIST_PATH)
	$(DD) if=./$(SRC_OUT).tmp of=./$(SRC_OUT) bs=1024 count=24
	$(RM) $(SRC_OUT).tmp

LUT:
	$(PYTHON) $(SCRIPT_PATH)/fm_vol_lut.py
	$(MV) fm_vol_lut.bin $(SRC_PATH)
	$(PYTHON) $(SCRIPT_PATH)/ssg_pitch_lut.py
	$(MV) ssg_pitch_lut.bin $(SRC_PATH)
	$(PYTHON) $(SCRIPT_PATH)/ssg_vol_lut.py
	$(MV) ssg_vol_lut.bin $(SRC_PATH)

clean:
	$(RM) -f $(SRC_OUT).tmp $(SRC_OUT) $(LIST_PATH) $(SRC_PATH)/fm_vol_lut.bin $(SRC_PATH)/ssg_pitch_lut.bin $(SRC_PATH)/ssg_vol_lut.bin