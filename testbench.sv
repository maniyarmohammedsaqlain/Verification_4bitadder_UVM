`include "uvm_macros.svh";
import uvm_pkg::*;

class transaction extends uvm_sequence_item;
  rand bit[3:0]a;
  rand bit[3:0]b;
  bit [4:0]y;
  
  `uvm_object_utils_begin(transaction)
  `uvm_field_int(a,UVM_DEFAULT);
  `uvm_field_int(b,UVM_DEFAULT);
  `uvm_field_int(y,UVM_DEFAULT);
  `uvm_object_utils_end
  
  function new(string path="trans");
    super.new(path);
  endfunction
endclass


class sequence1 extends uvm_sequence#(transaction);
  `uvm_object_utils(sequence1);
  transaction trans;
  function new(string path="seq");
    super.new(path);
  endfunction
  
  virtual task body();
    repeat(10)
      begin
        trans=transaction::type_id::create("trans");
        start_item(trans);
        trans.randomize();
        `uvm_info("Seq",$sformatf("Generated values of a is %d b is %d",trans.a,trans.b),UVM_NONE);
        finish_item(trans);
      end
  endtask
endclass


class driver extends uvm_driver#(transaction);
  `uvm_component_utils(driver);
  transaction trans;
  virtual add_if aif;
  function new(string path="drv",uvm_component parent=null);
    super.new(path,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    trans=transaction::type_id::create("trans",this);
    
    if(!uvm_config_db #(virtual add_if)::get(this,"","aif",aif))
      `uvm_info("drverr","Error occured is driver",UVM_NONE);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    forever
      begin
        seq_item_port.get_next_item(trans);
        aif.a<=trans.a;
        aif.b<=trans.b;
        `uvm_info("DRV",$sformatf("Driver recieved is a %d b %d",trans.a,trans.b),UVM_NONE);
        seq_item_port.item_done();
        #10;
      end
  endtask
endclass

class monitor extends uvm_monitor;
  `uvm_component_utils(monitor);
  transaction trans;
  virtual add_if aif;
  uvm_analysis_port #(transaction) send;
  function new(string path="monitor",uvm_component parent=null);
    super.new(path,parent);
    send=new("send",this);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    trans=transaction::type_id::create("trans",this);
    if(!uvm_config_db#(virtual add_if)::get(this,"","aif",aif))
      `uvm_info("moner","Error occured is monitor",UVM_NONE);
  endfunction
   
  virtual task run_phase(uvm_phase phase);
    forever
      begin
        #10;
        trans.a=aif.a;
        trans.b=aif.b;
        trans.y=aif.y;
        `uvm_info("MON",$sformatf("Data recieved from monitor is a %d b %d y %d",trans.a,trans.b,trans.y),UVM_NONE);
        send.write(trans);
      end
  endtask
endclass

class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard);
  transaction trans;
  uvm_analysis_imp #(transaction,scoreboard) recv;
  function new(string path="scoreboard",uvm_component parent=null);
    super.new(path,parent);
    recv=new("recv",this);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    trans=transaction::type_id::create("trans",this);
  endfunction
  
  virtual function void write(input transaction tra);
    trans=tra;
    `uvm_info("SCB",$sformatf("Data recieved is a is %d b is %d y is %d",trans.a,trans.b,trans.y),UVM_NONE);
    if(trans.y==trans.a+trans.b)
      begin
        `uvm_info("CHKP","Passed",UVM_NONE);
      end
    else
      begin
        `uvm_info("CHKF","FAILED",UVM_NONE);
      end
  endfunction
endclass

class agent extends uvm_agent;
  `uvm_component_utils(agent);
  monitor mon;
  uvm_sequencer #(transaction) seqr;
  driver drv;
  function new(string path="agent",uvm_component parent=null);
    super.new(path,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon=monitor::type_id::create("mon",this);
    drv=driver::type_id::create("drv",this);
    seqr=uvm_sequencer#(transaction)::type_id::create("seqr",this);
    
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass

class env extends uvm_env;
  `uvm_component_utils(env);
  agent a;
  scoreboard scb;
  
  function new(string path="env",uvm_component parent=null);
    super.new(path,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    a=agent::type_id::create("a",this);
    scb=scoreboard::type_id::create("scb",this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    a.mon.send.connect(scb.recv);
  endfunction
endclass

class test extends uvm_test;
  `uvm_component_utils(test);
  env e;
  sequence1 seq;
  function new(string path="test",uvm_component parent=null);
    super.new(path,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    e=env::type_id::create("e",this);
    seq=sequence1::type_id::create("seq",this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq.start(e.a.seqr);
    #50;
    phase.drop_objection(this);
  endtask
endclass

module tb;
  add_if aif();
  add adderdut(aif.a,aif.b,aif.y);
  initial
    begin
      uvm_config_db #(virtual add_if)::set(null,"uvm_test_top.e.a*","aif",aif);
      run_test("test");
    end
endmodule
