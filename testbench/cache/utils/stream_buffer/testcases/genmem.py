import math

def sequential(DATA_WIDTH = 32, ADDR_WIDTH = 16):
	# file name
	FILE_NAME = "sequential.mem"
	# get valid_addr_width
	STRB_WIDTH = (DATA_WIDTH // 8)
	VALID_ADDR_WIDTH = ADDR_WIDTH - int(math.log2(STRB_WIDTH))
	# check valid
	assert (VALID_ADDR_WIDTH > 0) and (math.log2(DATA_WIDTH) == int(math.log2(DATA_WIDTH)))
	# gen mem
	with open(FILE_NAME, "w") as f:
		for i in range(2 ** VALID_ADDR_WIDTH):
			fm = "%0" + str(DATA_WIDTH // 4) + "x\n"
			f.write(fm % i)

if __name__ == "__main__":
	sequential()
