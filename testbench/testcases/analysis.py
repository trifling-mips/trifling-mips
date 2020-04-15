import os
import utils

# which op we will ayalysis
ANALYSIS_OP = {
    "100000": "lb",
    "100001": "lh",
    "100010": "lwl",
    "100011": "lw",
    "100100": "lbu",
    "100101": "lhu",
    "100110": "lwr",
    "101011": "sw",
    "101001": "sh",
    "101000": "sb"
}

def parse(file, result):
    # init correlation cnt
    corr_cnt = 0
    # get correlation cnt
    for i in range(1, len(result)):
        if result[i]["n_line"] - 1 == result[i - 1]["n_line"] and result[i - 1]["rline_op"][0] == "l":
            # neighbor may have correlation
            corr_cnt = corr_cnt + 1 if (result[i]["rline_op"][0] == "s" and (result[i]["rline_rs"] == result[i - 1]["rline_rt"] or result[i]["rline_rt"] == result[i - 1]["rline_rt"])) else corr_cnt
            corr_cnt = corr_cnt + 1 if (result[i]["rline_op"][0] == "l" and result[i]["rline_rs"] == result[i - 1]["rline_rt"]) else corr_cnt
    print("corr_cnt : %5d" % corr_cnt)
    # init ls cnt & ll cnt & ss_cnt
    ls_cnt, ls_flag = 0, False
    ll_cnt, ll_flag = 0, False
    ss_cnt, ss_flag = 0, False
    # get ls cnt & ll cnt & ss_cnt
    for i in range(1, len(result)):
        # get ls cnt
        if result[i]["n_line"] - 1 == result[i - 1]["n_line"]:
            # neighbor may have ls
            ls_cnt  = ls_cnt + 1 if result[i]["rline_op"][0] != result[i - 1]["rline_op"][0] and not ls_flag else ls_cnt
            ls_flag = result[i]["rline_op"][0] != result[i - 1]["rline_op"][0]
        else:
            ls_flag = False
        # get ll cnt
        if result[i]["n_line"] - 1 == result[i - 1]["n_line"] and result[i]["rline_op"][0] == result[i - 1]["rline_op"][0]:
            # neighbor may have ll
            ll_cnt  = ll_cnt + 1 if result[i]["rline_op"][0] == "l" and not ll_flag else ll_cnt
            ll_flag = result[i]["rline_op"][0] == "l"
            # neighbor may have ss
            ss_cnt  = ss_cnt + 1 if result[i]["rline_op"][0] == "s" and not ss_flag else ss_cnt
            ss_flag = result[i]["rline_op"][0] == "s"
        else:
            ll_flag = False
            ss_flag = False
    print("ls_cnt   : %5d" % ls_cnt)
    print("ll_cnt   : %5d" % ll_cnt)
    print("ss_cnt   : %5d" % ss_cnt)

def analysis_mif(file):
    # cfg for mif
    mif_radix = 2
    assert mif_radix == 2
    # init cnt & get out
    out_file = os.path.splitext(file)[0] + ".out"
    n_line = 0
    result = []
    with open(file, "r") as f:
        while True:
            # get next line
            rline = f.readline().strip()
            n_line += 1
            if not rline:
                break
            # analysis inst
            # get inst op & inst 
            rline_op  = rline[0:6]
            rline_rs  = int(rline[6:11], mif_radix)
            rline_rt  = int(rline[11:16], mif_radix)
            rline_off = utils.str2sint(rline[16:])
            if (rline_op in ANALYSIS_OP.keys()):
                # update result
                result.append({
                    "n_line"    : n_line,
                    "rline_op"  : ANALYSIS_OP[rline_op],
                    "rline_rs"  : rline_rs,
                    "rline_rt"  : rline_rt,
                    "rline_off" : rline_off
                })
                # fm print
                fm = "%5d %s\t %2x %2x %5x" % (n_line, ANALYSIS_OP[rline_op], rline_rs, rline_rt, rline_off)
                with open(out_file, "a") as out:
                    out.write(fm + "\n")
            else:
                # not record in OP, ignore it
                continue
    # parse result
    parse(file, result)
    print("analysis_mif complete:   " + file)

def analysis_coe(file):
    return
    radix = 16
    with open(file, "r") as f:
        # get radix
        rline = f.readline().strip()
        # TODO
        # ignore this line
        rline = f.readline().strip()
        while True:
            rline = f.readline().strip()
            if not rline:
                break
            print(rline)
    print("analysis_coe complete:   " + file)

# which file we will ayalysis
ANALYSIS_FILE_LIST = {
    ".coe": analysis_coe,
    ".mif": analysis_mif
}
