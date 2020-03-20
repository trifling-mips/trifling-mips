import math
import random

LINE_WIDTH = 256
DATA_WIDTH = 32
LINE_DEPTH = 8
BYTE_WIDTH = 8
DATA_HEX_WIDTH = math.ceil(DATA_WIDTH / 4)
BYTE_HEX_WIDTH = math.ceil(BYTE_WIDTH / 4)
WBE_WIDTH = LINE_WIDTH // BYTE_WIDTH
WBE_HEX_WIDTH = math.ceil(WBE_WIDTH / 4)
LINE_BYTE_OFFSET = int(math.log2(LINE_WIDTH // 8))
LINE_HEX_WIDTH = math.ceil((LINE_WIDTH / 4))
# print(LINE_WIDTH, LINE_HEX_WIDTH)
ADDR_WIDTH = 32
LABEL_WIDTH = ADDR_WIDTH - LINE_BYTE_OFFSET
LABEL_HEX_WIDTH = math.ceil(LABEL_WIDTH / 4)
# print(LABEL_WIDTH, LABEL_HEX_WIDTH)
label_list = []
mem_list = []
req_list = ["push", "pop", "pp", "write"]

def label_in_lst(label):
	if len(label_list) == 0:
		return False
	for i in range(len(label_list)):
		label_int = int(label_list[i], 16)
		if (label_int == label):
			return True
	return False

def gen_label_in_lst():
	label_idx = random.randint(0, len(label_list) - 1)
	return int(label_list[label_idx], 16)

def gen_label_not_in_lst():
	label = random.randint(0, 2 ** LABEL_WIDTH - 1)
	while (label_in_lst(label)):
		label = random.randint(0, 2 ** LABEL_WIDTH - 1)
	return label

def gen_random_data():
	data = ""
	for i in range(LINE_HEX_WIDTH):
		temp_data = random.randint(0, 16 - 1)
		fm_data = "%x" % temp_data
		# print(fm_data, temp_data)
		data += fm_data
	# print(len(data))
	return data

def gen_random_wbe():
	wbe = []
	wbe_idx = random.randint(0, WBE_WIDTH - 1)
	for i in range(WBE_WIDTH):
		if i == wbe_idx:
			wbe.append(True)
		else:
			wbe.append(False)
	return wbe

def gen_compl_req(req):
	fm = "%0" + str(LABEL_HEX_WIDTH) + "x"
	if (req == 0):
		# push
		label = gen_label_not_in_lst()
		data = gen_random_data()
		return (req, fm % label, data, "")
	elif (req == 1):
		# pop
		return (req, "", "", "")
	elif (req == 2):
		# pp
		label_push = gen_label_not_in_lst()
		data = gen_random_data()
		return (req, fm % label_push, data, "")
	else:
		# write
		label = gen_label_in_lst()
		data = gen_random_data()
		wbe = gen_random_wbe()
		return (req, fm % label, data, wbe)

def gen_rand_req():
	if (len(mem_list)) == 0:
		return 0
	elif (len(mem_list)) == LINE_DEPTH:
		return random.randint(1, len(req_list) - 1)
	else:
		return random.randint(0, len(req_list) - 1)

def wbe2str(wbe):
	wbe_int = 0
	fm = "%0" + str(WBE_HEX_WIDTH) + "x"
	if (len(wbe)) == 0:
		return fm % wbe_int
	else:
		for i in reversed(range(len(wbe))):
			wbe_int <<= 1
			if wbe[i]:
				wbe_int += 1
		return fm % wbe_int

def write_req(req, req_file):
	if req[0] == 0:
		# push
		fm = "push %s %s 0" % (req[1], req[2],)
	elif req[0] == 1:
		# pop
		fm = "pop 0 0 0"
	elif req[0] == 2:
		# pp
		fm = "pp %s %s 0" % (req[1], req[2],)
	else:
		# write
		fm = "write %s %s %s" % (req[1], req[2], wbe2str(req[3]),)
	fm_output = fm + "\n"
	with open(req_file, "a") as f:
		f.write(fm_output)

def mux_wbe(rdata, wdata, wbe):
	muxdata = ""
	step = BYTE_HEX_WIDTH
	for i in range(len(wbe)):
		rev_i = len(wbe) - 1 - i
		if (wbe[rev_i]):
			muxdata += wdata[step * i: step * i + step]
		else:
			muxdata += rdata[step * i: step * i + step]
	# print(len(muxdata))
	return muxdata

def setmem(n_line, wdata, wlabel = 0):
	if n_line > len(mem_list):
		print("[ERROR] setmem index(%d) is greater than mem_list(%d)" % n_line, len(mem_list))
		return False
	elif n_line == len(mem_list):
		mem_list.append(wdata)
		label_list.append(wlabel)
		return True
	else:
		mem_list[n_line] = wdata
		return True

def getmem(label):
	for i in range(len(mem_list)):
		if label_list[i] == label:
			return (True, i, mem_list[i])
	return (False, None, None)

def exe_req(req, ans_file):
	resp = "skip"
	if (req[0] == 0):
		# push
		if (len(mem_list) == LINE_DEPTH):
			pass
		else:
			setmem(len(mem_list), req[2], req[1])
			resp = label_list[0] + "-" + mem_list[0]
	elif (req[0] == 1):
		# pop
		label_list.pop(0)
		mem_list.pop(0)
		if (len(mem_list) > 0):
			resp = label_list[0] + "-" + mem_list[0]
	elif (req[0] == 2):
		# pp
		label_list.pop(0)
		mem_list.pop(0)
		setmem(len(mem_list), req[2], req[1])
		resp = label_list[0] + "-" + mem_list[0]
	else:
		# write
		(flag, index, rdata) = getmem(req[1])
		if not flag:
			pass
		else:
			muxdata = mux_wbe(rdata, req[2], req[3])
			setmem(index, muxdata, req[1])
			resp = label_list[0] + "-" + mem_list[0]
	with open(ans_file, "a") as f:
		f.write(resp + "\n")

def pop_all(req_file, ans_file):
	while (len(mem_list)) > 0:
		req = 1		# pop
		compl_req = gen_compl_req(req)
		write_req(compl_req, req_file)
		exe_req(compl_req, ans_file)

def genreq(prefix = "random", n_req = 1000):
	# file name
	REQ_FILE = prefix + ".req"
	ANS_FILE = prefix + ".ans"
	# get req & ans
	for epoch in range(n_req):
		req = gen_rand_req()
		compl_req = gen_compl_req(req)
		write_req(compl_req, REQ_FILE)
		exe_req(compl_req, ANS_FILE)
	pop_all(REQ_FILE, ANS_FILE)

if __name__ == "__main__":
	genreq()
