`ifndef APB_MASTER_DRIVER_BFM_INCLUDED_
`define APB_MASTER_DRIVER_BFM_INCLUDED_

import apb_global_pkg::*;
//--------------------------------------------------------------------------------------------
// Interface : apb_master_driver_bfm
//  Used as the HDL driver for apb
//  It connects with the HVL driver_proxy for driving the stimulus
//
// Parameters:
//  intf - apb Interface
//--------------------------------------------------------------------------------------------
interface apb_master_driver_bfm (input  bit   pclk,
                                 input  bit   preset_n,
                                 input  bit   pready,
                                 input  bit   pslverr,
                                 input  logic [DATA_WIDTH-1:0]prdata,
                                 output logic [2:0]pprot,
                                 output logic penable,
                                 output logic pwrite,
                                 output logic [ADDRESS_WIDTH-1:0] paddr,
                                 output logic [NO_OF_SLAVES-1:0] pselx,
                                 output logic [DATA_WIDTH-1:0] pwdata,
                                 output logic [(DATA_WIDTH/8)-1:0] pstrb
                                );

  //-------------------------------------------------------
  // Importing uvm package file
  //-------------------------------------------------------
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  //-------------------------------------------------------
  // Importing the master package file
  //-------------------------------------------------------
  import apb_master_pkg::apb_master_driver_proxy;
  
  //Variable: end_of_transfer
  //Used to indicate the end of transfer of the packet
  bit end_of_transfer;
  
  //Variable: apb_master_drv_proxy_h
  //Creating the handle for the proxy_driver
  apb_master_driver_proxy apb_master_drv_proxy_h;
 
  initial begin
    `uvm_info("apb master driver bfm",$sformatf("APB MASTER DRIVER BFM"),UVM_LOW)
  end

  //--------------------------------------------------------------------------------------------
  // Task: wait_for_presetn
  // Waiting for the system reset to be active low
  //--------------------------------------------------------------------------------------------
  task wait_for_preset_n();
    @(negedge preset_n);
    `uvm_info("MASTER_DRIVER_BFM",$sformatf("system reset detected"),UVM_HIGH)
 
    @(posedge preset_n);
    `uvm_info("MASTER_DRIVER_BFM",$sformatf("system reset deactivated"),UVM_HIGH)
  endtask: wait_for_preset_n
  
  //--------------------------------------------------------------------------------------------
  // Task: drive_to_bfm
  // This task will drive the data from bfm to proxy using converters
  //
  // Parameters:
  // data_packet  - handle for apb_transfer_char_s
  // cfg_pkt      - handle for apb_transfer_cfg_s
  //--------------------------------------------------------------------------------------------
  task drive_to_bfm(inout apb_transfer_char_s data_packet, input apb_transfer_cfg_s cfg_pkt);
    if(preset_n) begin
      @(posedge pclk);
      `uvm_info("MASTER_DRIVER_BFM",$sformatf("DRIVE TO BFM TASK"),UVM_HIGH);

      //Driving Idle state
      drive_idle_state();

      //Driving Setup state
      drive_setup_state(data_packet);

      //Driving Access state
      drive_access_state(data_packet);

    end
    else begin
      `uvm_info("MASTER_DRIVER_BFM",$sformatf("RESET_DETECTED"),UVM_HIGH);
    end
  
   endtask: drive_to_bfm

  //--------------------------------------------------------------------------------------------
  // Task: drive_idle_state
  // This task drives the apb interface to idle state
  //--------------------------------------------------------------------------------------------
  task drive_idle_state();
    @(posedge pclk);
    `uvm_info("MASTER_DRIVER_BFM",$sformatf("driving the idle state"),UVM_HIGH)
    pselx   <= '0;
    penable <= 1'b0;
  endtask: drive_idle_state

  //--------------------------------------------------------------------------------------------
  // Task: drive_setup_state
  // This task defines the setup phase where signals 
  // are set to drive
  //
  // Parameters:
  // paddr - address signal
  //--------------------------------------------------------------------------------------------
  task drive_setup_state(input apb_transfer_char_s data_packet);
    @(posedge pclk);
    `uvm_info("MASTER_DRIVER_BFM",$sformatf("driving the setup state"),UVM_HIGH)
    pselx   <= data_packet.pselx;
    penable <= 1'b0;
    paddr   <= data_packet.paddr;
    pwrite  <= data_packet.pwrite;
  endtask: drive_setup_state

  //-------------------------------------------------------
  // Task: drive_access_state
  // This task defines the accessing of data signals from master to slave or viceverse
  //
  // Parameters:
  // data_packet - handle for apb_transfer_char_s
  //-------------------------------------------------------
  task drive_access_state(input apb_transfer_char_s data_packet);
    @(posedge pclk);
    `uvm_info("MASTER_DRIVER_BFM",$sformatf("driving the setup state"),UVM_HIGH);

    pselx     <= data_packet.pselx;
    penable   <= 1'b1;
    
    if(pready == 1'b1) begin
      transfer_data(data_packet);
    end
    else begin
      //Driving Wait State
      drive_wait_state(data_packet, penable);
    end
    if(end_of_transfer == 1'b1) begin
      drive_idle_state();
    end
    else begin
      drive_setup_state(data_packet);
    end

  endtask: drive_access_state

  //--------------------------------------------------------------------------------------------
  // Task: drive_access_state
  // This task defines the accessing of data signals from master to slave or viceverse
  //
  // Parameters:
  // data_packet - handle for apb_transfer_char_s
  //--------------------------------------------------------------------------------------------
  task transfer_data(apb_transfer_char_s data_packet);
    if(pwrite == 1'b1) begin
      pwdata <= data_packet.pwdata;
      end_of_transfer = 1'b1;
    end
    else begin
      data_packet.prdata = prdata;
      end_of_transfer = 1'b1;
    end
  endtask :transfer_data

  //--------------------------------------------------------------------------------------------
  // Task: drive_wait_state
  // In this task, signals are waiting for pready to set to high to transfer the data_packet
  //
  // Parameters:
  // data_packet - handle for apb_transfer_char_s
  //--------------------------------------------------------------------------------------------
  task drive_wait_state(apb_transfer_char_s data_packet, bit penable);
    
    paddr <= data_packet.paddr;
    pwrite <= data_packet.pwrite;

    while(penable) begin
      if(!pready) begin
        `uvm_info("MASTER_DRIVER_BFM","WAIT_STATE_DETECTED",UVM_LOW);
        @(posedge pclk);
      end
      else begin
        transfer_data(data_packet);
      end
    end
  endtask : drive_wait_state

endinterface : apb_master_driver_bfm

`endif

