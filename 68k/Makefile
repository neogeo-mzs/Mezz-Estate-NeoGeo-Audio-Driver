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
NGDEVKIT := /home/gbacretin/Software/ngdevkit
ROMWAK   := romwak

#ASFLAGS :=
CFLAGS  := -std=c99 -fomit-frame-pointer -g -Wall -Wextra -Winline -funsigned-char
LDFLAGS := -L$(NGDEVKIT)/local/m68k-neogeo-elf/lib -specs ngdevkit-specs

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
