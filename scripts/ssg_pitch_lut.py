###############################
###### Made by GbaCretin ######
###############################

# LUT from C2 to B7 (for SSG OPNBs)

number_of_octaves = 6
base_pitches = [
#   C2     C#2    D2     D#2    E2     F2
	65.41, 69.30, 73.42, 77.78, 82.41, 87.31,
#   F#2    G2     G#2     A2     A#2     B2
    92.50, 98.00, 103.83, 110.0, 116.54, 123.47]
    
LUT = bytearray()

for octave in range(1, number_of_octaves+1):
	for base_pitch in base_pitches:
		pitch = base_pitch * pow(2,octave)
		SSG_pitch = round(250000 / pitch)

		SSG_pitch_L = SSG_pitch & 0x00FF
		SSG_pitch_H = (SSG_pitch & 0xFF00) >> 8

		# Little endian
		LUT.append(SSG_pitch_L)
		LUT.append(SSG_pitch_H)

		# Big endian
		# LUT.append(SSG_pitch_H)
		# LUT.append(SSG_pitch_L)

file = open("ssg_pitch_lut.bin", "wb")
file.write(LUT)
file.close()
