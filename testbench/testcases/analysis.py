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

def analysis_mif(file):
    # cfg for mif
    mif_radix = 2
    assert mif_radix == 2
    # init cnt & get out
    out_file = os.path.splitext(file)[0] + ".out"
    n_line = 0
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
            rline_rd  = int(rline[11:16], mif_radix)
            rline_off = utils.str2sint(rline[16:])
            if (rline_op in ANALYSIS_OP.keys()):
                fm = "%5d %s\t %2x %2x %4x" % (n_line, ANALYSIS_OP[rline_op], rline_rs, rline_rd, rline_off)
                with open(out_file, "a") as out:
                    out.write(fm + "\n")
            else:
                # not record in OP, ignore it
                continue
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
