class transaction;
  
  rand bit oper;  // if oper == 1 -> write , if oper ==0 -> read
  bit wr_en, rd_en, full, empty;
  rand bit [7:0] data_in;
  bit [7:0] data_out;
  
  constraint input_data{
    data_in inside {[1:15]};
  }
  
  constraint operations{
    
    oper dist {0 :/ 50 , 1 :/ 50};
    
  }
  
  function transaction copy();
    
    copy = new();
    copy.oper = this.oper;
    copy.wr_en = this.wr_en;
    copy.rd_en = this.rd_en;
    copy.full = this.full;
    copy.empty = this.empty;
    copy.data_in = this.data_in;
    copy.data_out = this.data_out;
    
  endfunction
  

  
  
endclass

class generator;
  
  transaction trans;
  mailbox #(transaction) mbx;
  event done, sconext;
  int count;
  int iteration = 0 ;
  
  function new(mailbox #(transaction) mbx);
    
    this.mbx = mbx;
    trans = new();
    
  endfunction
  
  
  task run();
    
    repeat(count) begin
      
      assert(trans.randomize()) else $error("[GEN]: Randomization Failed.");
      iteration ++;
      $display("[GEN]: Operation : %0b Iteration : %0d ",trans.oper, iteration);
      mbx.put(trans.copy);
      @(sconext);
      
    end
    
    -> done;
    
    
  endtask
  
endclass

class driver;
  
  transaction datac;
  virtual fifo_if finf;
  mailbox #(transaction) mbx;
  
  
  function new(mailbox #(transaction) mbx);
    
    this.mbx = mbx;
    
  endfunction
  
  
  task reset();
    
    @(posedge finf.clk);
    finf.rst <= 1'b1;
    finf.wr_en <= 1'b0;
    finf.rd_en <= 1'b0;
    finf.data_in <= 0;
    repeat(5) @(posedge finf.clk);
    finf.rst <= 1'b0;
    @(posedge finf.clk);
    $display("[DRV]: RESET DONE");
    $display("------------------------------------------");
    
  endtask
  
  task write();
    
    @(posedge finf.clk);
    finf.rst <= 1'b0;
    finf.wr_en <= 1'b1;
    finf.rd_en <= 1'b0;
    finf.data_in <= datac.data_in;
    @(posedge finf.clk);
    finf.wr_en <= 1'b0;
    $display("[DRV]: WRITE DONE, DATA IN : %0d",finf.data_in);
    @(posedge finf.clk);
    
    
  endtask
  
  task read();
    
    @(posedge finf.clk);
    finf.rst <= 1'b0;
    finf.rd_en <= 1'b1;
    finf.wr_en <= 1'b0;
    @(posedge finf.clk);
    finf.rd_en <= 1'b0;
    $display("[DRV]: READ DONE");
    @(posedge finf.clk);
    
  endtask
  
  
  task run();
    
    forever begin
      
      mbx.get(datac);
      if(datac.oper == 1'b1)
        write();
      
      else 
        read();
      
    end
    
  endtask
  
endclass


class monitor;
  
  transaction trans;
  virtual fifo_if finf;
  mailbox #(transaction) mbx;
  
  
  function new(mailbox #(transaction) mbx);
    
    this.mbx = mbx;
    trans = new();
    
  endfunction
  
  task run();
    
    forever begin
      
      repeat(2) @(posedge finf.clk);
      trans.rd_en = finf.rd_en;
      trans.wr_en = finf.wr_en;
      trans.full = finf.full;
      trans.empty = finf.empty;
      trans.data_in = finf.data_in;
      @(posedge finf.clk);
      trans.data_out = finf.data_out;
      mbx.put(trans);
      $display("[MON]: RD : %0b WR : %0b FULL : %0b EMPTY : %0b DATA_IN : %0d DATA OUT : %0d",trans.rd_en, trans.wr_en, trans.full, trans.empty, trans.data_in, trans.data_out);
      
    end
    
  endtask
  
endclass

class scoreboard;
  
  transaction datac;
  mailbox #(transaction) mbx;
  event sconext;
  bit [7:0] queue[$];
  bit [7:0] temp;
  int err = 0;
  
  function new(mailbox #(transaction) mbx);
    
    this.mbx = mbx;
    
  endfunction
  
  task run();
    
    forever begin
      
      mbx.get(datac);
      $display("[SCO]: RD : %0b WR : %0b FULL : %0b EMPTY : %0b DATA_IN : %0d DATA OUT : %0d",datac.rd_en, datac.wr_en, datac.full, datac.empty, datac.data_in, datac.data_out);
      
      if(datac.wr_en == 1'b1) begin
        
        if(datac.full == 1'b0) begin
          
          queue.push_back(datac.data_in);
          $display("[SCO]: DATA Stored in QUEUE : %0d",datac.data_in);
          
        end
        
        else
          $display("[SCO]: Fifo is Full");
        
      end
      
      if(datac.rd_en == 1'b1) begin
        
        if(datac.empty == 1'b0) begin
          
          temp = queue.pop_front();
          
          if(datac.data_out == temp) $display("[SCO]: DATA MATCHED");
          
          else begin
           	
            err++;
            $display("[SCO]: DATA MISMATCHED");
            
          end
          
        end
        
        else $display("[SCO]: FIFO EMPTY");
        
      end
      
      $display("------------------------------------------");
      
      -> sconext;
    
    end
    
    
    
  endtask
  
  
endclass


class environment;
  
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  mailbox #(transaction) gen_drv_mbx, mon_sco_mbx;
  
  
  event done;
  
  virtual fifo_if finf;
  
  
  function new(virtual fifo_if finf);
    
    
    gen_drv_mbx = new();
    mon_sco_mbx = new();
    gen = new(gen_drv_mbx);
    drv = new(gen_drv_mbx);
    mon = new(mon_sco_mbx);
    sco = new(mon_sco_mbx);
    
    this.finf = finf;
    drv.finf = this.finf;
    mon.finf = this.finf;
    
    gen.sconext = sco.sconext;
    this.done = gen.done;
    
    
  endfunction
  
  task pre_test();
    
    drv.reset();
    
  endtask
  
  task test();
    
    fork
      
      gen.run();
      drv.run();
      mon.run();
      sco.run();
      
    join_any
    
  endtask
  
  task post_test();
    
    wait(done.triggered);
    $finish();
    
  endtask
  
  task run();
    
    pre_test();
    test();
    post_test();
    
  endtask
  
endclass


module top_tb();
  
  fifo_if finf();
  fifo dut(finf);
  environment env;
  
  initial finf.clk <= 0;
  always #10 finf.clk <= ~finf.clk;
  
  initial begin
    
    env = new(finf);
    env.gen.count = 20;
    env.run();
    
  end
  
  
  initial begin
    
    $dumpfile("dump.vcd");
    $dumpvars();
    
  end
  
  
endmodule
