/*Assignment agenda:

Modify the Testbench environment used for the verification of UART to test the operation of the UART transmitter with PARITY and STOP BIT. 
Add logic in scoreboard to verify that the data on TX pin matches the random 8-bit data applied on the DIN bus by the user.Parity is always enabled and odd type.

*/

`timescale 1ns/1ps

//transaction class
class transaction;
  
  //declare the other data variables
  rand bit [7:0] tx_data;
  bit newd; //rand?
  bit tx;
  bit donetx;
  
  //deep copy
  function transaction copy();
    copy = new();
    copy.newd = this.newd;
    copy.tx = this.tx;
    copy.tx_data = this.tx_data;
    copy.donetx = this.donetx;
  endfunction
  
endclass
 
//interface
interface uart_if;
  logic clk;
  logic rst;
  logic newd;
  logic [7:0] tx_data;
  logic tx;
  logic donetx;
  logic uclktx;
endinterface

 
//generator class
class generator;

  //declare the data variables
  transaction tr;
  mailbox #(transaction) mbx;
  event done;
  event drvnext;
  event sconext;
  int count = 0;
  
  //custom constructor
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    tr = new();
  endfunction
  
  //main task
  task run();
    
    repeat(count) begin
      assert(tr.randomize) else $error("[GEN] :Randomization Failed");
      mbx.put(tr.copy);
      $display("[GEN]: Input tx_data : %0d",tr.tx_data);
      @(drvnext);
      
      @(sconext);
    end
    -> done;

    
  endtask
endclass
 
//driver class
class driver;
  
  //call the data variables
  virtual uart_if vif;
  transaction tr;
  mailbox #(transaction) mbx;
  mailbox #(bit [7:0]) mbxds;
  event drvnext;
  
  bit [7:0] din;
  
  //custom constructor
  function new(mailbox #(bit [7:0]) mbxds, mailbox #(transaction) mbx);
    this.mbx = mbx;
    this.mbxds = mbxds;
   endfunction
  
  //reset
  task reset();
    vif.rst <= 1'b1;
    vif.tx_data <= 0;
    vif.newd <= 0;
    vif.donetx <= 0; //
 
    repeat(5) @(posedge vif.uclktx);
    vif.rst <= 1'b0;
    @(posedge vif.uclktx);
    $display("[DRV] : RESET DONE");
    $display("----------------------------------------");
  endtask
  

  //run
  task run();
  
    forever begin
      mbx.get(tr);
            
      @(posedge vif.uclktx);
      vif.rst <= 1'b0;
      vif.newd <= 1'b1;  ///start data sending op
      vif.tx_data = tr.tx_data;
      @(posedge vif.uclktx);
      vif.newd <= 1'b0;
      ////wait for completion 
      //repeat(9) @(posedge vif.uclktx);
      mbxds.put(tr.tx_data);
      $display("[DRV]: Data Sent : %0d", tr.tx_data);
      wait(vif.donetx == 1'b1);  
      ->drvnext;  

   
    end   
  endtask
endclass
 
 
//monitor class
class monitor;
 
  //declare the data variables
  transaction tr;
  mailbox #(bit [8:0]) mbx;
  virtual uart_if vif;

  bit [8:0] srx; //////send
  
  function new(mailbox #(bit [8:0]) mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    
    forever begin
      //@(posedge vif.uclktx);
      //@(posedge vif.uclktx);
      
      wait(vif.newd == 1);
      @(posedge vif.uclktx);
      
      if ( (vif.newd== 1'b1) ) begin
        @(posedge vif.uclktx); 
        
        ////start collecting tx data from next clock tick
        for(int i = 0; i<= 8; i++) begin 
          @(posedge vif.uclktx);
          srx[i] = vif.tx;
        end
      $display("[MON] : DATA SEND on UART TX %0d", srx);
      end
                  
      //////////wait for done tx before proceeding next transaction      
      wait(vif.donetx == 1);
      @(posedge vif.uclktx); 
      mbx.put(srx); 
    end  
endtask
  
 
endclass
 

//scoreboard class
class scoreboard;
  
  //declare the data variables
  mailbox #(bit [7:0]) mbxds;
  mailbox #(bit [8:0]) mbxms;
  bit [7:0] ds;
  bit [8:0] ms;
  event sconext;
  bit parity;
  
  //custom constructor
  function new(mailbox #(bit [7:0]) mbxds, mailbox #(bit [8:0]) mbxms);
    this.mbxds = mbxds;
    this.mbxms = mbxms;
  endfunction
  
  //main task
  task run();
    forever begin
      
      
      mbxds.get(ds);
      mbxms.get(ms);
      
      //calculate parity from ref
      parity = ~^ds;
      
      $display("[SCO] : DRV : %0d MON : %0d", ds, ms);
      $display("[SCO] : DRVParity : %0d MONParity : %0d", parity, ms[8]);
      
      if(ds == ms[7:0] && parity == ms[8])
        $display("DATA MATCHED");
      else
        $display("DATA MISMATCHED");
      
      $display("----------------------------------------");
      ->sconext; 
    end
  endtask
endclass
 

//environment class
class environment;
 
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco; 
  
    
  event nextgd; ///gen -> drv
  event nextgs;  /// gen -> sco
 
  mailbox #(transaction) mbxgd; ///gen - drv
  mailbox #(bit [7:0]) mbxds; /// drv - sco 
  mailbox #(bit [8:0]) mbxms;  /// mon - sco
  virtual uart_if vif;
 
  
  function new(virtual uart_if vif);
       
    mbxgd = new();
    mbxms = new();
    mbxds = new();
    
    gen = new(mbxgd);
    drv = new(mbxds,mbxgd);
    
    
 
    mon = new(mbxms);
    sco = new(mbxds, mbxms);
    
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
    
    gen.sconext = nextgs;
    sco.sconext = nextgs;
    
    gen.drvnext = nextgd;
    drv.drvnext = nextgd;
 
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
    wait(gen.done.triggered);  
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
 
endclass
 
 
//testbench top module
module tb;
    
  uart_if vif();
  
  uarttx #(1000000, 9600) dut (vif.clk,vif.rst,vif.newd,vif.tx_data,vif.tx,vif.donetx);
  
  initial begin
    vif.clk <= 0;
  end
    
  always #10 vif.clk <= ~vif.clk;
    
  environment env;
  
  initial begin
    env = new(vif);
    env.gen.count = 10;
    env.run();
  end
      
    
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    //#200000
    //$finish();
  end
   
  assign vif.uclktx = dut.uclk;

endmodule
