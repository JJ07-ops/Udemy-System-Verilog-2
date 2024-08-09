/*Assignment agenda:

Create a testbench environment for validating the SPI interface's ability to transmit data serially immediately when the CS signal goes low. Utilize the negative edge of the SCLK to sample the MOSI signal in order to generate reference data. Codes are added in Instruction tab.

Student's note: Testbench code was done by the student from scratch, with help of reference code based on previous example given by the lecturer.

*/

`timescale 1ns/1ps

//transaction class
class transaction;
  rand bit newd;
  rand bit [11:0] din;
  bit cs;
  bit mosi;
  
  function transaction copy();
    copy = new();
    copy.newd = this.newd;
    copy.din = this.din;
    copy.cs = this.cs;
    copy.mosi = this.mosi;
  endfunction
  
  function void display(input string str);
    $display("[%0s] : DATA NEW : %0d DIN : %0d CS: %0d MOSI : %0d",str,newd,din,cs,mosi);
  endfunction
   
endclass

//interface
interface spi_if;
  logic clk, newd,rst;
  logic [11:0] din;
  logic sclk,cs,mosi;
endinterface

//generator class
class generator;
  transaction tr;
  mailbox #(transaction) mbx;
  mailbox #(bit [11:0]) mbxref;
  
  event done;
  event sconext;
  event drvnext;
  
  int counter;
  
  //constructor
  function new(mailbox #(transaction) mbx, mailbox #(bit [11:0]) mbxref);
    tr = new();
    this.mbx = mbx;
    this.mbxref = mbxref;
  endfunction
  
  //task main
  task run();
    repeat(counter) begin
      assert(tr.randomize()) else $error("[GEN] : Randomization failed");
      mbx.put(tr.copy);
      mbxref.put(tr.din);
      tr.display("GEN");
      @drvnext;
      @sconext;
      //$display("here1");
      //$display("here2");
    end 
    -> done;
  endtask
endclass

//driver class
class driver;
  virtual spi_if vif;
  transaction tr;
  mailbox #(transaction) mbx;
  event drvnext;
  
  //constructor
  function new(mailbox #(transaction) mbx);
    tr = new();
    this.mbx = mbx;
  endfunction
  
  //Task to reset
  task reset;
    //turn on reset and reset values
    vif.rst <= 1'b1;
    vif.cs <= 1'b1;
    vif.newd <= 1'b0;
    vif.din <= 1'b0;
    vif.mosi <= 1'b0;
    
    //wait for 10 cycles
    repeat(10) @(posedge vif.clk);
    
    //turn off reset
    vif.rst <= 1'b0;
    
    //wait for 5 cycles for reset to be done
    repeat(5) @(posedge vif.clk);
    $display("[DRV] : RESET DONE");
    $display("-----------------------------------------------");
  endtask
  
  //Task to run
  task run();
    forever begin
      mbx.get(tr);
      //switch on newd and send din to interface
      @(negedge vif.sclk);
      vif.newd <= 1'b1 ;
      vif.din <= tr.din;
      
      //switch off newd
      @(negedge vif.sclk);
      vif.newd <= 1'b0;
      
      //wait for cs to be low
      wait(vif.cs == 1'b0);
      tr.display("DRV");
      -> drvnext;
    end
  endtask
  
  
endclass

//monitor class
class monitor;
  virtual spi_if vif;
  mailbox #(bit [11:0]) mbx;
  bit [11:0] serialdata; //received data
  
  //constructor
  function new(mailbox #(bit [11:0]) mbx);
    this.mbx = mbx;
  endfunction

  
  //Task to run
  task run();
    forever begin
      @(negedge vif.sclk);
      wait(vif.cs == 1'b0);
      @(negedge vif.sclk);
      
      for(int i = 0;i < 12;i++) begin
        @(negedge vif.sclk);
        serialdata[i] = vif.mosi;
      end
      
      //wait for serialdata to be finished updating before sending to scoreboard
      wait(vif.cs == 1'b1);
      $display("[MON] : DATA RCVD : %0d", serialdata);
      mbx.put(serialdata);
    end
  endtask
  
  
endclass

//scoreboard class
class scoreboard;
  mailbox #(bit [11:0]) mbx;
  mailbox #(bit [11:0]) mbxref;
  bit [11:0] dataref;
  bit [11:0] serialdata;
  event sconext;
  
  //constructor
  function new(mailbox #(bit [11:0]) mbx, mbxref);
    this.mbxref = mbxref;
    this.mbx = mbx;
  endfunction
  
  //main task
  task run();
    forever begin
      mbxref.get(dataref);
      mbx.get(serialdata);
      $display("[SCO] : DATA FROM GEN : %0d DATA FROM MON : %0d", dataref, serialdata);
      
      if(dataref == serialdata)
        $display("TEST PASSED");
      else
        $display("TEST FAILED");
      
      $display("-----------------------------------------------");
      -> sconext;
      
    end
  endtask
endclass

//environment class
class environment;
  
  //call all the classes
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  //call the events and interface and mailboxes
  event nextgd;
  event nextgs;
  virtual spi_if vif;
  mailbox #(transaction) mbxgd;
  mailbox #(bit [11:0]) mbxms;
  mailbox #(bit [11:0]) mbxgs;
  
  //Constructor and connect all the variables
  function new(virtual spi_if vif);
    
    //construct the mailboxes
    mbxgd = new();
    mbxms = new();
    mbxgs = new();
    
    //construct the classes and connect the mailboxes
    gen = new(mbxgd,mbxgs);
    drv = new(mbxgd);
    mon = new(mbxms);
    sco = new(mbxms,mbxgs); 
      
    //connect the events
    gen.sconext = nextgs;
    gen.drvnext = nextgd;
    drv.drvnext = nextgd;
    sco.sconext = nextgs;
    
    
    //connect the interfaces
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
    
  endfunction
  
  //pre-test
  task pre_test();
    drv.reset();
  endtask
  
  //test
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  //post-test
  task post_test();
    wait(gen.done.triggered); //add delay after this?
    $finish();
  endtask
  
  //run
  task run;
    pre_test();
    test();
    post_test();
  endtask
  
  
  
endclass

//testbench top
module tb(  );
  //call the interface
  spi_if vif();
  spi dut(vif.clk,vif.newd,vif.rst,vif.din,vif.sclk,vif.cs,vif.mosi); 
  
  //set the clock
  initial begin
    vif.clk <= 0;
  end
  
  always #10 vif.clk <= ~vif.clk;
  
  //call the environment class
  environment env;
  
  //construct and run the environment class
  initial begin
    env = new(vif);
    env.gen.counter = 10;
    env.run();
  end
  
  //dump file
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
 
endmodule
