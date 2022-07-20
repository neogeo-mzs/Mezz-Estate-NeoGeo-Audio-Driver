include ../../Makefile.config

SDATA_MAIN := sdata.s 
SDATA_OUT  := ../sdata.bin
SMP_PATH   := smp

build: vrom
	$(ZASM) -i $(SDATA_MAIN) -o $(SDATA_OUT) -uwy ./listing.txt

vrom:
	$(MAKE) -C $(SMP_PATH)
	$(CP) $(SMP_PATH)/adpcma_sample_lut.bin adpcma_sample_lut.bin

clean:
	$(MAKE) -C $(SMP_PATH) clean
	rm -f listing.txt adpcma_sample_lut.bin