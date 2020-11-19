######## Mezz'Estate Studios NeoGeo PROM Makefile ########

SFILES := $(wildcard *.s)
CFILES := $(wildcard *.c) $(wildcard neogeo/*.c)

SOBJS := $(SFILES:.s=.o)
COBJS := $(CFILES:.c=.o)
OBJS := $(SOBJS) $(COBJS)

# Tool paths
CROSS    := m68k-neogeo-elf-
AS       := $(CROSS)as
LD       := $(CROSS)gcc
CC       := $(CROSS)gcc
OBJCOPY  := $(CROSS)objcopy
ROMWAK   := romwak

#ASFLAGS :=
CFLAGS  := -std=c99 -fomit-frame-pointer -g -Wall -Wextra -Winline -funsigned-char
LDFLAGS := -specs ngdevkit-specs -Wl,--defsym,rom_eye_catcher_mode=2 

build: prom.bin

prom.bin: prom.elf
	$(OBJCOPY) -v -O binary -S -R .comment $< $@
	dd if=$@ of=$@ conv=notrunc,swab

prom.elf: $(OBJS)
	$(LD) $^ $(LDFLAGS) -o $@

# COBJS are compiled automatically

$(SOBJS): %.o : %.s
	$(AS) $(ASFLAGS) $< -o $@

.PHONY: clean

clean:
	rm -fvr $(OBJS) prom.elf prom.bin history
