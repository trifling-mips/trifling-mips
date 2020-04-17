`ifndef TESTBENCH_DEFS_SVH
`define TESTBENCH_DEFS_SVH

/*
    This header defines common constants & funcs in testbench module
*/

// common_defs
`include "common_defs.svh"

// funcs
//该宏在实际使用中时常会被修改 表示从testbench开始的相对路径
`define PATH_PREFIX "testbench"
/*
* this function is used to return the relative path of the file. it needs to ensure 
* that the testbench directory can be found in the form of (.. / *) testbench.
* if there is no testbench directory in the parent directory, null will be returned
* @name     : file_name
* @return   : reletive_path + file_name or ""
*/
`define DEF_FUNC_GET_PATH function string get_path( \
    input string name \
); \
    string path = ""; \
    automatic integer path_counter = 0; \
 \
    if(!$fopen({path, name}, "r")) begin \
        path = `PATH_PREFIX; \
        while(!$fopen({path, name}, "r") && path_counter < 20) begin \
            path_counter++; \
            path = {"../", path}; \
        end \
    end \
 \
    if (!$fopen({path, name}, "r")) \
        return ""; \
    else \
        return {path, name}; \
endfunction

function judge(
    input integer fans,
    input integer cycle,
    input string out
);
    string ans;

    $fscanf(fans, "%s\n", ans);
    if (out != ans && ans != "skip") begin
        $display("[%0d] %s", cycle, out);
        $display("[Error] Expected: %0s, Got: %0s", ans, out);
        $stop;
    end else begin
        $display("[%0d] %s [%s]", cycle, out, ans == "skip" ? "skip" : "pass");
    end
endfunction

`endif
