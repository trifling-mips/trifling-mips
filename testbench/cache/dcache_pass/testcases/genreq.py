import math
import random

# file name
PREFIX = "sequential"
PREFIX_RAND = "random"
ENABLE_MEM_CPY = True
MEM_CPY = []
DATA_WIDTH = 32
ADDR_WIDTH = 16
FLUSH_ENABLE = [True, True, True]
# get valid_addr_width
STRB_WIDTH = (DATA_WIDTH // 8)
VALID_ADDR_WIDTH = ADDR_WIDTH - int(math.log2(STRB_WIDTH))
# check valid
assert (VALID_ADDR_WIDTH > 0) and (math.log2(DATA_WIDTH) == int(math.log2(DATA_WIDTH)))
N_REQ = 1000

def getdata(addr):
	assert addr < 2 ** VALID_ADDR_WIDTH
	global MEM_CPY
	return MEM_CPY[addr]

def wrdata(addr, wbe, wrdata):
	global MEM_CPY
	muxdata = list(MEM_CPY[addr])
	for i in range(len(wbe)):
		if wbe[i] == 1:
			# enable
			muxdata[len(muxdata) - 2 * i - 1] = wrdata[len(muxdata) - 2 * i - 1]
			muxdata[len(muxdata) - 2 * i - 2] = wrdata[len(muxdata) - 2 * i - 2]
	MEM_CPY[addr] = "".join(muxdata)

def lst2num(lst):
	result = 0
	# print(lst)
	for i in reversed(range(len(lst))):
		result <<= 1
		if (lst[i] == 1):
			result += lst[i] & 1
	# print(result)
	return result

def gen_random_req(n_req = N_REQ):
	# req_file & ans_file & mem_file
	req_file = PREFIX_RAND + ".req"
	ans_file = PREFIX_RAND + ".ans"
	index = 0
	while index < n_req:
		# get random addr
		ls_type = random.randint(0, 1)	# load - 1, store - 0
		addr = random.randint(0, 2 ** VALID_ADDR_WIDTH - 1)
		wdata = ("%0" + str(DATA_WIDTH // 4) + "x") % random.randint(0, 2 ** DATA_WIDTH - 1)
		wbe = []
		for j in range(STRB_WIDTH):
			wbe.append(random.randint(0, 1))
		index += 1
		with open(req_file, "a") as freq:
			fm = "%01x %01x %0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x %s\n"
			if ls_type == 1:	# load
				wbe = []
				for j in range(STRB_WIDTH):
					wbe.append(0)
				wdata = ("%0" + str(DATA_WIDTH // 4) + "x") % 0
			freq.write(fm % (ls_type, lst2num(wbe), addr, wdata))
			# get corresponding data
			if ls_type == 1:	# load
				rdata = getdata(addr)
				fm = "%01x-%01x-%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x-%s\n"
				with open(ans_file, "a") as f:
					f.write(fm % (1, lst2num(wbe), addr, rdata))
			else:
				fm = "%01x-%01x-%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x-%s\n"
				with open(ans_file, "a") as f:
					f.write(fm % (1, lst2num(wbe), addr, wdata))
				wrdata(addr, wbe, wdata)
				if random.randint(0, 1) == 1:
					if index < n_req:
						fm = "%01x %01x %0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x %s\n"
						ls_type = 1
						wbe = []
						for j in range(STRB_WIDTH):
							wbe.append(0)
						wdata = ("%0" + str(DATA_WIDTH // 4) + "x") % 0
						freq.write(fm % (ls_type, lst2num(wbe), addr, wdata))
						rdata = getdata(addr)
						fm = "%01x-%01x-%0" + str(math.ceil(VALID_ADDR_WIDTH / 4)) + "x-%s\n"
						with open(ans_file, "a") as f:
							f.write(fm % (1, lst2num(wbe), addr, rdata))
						index += 1

def sequential():
	# mem_file
	global MEM_CPY
	mem_file = PREFIX + ".mem"
	# gen mem
	with open(mem_file, "w") as f:
		for i in range(2 ** VALID_ADDR_WIDTH):
			fm = "%0" + str(math.ceil(DATA_WIDTH / 4)) + "x\n"
			f.write(fm % i)
	if ENABLE_MEM_CPY:
		MEM_CPY = []
		for i in range(2 ** VALID_ADDR_WIDTH):
			fm = "%0" + str(math.ceil(DATA_WIDTH / 4)) + "x"
			MEM_CPY.append(fm % i)

if __name__ == "__main__":
	sequential()
	gen_random_req()
