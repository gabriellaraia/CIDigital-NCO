`ifndef UTIL_VH
`define UTIL_VH

function integer clog2 (input integer value);
    integer temp;
    begin
        temp = value - 1;
        for (clog2 = 0; temp > 0; clog2 = clog2 + 1) begin
            temp = temp >> 1;
        end
    end
endfunction

`endif