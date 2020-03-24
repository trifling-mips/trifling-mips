import math
import random

# file name
PREFIX = "sequential"
PREFIX_SEQU = "sequential"
PREFIX_RAND = "random"
PREFIX_SEQU_RAND = "sequ_rand"
LINE_WIDTH = 256
DATA_WIDTH = 32
LINE_BYTE_OFFSET = int(math.log2(LINE_WIDTH // 8))
DATA_PER_LINE = LINE_WIDTH // DATA_WIDTH
ADDR_WIDTH = 16
# get valid_addr_width
STRB_WIDTH = (DATA_WIDTH // 8)
VALID_ADDR_WIDTH = ADDR_WIDTH - int(math.log2(STRB_WIDTH))
# check valid
assert (VALID_ADDR_WIDTH > 0) and (math.log2(DATA_WIDTH) == int(math.log2(DATA_WIDTH)))
N_REQ = 1000

def getdata(addr, mem_file = "sequential.mem"):
	line_content = ""
	with open(mem_file) as f:
		for i in range(addr):
			f.readline()
		line_content = f.readline().rstrip("\n")
	return line_content

def gen_random_req(n_req = N_REQ):
	# req_file & ans_file & mem_file
	req_file = PREFIX_RAND + ".req"
	ans_file = PREFIX_RAND + ".ans"
	mem_file = PREFIX + ".mem"
	for i in range(n_req):
		# get random addr
		addr = random.randint(0, 2 ** VALID_ADDR_WIDTH - 1)
		with open(req_file, "a") as f:
			fm = "%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x\n"
			f.write(fm % (addr << int(math.log2(STRB_WIDTH))))
		# get corresponding data
		data = getdata(addr, mem_file = mem_file)
		with open(ans_file, "a") as f:
			f.write(data + "\n")

def gen_sequ_req(n_req = N_REQ):
	# req_file & ans_file & mem_file
	req_file = PREFIX_SEQU + ".req"
	ans_file = PREFIX_SEQU + ".ans"
	mem_file = PREFIX + ".mem"
	addr = 1 << (LINE_BYTE_OFFSET - int(math.log2(STRB_WIDTH)))	# label cannot be 0
	for i in range(n_req):
		# get sequ addr
		if addr > 2 ** VALID_ADDR_WIDTH - 1:
			return
		with open(req_file, "a") as f:
			fm = "%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x\n"
			f.write(fm % (addr << int(math.log2(STRB_WIDTH))))
		# get corresponding data
		data = getdata(addr, mem_file = mem_file)
		with open(ans_file, "a") as f:
			f.write(data + "\n")
		addr = addr + 1

def gen_sequ_rand_req(n_req = N_REQ, max_sequ = 30 - 1):
	# req_file & ans_file & mem_file
	req_file = PREFIX_SEQU_RAND + ".req"
	ans_file = PREFIX_SEQU_RAND + ".ans"
	mem_file = PREFIX + ".mem"
	# reset all parameter
	addr = 1 << (LINE_BYTE_OFFSET - int(math.log2(STRB_WIDTH)))	# label cannot be 0
	req_count = 0
	while req_count < n_req:
		# get sequ addr
		if addr > 2 ** VALID_ADDR_WIDTH - 1:
			return
		with open(req_file, "a") as f:
			fm = "%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x\n"
			f.write(fm % (addr << int(math.log2(STRB_WIDTH))))
		# get corresponding data
		data = getdata(addr, mem_file = mem_file)
		with open(ans_file, "a") as f:
			f.write(data + "\n")
		# update req_count
		req_count += 1
		curr_sequ = random.randint(0, max_sequ)
		if (curr_sequ + req_count >= n_req):
			curr_sequ = n_req - req_count
		# update addr
		addr += 1
		for i in range(curr_sequ):
			# get sequ addr
			if addr > 2 ** VALID_ADDR_WIDTH - 1:
				break
			with open(req_file, "a") as f:
				fm = "%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x\n"
				f.write(fm % (addr << int(math.log2(STRB_WIDTH))))
			# get corresponding data
			data = getdata(addr, mem_file = mem_file)
			with open(ans_file, "a") as f:
				f.write(data + "\n")
			addr = addr + 1
			# update req_count
			req_count += 1
		# get random addr
		addr = random.randint(0, 2 ** VALID_ADDR_WIDTH - 1)

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
	gen_random_req()
	gen_sequ_req()
	gen_sequ_rand_req()
