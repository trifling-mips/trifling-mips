import os
import analysis

def str2sint(src):
    assert len(src) > 1
    tar = list(src)
    # print(tar)
    if tar[0] == "1":
        for i in range(len(tar)):
            tar[i] = "0" if tar[i] == "1" else "1"
        # print(tar)
        return -(int("".join(tar), 2) + 1)
    else:
        return int("".join(tar), 2)

def listdir(path, file_lst):
    # get all path
    for file in os.listdir(path):
        file_path = os.path.join(path, file)
        if os.path.isdir(file_path):
            listdir(file_path, file_lst)
        elif os.path.splitext(file_path)[1] in analysis.ANALYSIS_FILE_LIST.keys():
            file_lst.append(file_path)

if __name__ == "__main__":
    print("%x" % str2sint("1110000000000000"))
