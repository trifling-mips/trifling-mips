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
FLUSH_ENABLE = [True, True, True]
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

def gen_random_req(n_req = N_REQ, en_flush = False):
	# req_file & ans_file & mem_file
	if en_flush:
		req_file = PREFIX_RAND + "_flush" + ".req"
		ans_file = PREFIX_RAND + "_flush" + ".ans"
	else:
		req_file = PREFIX_RAND + ".req"
		ans_file = PREFIX_RAND + ".ans"
	mem_file = PREFIX + ".mem"
	result_lst = []
	valid_lst = []
	if not en_flush:
		for i in range(n_req):
			# get random addr
			addr = random.randint(0, 2 ** VALID_ADDR_WIDTH - 1)
			with open(req_file, "a") as f:
				fm = "%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x 0 0 0\n"
				f.write(fm % (addr << int(math.log2(STRB_WIDTH))))
			# get corresponding data
			data = getdata(addr, mem_file = mem_file)
			with open(ans_file, "a") as f:
				f.write(data + "\n")
	else:
		for i in range(n_req):
			# get random addr
			addr = random.randint(0, 2 ** VALID_ADDR_WIDTH - 1)
			flush_1 = 1 if random.randint(0, 9) == 9 else 0
			flush_2 = 1 if random.randint(0, 9) == 9 else 0
			flush_3 = 1 if random.randint(0, 9) == 9 else 0
			fm = "%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x %01x %01x %01x\n"
			fm = fm % ((addr << int(math.log2(STRB_WIDTH))), flush_1, flush_2, flush_3)
			with open(req_file, "a") as f:
				f.write(fm)
			# get corresponding data
			data = getdata(addr, mem_file = mem_file)
			# set result_lst & valid_lst
			result_lst.append(data)
			valid_lst.append(True)
			if (flush_1 == 1):
				valid_lst[-1] = False
			if (flush_2 == 1 and len(valid_lst) >= 2):
				valid_lst[-2] = False
			if (flush_3 == 1 and len(valid_lst) >= 3):
				valid_lst[-3] = False
		with open(ans_file, "a") as f:
			for i in range(len(valid_lst)):
				if (valid_lst[i]):
					f.write(result_lst[i] + "\n")

def gen_sequ_req(n_req = N_REQ, en_flush = False):
	# req_file & ans_file & mem_file
	if en_flush:
		req_file = PREFIX_SEQU + "_flush" + ".req"
		ans_file = PREFIX_SEQU + "_flush" + ".ans"
	else:
		req_file = PREFIX_SEQU + ".req"
		ans_file = PREFIX_SEQU + ".ans"
	mem_file = PREFIX + ".mem"
	result_lst = []
	valid_lst = []
	addr = 1 << (LINE_BYTE_OFFSET - int(math.log2(STRB_WIDTH)))	# label cannot be 0
	if not en_flush:
		for i in range(n_req):
			# get sequ addr
			if addr > 2 ** VALID_ADDR_WIDTH - 1:
				return
			with open(req_file, "a") as f:
				fm = "%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x 0 0 0\n"
				f.write(fm % (addr << int(math.log2(STRB_WIDTH))))
			# get corresponding data
			data = getdata(addr, mem_file = mem_file)
			with open(ans_file, "a") as f:
				f.write(data + "\n")
			addr = addr + 1
	else:
		for i in range(n_req):
			# get sequ addr
			if addr > 2 ** VALID_ADDR_WIDTH - 1:
				return
			flush_1 = 1 if random.randint(0, 9) == 9 else 0
			flush_2 = 1 if random.randint(0, 9) == 9 else 0
			flush_3 = 1 if random.randint(0, 9) == 9 else 0
			fm = "%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x %01x %01x %01x\n"
			fm = fm % ((addr << int(math.log2(STRB_WIDTH))), flush_1, flush_2, flush_3)
			with open(req_file, "a") as f:
				f.write(fm)
			# get corresponding data
			data = getdata(addr, mem_file = mem_file)
			# set result_lst & valid_lst
			result_lst.append(data)
			valid_lst.append(True)
			if (flush_1 == 1):
				valid_lst[-1] = False
			if (flush_2 == 1 and len(valid_lst) >= 2):
				valid_lst[-2] = False
			if (flush_3 == 1 and len(valid_lst) >= 3):
				valid_lst[-3] = False
			addr = addr + 1
		with open(ans_file, "a") as f:
			for i in range(len(valid_lst)):
				if (valid_lst[i]):
					f.write(result_lst[i] + "\n")

