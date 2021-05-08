LUT = bytearray()

for i in range(0,16):
	print(f"==== VOLUME {i} ====")
	for j in range(0,16):
		byte = round(i * j / 15)
		print("0x{:01X}".format(byte))
		LUT.append(byte & 0xFF)

output_file = open("ssg_vol_lut.bin", "wb")
output_file.write(LUT)