import math
import random

# file name
PREFIX = "sequential"
LINE_WIDTH = 256
DATA_WIDTH = 32
DATA_PER_LINE = LINE_WIDTH // DATA_WIDTH
ADDR_WIDTH = 16
# get valid_addr_width
STRB_WIDTH = (DATA_WIDTH // 8)
VALID_ADDR_WIDTH = ADDR_WIDTH - int(math.log2(STRB_WIDTH))
LABEL_WIDTH = VALID_ADDR_WIDTH - int(math.log2(DATA_PER_LINE))
# print(ADDR_WIDTH, VALID_ADDR_WIDTH, LABEL_WIDTH)
# check valid
assert (VALID_ADDR_WIDTH > 0) and (math.log2(DATA_WIDTH) == int(math.log2(DATA_WIDTH)))
N_REQ = 1000

def getdata(addr, mem_file = "sequential.mem"):
	line_content = ""
	with open(mem_file) as f:
		for i in range(addr):
			f.readline()
		for i in range(DATA_PER_LINE):
			line_content = f.readline().rstrip("\n") + line_content
	return line_content

def gen_random_req():
	# req_file & ans_file & mem_file
	req_file = PREFIX + ".req"
	ans_file = PREFIX + ".ans"
	mem_file = PREFIX + ".mem"
	# get random label
	label = random.randint(0, 2 ** LABEL_WIDTH - 2)
	with open(req_file, "a") as f:
		fm = "%0" + str(math.ceil(LABEL_WIDTH / 4)) + "x\n"
		f.write(fm % label)
	# get corresponding data
	# data = getdata(((label + 1) << int(math.log2(DATA_PER_LINE))), mem_file = mem_file)
	data = getdata((label << int(math.log2(DATA_PER_LINE))), mem_file = mem_file)
	with open(ans_file, "a") as f:
		f.write(data + "\n")

def sequential():
	# mem_file
	mem_file = PREFIX + ".mem"
	# gen mem
	with open(mem_file, "w") as f:
		for i in range(2 ** VALID_ADDR_WIDTH):
			fm = "%0" + str(math.ceil(DATA_WIDTH / 4)) + "x\n"
			f.write(fm % i)

if __name__ == "__main__":
	sequential()
	for i in range(N_REQ):
		gen_random_req()
