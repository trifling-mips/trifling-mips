import os
import utils
import analysis

def main():
    file_lst = []
    utils.listdir(".", file_lst)
    for file in (file_lst):
        postfix = os.path.splitext(file)[1]
        analysis.ANALYSIS_FILE_LIST[postfix](file)

if __name__ == "__main__":
    main()
