#create time constraints 
#96MHz
create_clock -period 10.417 -name wr_clk -waveform {0.000 5.208} [get_ports wr_clk_i]

#60MHz
create_clock -period 16.667 -name rd_clk -waveform {0.000 8.333} [get_ports rd_clk_i]

#declare domains asynchrouns

set_clock_groups -asynchronous \  
    -group [get_clocks wr_clk] \ 
    -group [get_clocks rd_clk]

#protect the sync flops 

