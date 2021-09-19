
# Tool
ROMWAK    := romwak
ADPCMA    := adpcma
ADPCMB    := adpcmb
VROM_TOOL := python3 ../scripts/vrom_tool.py
MV        := mv

RAW_ADPCMA_FILES := GRAND_PIANO_C3.raw GRAND_PIANO_C\#3.raw GRAND_PIANO_D3.raw GRAND_PIANO_D\#3.raw GRAND_PIANO_E3.raw GRAND_PIANO_F3.raw \
                    GRAND_PIANO_F\#3.raw GRAND_PIANO_G3.raw GRAND_PIANO_G\#3.raw GRAND_PIANO_A3.raw GRAND_PIANO_A\#3.raw GRAND_PIANO_B3.raw \
					NECOARC.raw
                    
PCMA_FILES := $(RAW_ADPCMA_FILES:.raw=.pcma)

build: vrom.bin

vrom.bin: $(PCMA_FILES)
	$(VROM_TOOL) $(PCMA_FILES) 
	$(ROMWAK) /p vrom.bin vrom.bin 16383 128
	$(ROMWAK) /p adpcma_sample_lut.bin adpcma_sample_lut.bin 2 0

$(PCMA_FILES): %.pcma : %.raw
	$(ADPCMA) $< $@
	
.PHONY: clean

clean:
	rm -fv vrom.bin
	rm -fv $(PCMA_FILES)
	rm -fv vrom.bin vrom.h
