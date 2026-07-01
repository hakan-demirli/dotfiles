#!/usr/bin/env python3
import re
import sys

"""
CAI: Copy as Instance

Create verilog instantiation from module definition.
Args:
  verilog_code: Verilog module definition.
Returns:
  The instantiation of the module in Verilog .
"""


def align_parentheses(processed_code):
    lines = processed_code.split("\n")
    max_len_left = max(
        len(line.split("(")[0]) for line in lines if "(" in line and "_dut" not in line
    )
    max_len_right = max(
        len(line.split("(")[1].split(")")[0])
        for line in lines
        if "(" in line and ")" in line
    )
    aligned_code = ""
    for line in lines:
        if "(" in line and ")" in line and "_dut" not in line:
            before_left, after_left = line.split("(", 1)
            before_right, after_right = after_left.split(")", 1)
            aligned_code += (
                before_left.ljust(max_len_left)
                + "("
                + before_right.ljust(max_len_right)
                + ")"
                + after_right
                + "\n"
            )
        else:
            aligned_code += line + "\n"
    return aligned_code


def process_verilog(verilog_code):
    verilog_keywords = [
        "module",
        "endmodule",
        "input",
        "inout",
        "output",
        "reg",
        "wire",
        "always",
        "parameter",
    ]
    for keyword in verilog_keywords:
        verilog_code = re.sub(rf"{keyword}\s+", "", verilog_code)
    parameters = re.search(r"#\((.*?)\)", verilog_code, flags=re.DOTALL)
    parameters_str = parameters.group(1) if parameters else ""
    parameters_str = re.sub(r"\s*=\s*\w+", "", parameters_str)
    if parameters_str:
        parameters_str = ", ".join(
            [
                f".{param.strip()}({param.strip()})"
                for param in parameters_str.split(",")
            ]
        )

    verilog_code = re.sub(r"#\(.*?\)", "", verilog_code, flags=re.DOTALL)

    verilog_code = re.sub(r"\n\s*\n", "\n", verilog_code, flags=re.MULTILINE)
    verilog_code = re.sub(r"/\*.*?\*/", "", verilog_code, flags=re.DOTALL)
    verilog_code = re.sub(r"//.*", "", verilog_code)
    verilog_code = re.sub(r"\[[^\]]*\]\s+", "", verilog_code)
    verilog_code = re.sub(r"(\w+)(,|\s*\))", r".\1(\1)\2", verilog_code)
    verilog_code = align_parentheses(verilog_code)
    if parameters_str:
        verilog_code = re.sub(
            r"(\w+)\s*\(",
            r"\1 \1_dut #(" + parameters_str + ") (",
            verilog_code,
            count=1,
        )
    else:
        verilog_code = re.sub(r"(\w+)\s*\(", r"\1 \1_dut (", verilog_code, count=1)

    return verilog_code.rstrip(",")


def test_process_verilog():
    verilog_code = """
    module ls_unit (
        input  wire                 clk_i,    // differential clock inputs
        output wire                 busy_o,
        // ex
        input  wire                 we_i,
        output reg  [         31:0] data_o, /* // */
        // dram
        output wire                 cke,      // c
        output wire                 we_n,     // wrim,.//,,,
        output wire [  BA_BITS-1:0] ba,       // bank wire
        output wire [ADDR_BITS-1:0] addr,     // address(fuzz) input
        inout  wire [  DQ_BITS-1:0] dq,       //
        input  wire [ DQS_BITS-1:0] tdqs_n,   // Termination
        output                      odt       //
    );
    """
    verilog_code_param = """
    module ls_unit #(
       parameter PC_WIDTH   = 32,
       parameter DATA_WIDTH = 32
    ) (
        input  wire                 clk_i,    // differential clock inputs
        input  wire                 we_i,
        output reg  [         31:0] data_o, /* // */
        output                      odt       //
    );
    """

    processed_code = process_verilog(verilog_code)
    print(processed_code)
    processed_code = process_verilog(verilog_code_param)
    print(processed_code)


if __name__ == "__main__":
    debug = False
    if debug:
        test_process_verilog()
    else:
        verilog_code = sys.stdin.read()
        processed_code = process_verilog(verilog_code)
        print(processed_code)


"""
FIX:
    module rf_p_2r2w #(
       parameter WLEN  = 32,
       parameter DEPTH = 32
    ) (

       `RP(0)
       `RP(1)

       `WP(0)

       //
       input wire clk_i,
       input wire rst_i
    );

FIX:
    module alu (
       input wire [31:0] data1_i,
       input wire [31:0] data2_i,
       output wire [31:0] output_o,
       alu_t control_i
    );

"""
