#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"

void stbtt_GrayscaleToRGBA(const unsigned char *source, unsigned char *destination, int pixel_count)
{
	for (int i = 0; i < pixel_count; ++i)
	{
		const unsigned char coverage = source[i];
		destination[i * 4 + 0] = coverage;
		destination[i * 4 + 1] = coverage;
		destination[i * 4 + 2] = coverage;
		destination[i * 4 + 3] = coverage;
	}
}
