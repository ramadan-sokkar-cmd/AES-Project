create_clock -period 4.300 [get_ports clk]

create_pblock pblock_1
resize_pblock [get_pblocks pblock_1] -add {SLR0}
