import math
import random

# file name
SET_ASSOC = 4
N_REQ = 1000
PREFIX_PLRU = "plru"
PREFIX_REPL_FIFO = "repl_fifo"

class plru:

	def __init__(self):
		self.state = []
		for i in range(SET_ASSOC - 1):
			self.state.append(0)

	def update_stat(self, access, update):
		if update == 1:
			for i in reversed(range(len(access))):
				if access[i] == 1:
					for j in range(int(math.log2(SET_ASSOC))):
						self.state[(2 ** j) - 1 + (i // (2 ** (int(math.log2(SET_ASSOC)) - j)))] = 0 if ((i % (2 ** (int(math.log2(SET_ASSOC)) - j))) >= (2 ** (int(math.log2(SET_ASSOC)) - j - 1))) else 1
					break

	def get_stat(self):
		# print(self.state)
		repl_index = self._get_stat_helper(0, 0)
		# print(repl_index)
		return repl_index

	def _get_stat_helper(self, value, index):
		if (index + 1 >= SET_ASSOC // 2):
			# final state
			return (value << 1) + self.state[index]
		else:
			value = (value << 1) + self.state[index]
			return self._get_stat_helper(value, (index * 2 + 2) if self.state[index] == 1 else (index * 2 + 1))

def numlst2num(numlst):
	# binary
	result = 0
	for i in reversed(range(len(numlst))):
		result <<= 1
		result += numlst[i] & 1
	return result

def gen_plru_req(n_req = N_REQ):
	# file_name
	req_file = PREFIX_PLRU + ".req"
	ans_file = PREFIX_PLRU + ".ans"
	# gen plru unit
	plru_inst = plru()
	# gen req
	for i in range(n_req):
		update = 0 if random.randint(0, 9) == 9 else 1
		access = []
		for j in range(SET_ASSOC):
			access.append(0)
		access_index = random.randint(0, SET_ASSOC - 1)
		access[access_index] = 1
		if random.randint(0, 9) == 9:
			access_index = random.randint(0, SET_ASSOC - 1)
			access[access_index] = 1
		with open(req_file, "a") as f:
			fm = "%0" + str(math.ceil(SET_ASSOC / 8)) + "x %01x\n"
			f.write(fm % (numlst2num(access), update))
		# update state
		plru_inst.update_stat(access, update)
		# get state
		repl_index = plru_inst.get_stat()
		with open(ans_file, "a") as f:
			fm = "%0" + str(math.ceil(math.log2(SET_ASSOC) / 8)) + "x\n"
			f.write(fm % repl_index)

if __name__ == "__main__":
	gen_plru_req()
	# gen_
