/*Assignment agenda:

Create a testbench environment for validating the SPI interface's ability to transmit data serially immediately when the CS signal goes low. Utilize the negative edge of the SCLK to sample the MOSI signal in order to generate reference data. Codes are added in Instruction tab.

Student's note: Testbench code was done by the student from scratch, with some reference to look on based on previous example given by the lecturer.

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
  mailbox #(transaction) mbxdrv;
  mailbox #(bit [11:0]) mbxsco;
  
  event done;
  event sconext;
  event drvnext;
  
  int counter;
  
  //constructor
  function new(mailbox #(transaction) mbxdrv, mailbox #(bit [11:0]) mbxsco);
    tr = new();
    this.mbxdrv = mbxdrv;
    this.mbxsco = mbxsco;
  endfunction
  
  //task main
  task main();
    repeat(counter) begin
      assert(tr.randomize()) else $error("[GEN] : Randomization failed");
      mbxdrv.put(tr.copy);
      mbxsco.put(tr.din);
      tr.display("GEN");
      @sconext;
      @drvnext;
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
      
      //wait for duty to be over
      wait(vif.cs == 1'b0);
      tr.display("DRV");
    end
  endtask
  
  
endclass

//monitor class

//scoreboard class

//environment class

//testbench top
module tb(  );
 
reg clk = 0, rst = 0, newd = 0;
reg [11:0] din = 0;
wire sclk, cs, mosi;
  reg [11:0] mosi_out = 0;
 
always #10 clk = ~clk;
 
spi_master dut (clk, newd,rst, din, sclk, cs, mosi);
 
initial 
begin
rst = 1;
repeat(5) @(posedge clk);
rst = 0;
 
newd = 1;
din = $urandom;
  $display("%0d", din); 
  for(int i = 0; i <= 11; i++)
    begin
    @(negedge dut.sclk);
    mosi_out = {mosi, mosi_out[11:1]};
    $display("%0d", mosi_out);  
    end
  
  
end
 
 
 
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    #2500;
    $stop;
  end
 
endmodule