def gen_sequ_rand_req(n_req = N_REQ, max_sequ = 30 - 1, en_flush = False):
	# req_file & ans_file & mem_file
	if en_flush:
		req_file = PREFIX_SEQU_RAND + "_flush" + ".req"
		ans_file = PREFIX_SEQU_RAND + "_flush" + ".ans"
	else:
		req_file = PREFIX_SEQU_RAND + ".req"
		ans_file = PREFIX_SEQU_RAND + ".ans"
	mem_file = PREFIX + ".mem"
	result_lst = []
	valid_lst = []
	# reset all parameter
	addr = 1 << (LINE_BYTE_OFFSET - int(math.log2(STRB_WIDTH)))	# label cannot be 0
	req_count = 0
	while req_count < n_req:
		# get sequ addr
		if addr > 2 ** VALID_ADDR_WIDTH - 1:
			return
		if not en_flush:
			with open(req_file, "a") as f:
				fm = "%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x 0 0 0\n"
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
					fm = "%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x 0 0 0\n"
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
		else:
			flush_1 = 1 if random.randint(0, 9) == 9 else 0
			flush_2 = 1 if random.randint(0, 9) == 9 else 0
			flush_3 = 1 if random.randint(0, 9) == 9 else 0
			fm = "%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x %01x %01x %01x\n"
			fm = fm % ((addr << int(math.log2(STRB_WIDTH))), flush_1, flush_2, flush_3)
			with open(req_file, "a") as f:
				f.write(fm)
			# get corresponding data
			data = getdata(addr, mem_file = mem_file)
			# set result_lst & valid_lst
			result_lst.append(data)
			valid_lst.append(True)
			if (flush_1 == 1):
				valid_lst[-1] = False
			if (flush_2 == 1 and len(valid_lst) >= 2):
				valid_lst[-2] = False
			if (flush_3 == 1 and len(valid_lst) >= 3):
				valid_lst[-3] = False
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
				flush_1 = 1 if random.randint(0, 9) == 9 else 0
				flush_2 = 1 if random.randint(0, 9) == 9 else 0
				flush_3 = 1 if random.randint(0, 9) == 9 else 0
				fm = "%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x %01x %01x %01x\n"
				fm = fm % ((addr << int(math.log2(STRB_WIDTH))), flush_1, flush_2, flush_3)
				with open(req_file, "a") as f:
					f.write(fm)
				# get corresponding data
				data = getdata(addr, mem_file = mem_file)
				# set result_lst & valid_lst
				result_lst.append(data)
				valid_lst.append(True)
				if (flush_1 == 1):
					valid_lst[-1] = False
				if (flush_2 == 1 and len(valid_lst) >= 2):
					valid_lst[-2] = False
				if (flush_3 == 1 and len(valid_lst) >= 3):
					valid_lst[-3] = False
				addr = addr + 1
				# update req_count
				req_count += 1
			# get random addr
			addr = random.randint(0, 2 ** VALID_ADDR_WIDTH - 1)
	if en_flush:
		with open(ans_file, "a") as f:
			for i in range(len(valid_lst)):
				if (valid_lst[i]):
					f.write(result_lst[i] + "\n")

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
	# gen_random_req(en_flush = True)
	# gen_sequ_req(en_flush = True)
	# gen_sequ_rand_req(en_flush = True)
