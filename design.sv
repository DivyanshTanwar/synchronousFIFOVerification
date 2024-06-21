interface fifo_if;
  
  logic clk, rst, wr_en, rd_en;
  logic [7:0] data_in, data_out;
  logic full, empty;
  
  
endinterface

// WIDTH - 8 DEPTH - 16

module fifo (fifo_if finf);
  
  logic [3:0] rd_ptr, wr_ptr;
  logic [4:0] count;
  
  logic [7:0] mem [15:0];
  
  always @(posedge finf.clk) begin
    
    if(finf.rst == 1'b1) begin
      
      rd_ptr <= 0;
      wr_ptr <= 0;
      count <= 0;
      
    end
    
    else if(finf.wr_en && !finf.full) begin
      
      mem[wr_ptr] <= finf.data_in;
      wr_ptr <= wr_ptr + 1;
      count <= count + 1;
      
    end
    
    else if (finf.rd_en && !finf.empty) begin
      
      finf.data_out <= mem[rd_ptr];
      rd_ptr <= rd_ptr + 1;
      count <= count - 1;
      
    end
    
    
  end
  
  assign finf.full = (count == 16) ? 1'b1 : 1'b0;
  assign finf.empty = (count == 0) ? 1'b1 : 1'b0;
  
  
endmodule
