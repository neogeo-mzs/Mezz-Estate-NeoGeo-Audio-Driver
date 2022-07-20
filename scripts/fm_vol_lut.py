LUT = bytearray()

for i in range(0,128):
	for j in range(0,128):
		byte = round(i * j / 127)
		LUT.append(byte & 0xFF)

output_file = open("fm_vol_lut.bin", "wb")
output_file.write(LUT)