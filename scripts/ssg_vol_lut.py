LUT = bytearray()

for i in range(0,16):
	for j in range(0,16):
		byte = round(i * j / 15)
		LUT.append(byte & 0xFF)

output_file = open("ssg_vol_lut.bin", "wb")
output_file.write(LUT)