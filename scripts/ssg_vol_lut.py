LUT = bytearray()

for i in range(0,16):
	print(f"==== VOLUME {i} ====")
	for j in range(0,16,2):
		byte = round(i * (j+1) / 15) | (round(i * j / 15) << 4)
		#print("0x{:02X}".format(byte))
		LUT.append(byte & 0xFF)

output_file = open("ssg_vol_lut.bin", "wb")
output_file.write(LUT)