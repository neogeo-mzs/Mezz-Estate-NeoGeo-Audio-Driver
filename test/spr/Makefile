C1FILES := example_sprite.c1
C2FILES := $(C1FILES:.c1=.c2)

# tools
ROMWAK := romwak

# In kb
PADDING := 1024

build: c1rom.bin c2rom.bin

c1rom.bin:
	cat $(C1FILES) > c1rom.tmp.bin
	$(ROMWAK) /p c1rom.tmp.bin $@ $(PADDING) 0
	rm c1rom.tmp.bin

c2rom.bin:
	cat $(C2FILES) > c2rom.tmp.bin
	$(ROMWAK) /p c2rom.tmp.bin $@ $(PADDING) 0
	rm c2rom.tmp.bin

.PHONY: clean

clean:
	rm -fv c1rom.bin c2rom.bin
