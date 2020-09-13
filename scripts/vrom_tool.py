import sys
import os
import re

vrom = bytearray()
adpcma_smp_lut = bytearray()
vrom_size = 0 # in 256 byte chunks
sys.argv.pop(0)

def str_filter(text):
    return bool(re.match("^[A-Za-z0-9_-]*$", text))

for pcma_filepath in sys.argv:
    pcma_file_label = os.path.splitext(pcma_filepath)[0].replace(" ", "_")
    alphanum_filter = filter(str_filter, pcma_file_label)
    pcma_file_label = "".join(alphanum_filter)
    
    pcma_file = open(pcma_filepath, "rb")
    pcma_size = os.stat(pcma_filepath).st_size
    
    if pcma_size % 256 != 0:
        sys.stderr.write(f"\"{pcma_filepath}\"'s size should be a multiple of 256.\n")
        exit(1)
        
    vrom += pcma_file.read()
    adpcma_smp_lut += vrom_size.to_bytes(length=2, byteorder='little')
    vrom_size += pcma_size//256
    adpcma_smp_lut += (vrom_size-1).to_bytes(length=2, byteorder='little')
    pcma_file.close()

output_file = open("vrom.bin","wb")
output_file.write(vrom)
output_file.close()

header_file = open("adpcma_sample_lut.bin","wb")
header_file.write(adpcma_smp_lut)
header_file.close()
