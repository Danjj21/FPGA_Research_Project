`default_nettype none
module SPI_mnrch(clk,rst_n,SS_n,SCLK,MISO,MOSI,snd,cmd,resp,done);
  ///////////////////////////////////////////////////
  /// Model of a SPI monarch/////////////////////////
  ///////////////////////////////////////////////////

  input wire clk,rst_n;			// clock and active low asynch reset
  input wire MISO;				// serial data out to master
  input wire snd;				//A high for 1 clock period would initiate 
							//a SPI transaction
  input logic [15:0] cmd;			// Data (command) being sent to inertial 
							//sensor.
  
  output logic SS_n;				// active low slave select
  output logic SCLK;				// Serial clock
  output logic MOSI;				// serial data in from master
  output logic  done;			// Asserted when SPI transaction is 
							// complete. Should stay asserted till 
							// next wrt		
  output logic [15:0] resp;		// command to the A2D
  
  typedef enum logic[1:0] {IDLE,SHIFT_En,DONE} state_t;// took out Almost done 
  
    /////////////////////////////////////////////
  // SM outputs declared as type logic next //
  ///////////////////////////////////////////
  
  logic out1_
  
  ///////////////////////////////////////////////
  // Registers needed in design declared next //
  /////////////////////////////////////////////
  state_t state,next_state;
  logic ld_SCLK;
  logic init;
  /////////////////////////////////////////////
  // SM outputs declared as type logic next //
  ///////////////////////////////////////////
  logic ld_shft_reg, shift_tx, shift_rx, clr_rdy, set_rdy;

  logic SS_n_int;
  
  assign SS_n_int= SS_n;
  
  ////////////////////////////////////////////////////////
  // bit counter to check if 16 loads have been achieved//
  ////////////////////////////////////////////////////////
  
  // initialize intermediate signals
  logic set_done;
  logic shft;
  logic [15:0] shft_reg_tx;
  logic [15:0] shft_reg_rx;
  logic [4:0] bit_cntrOut;
  logic [4:0] bit_cntrIn;
  logic [4:0] bit_cntrInt1;
  logic done16;

  // assign input signal to flop to all zeros if init is asserted else assign
  // to output from previous mux
  assign bit_cntrIn = (init) ? 5'b00000: bit_cntrInt1;
  // assign intermediate signal to flop to all bit_cntrOut if shift is deasserted else assign
  // to the same signal plus 1
  assign bit_cntrInt1 = (shft) ? bit_cntrOut: bit_cntrOut+1'b1;
  
  assign done16= &bit_cntrOut;
  //flop to assign done signal to either 1 or 0 (one bit)//
  always_ff @(posedge clk) 
	if(clk) begin
	bit_cntrOut<=bit_cntrIn;
	end 
  
  ////////////////////////////////////////////////////////
  //////// bit counter to change state of SCLK////////////
  ////////////////////////////////////////////////////////
  
  // initialize intermediate signals
  logic [4:0] SCLK_divOut;
  logic [4:0] SCLK_divIn;
  logic full;	
  assign SCLK_divIn= (ld_SCLK) ? 5'b10111 : SCLK_divOut;
  assign SCLK= SCLK_divOut[4];
  assign shft= SCLK_divOut[0]; 
  assign full= SCLK_divOut[4];
  //flop to assign shift signal to either 1 or 0 (one bit)//
  always_ff @(posedge clk)
    if (clk)
	  begin
		SCLK_divOut<= 5'b00000: SCLK_divIn+2'b10;
	  end
	else
	  begin
		SCLK_divOut <= SCLK_divOut;
	  end  
	  


  //// Infer main SPI shift register ////


  ////////////////////////////////////////////
  // always ff for shift register//
  ////////////////////////////////////////////  
 always_ff @(posedge clk)
	  //////////////////////
      // Default outputs //
      ////////////////////
     
    if (clk)
		shft_reg_tx <= (init) ? cmd : ((shft)? {shft_reg_rx[14:0],MISO}: shft_reg_rx);

		
  ///// MOSI is shift_reg[15] with a tri-state ///////////
  assign MOSI = (SS_n_int) ? 1'bz : shft_reg_tx[15];	
  assign resp = shft_reg_tx;
    always_ff @(posedge clk,negedge rst_n)
  //reset state to state if rst_n is low
    if (!rst_n)
      state <= IDLE;
  //else set state to next state at next posedge clk
   else
      state <= next_state;
	  
  //////////////////////////////////////
  // Implement state tranisiton logic //
  /////////////////////////////////////
  always_comb begin
    
      //////////////////////
      // Default outputs //
      ////////////////////
	  ld_SCLK = 0;
      set_done = 0;
	  init = 0;  
	  
	  next_state=IDLE;
      case (state)
        IDLE : begin
          ld_SCLK=1'b1;
          if (snd) begin
	      init=1'b1; 
		  next_state= SHIFT_En;
          end
        end
		SHIFT_En : begin		
		  ld_SCLK=1'b1;
          if (snd) begin
	      init=1'b0; 
          end
		  if(done16) begin
		  next_state=DONE;
		  end
		  else begin
		  next_state= SHIFT_En;
		  end
		end
		//Almost_Done: begin
		
		//end
		DONE : begin
		 set_done=1'b1;
		end
	default: begin
	next_state= IDLE;
	end
    endcase
   end
	//always ff for resetting done and SS_n signals out of SM
	always_ff @(posedge clk) 
	if (!rst_n) begin
	done <= 1'b0;
	end
	else if(set_done) begin
	done <= 1'b1;
	end 
    always_ff @(posedge clk) 
	if (!rst_n) begin
	SS_n <= 1'b1;
	end
	else if(!init) begin
	SS_n <= 1'b0;
	end 

  
endmodule  
`default_nettype wire
