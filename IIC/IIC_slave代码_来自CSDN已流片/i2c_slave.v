//**********************************************************************
//
//            File: i2c_slave.v
//            Module:i2c_slave
//            
//            
//
//
//**********************************************************************
//`timescale	1ns/1ps

module i2c_slave (
		reset_n,
		clock,
		sda_out,
		sda_in,
		scl,
		sda_en,
        device_id,
        data_from_memory,
        data_to_memory,
        enable_writeToMemory,
        enable_writeFromMemory,
        address
		);
		
input		clock;   
input		reset_n;
input		sda_in;
input		scl;
input   [4:0]  device_id;
input   [7:0]   data_from_memory;

output	[7:0]	data_to_memory;  //to define eight register to memory 

output    [7:0]   address;//   use this reg for count the address of memory;
output  enable_writeToMemory,enable_writeFromMemory;

output 		sda_en;
output 		sda_out;

reg		sda_en;
reg 		reset_n1;
reg 		reset_n2;
reg 		scl_regi0; 
reg 		scl_regi;
reg         scl_reg;
reg 		sda_regi0;
reg 		sda_regi;
reg         sda_reg;
reg		start_bus_reg;
reg		stop_bus_reg; 
 
//reg	[7:0] 	data_to_memory;  //wire 
reg     [7:0]   address;
wire  address_load;
wire address_add;
reg  [2:0]  address_FlagCreater;//load address;
reg         flagToggle;//load address;

reg [2:0]   address_FlagCreater_add1;//add address; for read 
reg [2:0]   address_FlagCreater_add2;//add address; for write
reg   flagToggle_add_read;
reg   flagToggle_add_write;

reg  [2:0] synchronizer_writeToMemory;//load memory 
reg   toggle_writeToMemory;
reg  [2:0] synchronizer_writeFromMemory;// get memory
reg   toggle_writeFromMemory;

reg	[6:0]	addr_in_reg;
wire	[7:0] 	data_in_reg0;  
reg	[7:0] 	data_in_reg1;
reg	[7:0] 	reg_addr;
reg	[3:0]	main_state; 
reg	[2:0]	addr_in_state;
reg	[3:0]	data_in_state;
reg	[3:0]	data_out_state;
reg	[3:0]	reg_addr_state;

reg		sda_out1;		// ACK
reg 		sda_out2;		// data_to_master
reg     sda_in1;  //read ack from master to slave;

reg		write_read;
reg	[1:0]	ack_state; 
 
reg		flag;
 
assign sda_out = flag ? sda_out2 : sda_out1;


wire [6:0] device_id_full;
assign device_id_full={2'b11,device_id};

// ----------------------------------------------------------------
// reset_n, scl, sda_in -> two stages registered 
always@(posedge clock)
begin
	reset_n1 <= reset_n;
	reset_n2 <= reset_n1;
    //reset_n3 <= reset_n2;
end
  
always@(posedge clock or negedge reset_n2)
begin
      if(!reset_n2)
	begin
             scl_regi  <= 1'b0;
             sda_regi  <= 1'b0;
             scl_regi0 <= 1'b0;
             sda_regi0 <= 1'b0;
             sda_reg   <= 1'b0;
             scl_reg   <= 1'b0;
	end
      else
	begin
             scl_regi0 <= scl_regi;
             scl_regi  <= scl_reg;
             sda_regi0 <= sda_regi;
             sda_regi  <= sda_reg;

             scl_reg   <= scl;
             sda_reg   <= sda_in;
	end
end

// ----------------------------------------------------------------
// to test start condition: scl=1, sda_in=100

always@(posedge clock or negedge reset_n2)
 begin
  if(!reset_n2)
     start_bus_reg <= 1'b0;
  else
     begin
       if({sda_regi0,sda_regi,sda_reg}==3'b100 && {scl_regi0,scl_regi,scl_reg}==3'b111)
            start_bus_reg <= 1'b1;
       else
            start_bus_reg <= 1'b0;
     end
 end
 
// ----------------------------------------------------------------
// to test stop condition: scl=1, sda_in=011

always@(posedge clock or negedge reset_n2)
 begin
  if(!reset_n2)
     stop_bus_reg <= 1'b0;
  else
     begin
       if({sda_regi0,sda_regi,sda_reg}==3'b011 && {scl_regi0,scl_regi,scl_reg}==3'b111)
            stop_bus_reg <= 1'b1;
       else
            stop_bus_reg <= 1'b0;
     end
 end
 
//----------------- addr in statemachine -------------------------------
 
parameter addr_in6   		= 3'h0;			// chip_id
parameter addr_in5   		= 3'h1;
parameter addr_in4   		= 3'h2;
parameter addr_in3   		= 3'h3;
parameter addr_in2   		= 3'h4;
parameter addr_in1   		= 3'h5;
parameter addr_in0   		= 3'h6;
parameter addr_end   		= 3'h7;

//----------------- reg addr in statemachine ----------------------------
parameter reg_addr7         =4'h0;
parameter reg_addr6         =4'h1;
parameter reg_addr5         =4'h2;
parameter reg_addr4         =4'h3;
parameter reg_addr3         =4'h4;
parameter reg_addr2         =4'h5;
parameter reg_addr1         =4'h6;
parameter reg_addr0         =4'h7;
parameter reg_addr_end      =4'h8;
parameter reg_addr_load      =4'h9;
       
//----------------- data in statemachine -------------------------------

parameter   data_in7   		= 4'h0;
parameter   data_in6   		= 4'h1;
parameter   data_in5   		= 4'h2;
parameter   data_in4   		= 4'h3;
parameter   data_in3   		= 4'h4;
parameter   data_in2   		= 4'h5;
parameter   data_in1   		= 4'h6;
parameter   data_in0   		= 4'h7;
parameter   data_end   		= 4'h8;

//----------------- data out statemachine -------------------------------
 parameter   data_out7   		= 4'h0;
 parameter   data_out6   		= 4'h1;
 parameter   data_out5   		= 4'h2;
 parameter   data_out4   		= 4'h3;
 parameter   data_out3   		= 4'h4;
 parameter   data_out2   		= 4'h5;
 parameter   data_out1   		= 4'h6;
 parameter   data_out0   		= 4'h7;
 parameter   data_out_end  = 4'h8; 
 //parameter   data_out_load  = 4'h9; 

//----------------- main statemachine ------------------------------
parameter idle                       =4'h0;
parameter addr_read                  =4'h1;
parameter write_read_flag            =4'h2;
parameter addr_ack                   =4'h3;
parameter data_write	                =4'h4;
parameter data_in_ack                =4'h5;			 	 
parameter data_read                  =4'h6;
parameter data_out_ack               =4'h7;
parameter reg_addr_read              =4'h8;
parameter reg_addr_ack               =4'h9;
parameter if_rep_start               =4'ha;

//--------------------------------------------------------

//------------------------------------------------------------------	
//main state machine

always @(posedge clock or negedge reset_n2) 
	if(!reset_n2)
	begin
		main_state <= idle;
		write_read <= 1'b0;
        toggle_writeFromMemory<=1'b0;
	    flagToggle_add_write<=1'b0;
	end
	else
	begin
		case (main_state)	
		idle:
		begin
					    
			if(start_bus_reg)	// receive start from SDA
			begin
				main_state	<= addr_read;							 
			end
			else					 
			begin
				main_state	<= idle;						     
			end									     					  
		end
						
		addr_read:	// read chip_id from the master
		begin				    
			if(addr_in_state==addr_end)
				main_state	 <= write_read_flag;
			else					        
				main_state	 <= addr_read;
		end	
				
		write_read_flag:	// read R/W flag following chip_id 			         
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b011)
			begin
				write_read <= sda_reg;   	                                                      
				main_state <= addr_ack;
			end	
			else
				main_state <= write_read_flag;			 
		end
				
		addr_ack:	// send chip_id_ack to the master
		begin	
			if({scl_regi0,scl_regi,scl_reg}==3'b011) 
			begin
				if(addr_in_reg==device_id_full)
                    begin
                        if(write_read==1'b0)
					        main_state <= reg_addr_read;        //write byte
                        else    
                            main_state <= data_read;                      //read byte
                    end
				else                  
				    main_state <= idle;
			end
			else
				main_state <= addr_ack;   				       				     
		end	
		reg_addr_read:	// read register address from master
		begin
			if(reg_addr_state==reg_addr_end)
				main_state <= reg_addr_ack;
			else                  
				main_state <= reg_addr_read;
		end
		reg_addr_ack:	// send reg_addr_ack to master
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b011)	
			begin
				if(sda_out1)	
					main_state <= idle;
				else
				begin
                      //data_in_reg0<=data_from_memory;
						main_state <= data_write;
//					if(write_read)	 // '1': read			            
//						main_state <= data_read;				       
//					else		// '0': write
//						main_state <= data_write;
				end
			end
			else
				main_state <= reg_addr_ack;	
		end				
		data_write:	// read data from master			
		begin						 
 			if(data_in_state == data_end)			
				main_state <= data_in_ack;
			else
				main_state <= data_write;						    					      
		end
						
		data_in_ack:	// write data_in_ack to master		 
		begin
            if ({scl_regi0,scl_regi,scl_reg}==3'b100)
                flagToggle_add_write<=~flagToggle_add_write;
            else if({scl_regi0,scl_regi,scl_reg}==3'b011)					
				main_state <= if_rep_start;
			else                  
				main_state <= data_in_ack;			
		end	
								 
		data_read:	// write data to master
		begin    
            toggle_writeFromMemory<=~toggle_writeFromMemory;
			if(data_out_state==data_out_end && {scl_regi0,scl_regi,scl_reg}==3'b100)		              
			begin
				main_state <= data_out_ack;		             
			end                   
			else                  
			begin                 
				main_state <= data_read;			              
			end			            	           
		end
			
		data_out_ack:	// write data_out_ack to master
		begin			             
			if({scl_regi0,scl_regi,scl_reg}==3'b011)
				main_state <= if_rep_start;
			else                  
				main_state <= data_out_ack;
		end
			 
		if_rep_start:	// read restart from master
//		begin
//			if(stop_bus_reg)
//				main_state <= idle;
//			else if(start_bus_reg)
//                    begin
//                       main_state<= addr_read; 
//                    end
//
//				main_state <= reg_addr_read;
//			else if((write_read==1'b0)&&({scl_regi0,scl_regi,scl_reg}==3'b110))
//                    begin
//                        main_state <= data_write;
//                    end
//            else if ((write_read==1'b1)&&({scl_regi0,scl_regi,scl_reg}==3'b110))
//                    begin
//                        main_state  <= data_read;
//                    end
//                
//            else 
//				main_state <= if_rep_start;			 
//		end  
            begin
                if(write_read==1'b0)
                    begin
                        main_state<=data_write;
                    end
                else if(write_read==1'b1)
                    begin
                        if(sda_in1==1'b0)
                            begin
                                main_state<=data_read;
                            end
                        else if(sda_in1==1'b1)
                            begin
                                main_state<=if_rep_start;
                            end
                        else
                            begin
                                main_state<=if_rep_start;
                            end
                    end
                else if (stop_bus_reg)
                    begin
                        main_state<=idle;
                    end
                else if (start_bus_reg)
                    begin
                        main_state<=addr_read;
                    end
                else 
                    begin
                        main_state<=if_rep_start;
                    end
            end
		                        
		default:	main_state <= idle;
		endcase
        if(stop_bus_reg)
            begin
                main_state<= idle;
            end
        if((start_bus_reg==1'b1)&&(main_state!=(if_rep_start)))
            begin
                main_state<=addr_read;
            end
        
	end 
	
//------------------------------------------------------------------			
// send chip_id_ack to master           
always @(posedge clock or negedge reset_n2) //addr ack output
begin
	if(!reset_n2)
	begin 
		ack_state <= 2'b00;
		sda_en    <= 1'b0;//sda in
		flag      <= 1'b0;// 0 for sda_out1    1 for sda_out2
		sda_out1  <= 1'b0;//ack 
        sda_in1   <=1'b0;  //read ack from master to slave , default  value is 0 for ack,  verse  1 for no ack;
	end
	else
	begin
		case(ack_state)
		2'b00:
		begin
			if(main_state==addr_ack && {scl_regi0,scl_regi,scl_reg}==3'b100)    //to ack chip address           
			begin 
				if(addr_in_reg==device_id_full)   
					sda_out1 <= 1'b0;
				else
					sda_out1 <= 1'b1; 
					 
                                flag      <= 1'b0;    //send sda_out1                              
				sda_en    <= 1'b1;//sda out
				ack_state <= 2'b11;
			end
			else if(main_state==reg_addr_ack && {scl_regi0,scl_regi,scl_reg}==3'b100)// to ack register address
			begin

				if((reg_addr<=55)&&(reg_addr>=32))
                    begin
                        sda_out1<=1'b0;
                    end
                else
                    begin
                        sda_out1<=1'b1;
                    end
			    	flag      <= 1'b0;    //send sda_out1
				sda_en    <= 1'b1;
				ack_state <= 2'b11;  
			end 					 
			else if(main_state==data_in_ack && {scl_regi0,scl_regi,scl_reg}==3'b100)
			begin
				flag      <= 1'b0;    //send sda_out1
				sda_out1  <= 1'b0;    //??2
				sda_en    <= 1'b1;
				ack_state <= 2'b01;
			end
			else if(main_state==data_read && {scl_regi0,scl_regi,scl_reg}==3'b100)
			begin
				flag      <= 1'b1;
				sda_en    <= 1'b1;
				ack_state <= 2'b10;	//?master??????ack???
			end
            else if (main_state==data_out_ack && {scl_regi0,scl_regi,scl_reg}==3'b011)
                begin
                    sda_en <=1'b0;
                    sda_in1 <=sda_regi0;
                    ack_state <=2'b11;

                end

			else
				sda_en<=1'b0;
			end
		2'b01:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b100)
			begin
				sda_en    <= 1'b0;
				ack_state <= 2'b00;
			end
			else
				ack_state <= 2'b01; 
		end
		2'b10:
		begin
			if(main_state==data_read)
				ack_state <= 2'b10;
			else
			begin 
				ack_state <= 2'b00;
				sda_en    <= 1'b0;  
				flag      <= 1'b0;
			end
		end
		
		2'b11:
		begin
			if(main_state==data_read && {scl_regi0,scl_regi,scl_reg}==3'b100)
			begin
				flag      <= 1'b1;
				sda_en    <= 1'b1;
				ack_state <= 2'b10;
			end
			else if(main_state!=data_read && {scl_regi0,scl_regi,scl_reg}==3'b100)
			begin 
				ack_state <= 2'b00;
				sda_en    <= 1'b0;  
			end
			else
				ack_state <= 2'b11;
		end  
		default:	ack_state <= 2'b00;         
		endcase				 
	end
 end

//------------------------------------------------------------------	
//to read Chip_id from master

always @(posedge clock or negedge reset_n2)//to write chip address
	if(!reset_n2)
	begin 
		addr_in_state <= addr_in6;
		addr_in_reg   <= 7'b0000000;
	end
	else if(main_state==addr_read)
	begin
		case(addr_in_state)	
		addr_in6:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b011)
			begin
				addr_in_state  <= addr_in5;
				addr_in_reg[6] <= sda_regi;
			end
			else
				addr_in_state  <= addr_in6;
		end
			        
		addr_in5:					 
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b011)
			begin
				addr_in_state  <= addr_in4;
				addr_in_reg[5] <= sda_regi;
			end
			else
				addr_in_state  <= addr_in5;
		end				
		addr_in4:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b011)
			begin
				addr_in_state  <= addr_in3;
				addr_in_reg[4] <= sda_regi;
			end
			else
				addr_in_state  <= addr_in4;
		end				
		addr_in3:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b011)
			begin
				addr_in_state  <= addr_in2;
				addr_in_reg[3] <= sda_regi;
			end
			else
				addr_in_state  <= addr_in3;
		end			
		addr_in2:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b011)
			begin
				addr_in_state  <= addr_in1;
				addr_in_reg[2] <= sda_regi;
			end
			else
				addr_in_state  <= addr_in2;
		end				
		addr_in1:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b011)
			begin
				addr_in_state  <= addr_in0;
				addr_in_reg[1] <= sda_regi;
			end
			else
				addr_in_state  <= addr_in1;
		end				
		addr_in0:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b011)
			begin
				addr_in_state  <= addr_end;
				addr_in_reg[0] <= sda_regi;
			end
			else
				addr_in_state <= addr_in0;		    
		end
		addr_end:	addr_in_state <= addr_in6;
		default:	addr_in_state <= addr_in6;
		endcase
	end
	else
		addr_in_state  <= addr_in6;  

//------------------------------------------------------------------	
//to read data from master
 
always @(posedge clock or negedge reset_n2)
	if(!reset_n2)
	begin
		data_in_state <= data_in7;
		data_in_reg1  <= 8'b00000000;  //vgf  //0x00
        toggle_writeToMemory<=1'b0;

 
	end
	else
	begin
		if(main_state==data_write)
			case(data_in_state)	
			data_in7:
			begin	 
				if({scl_regi0,scl_regi,scl_reg}==3'b011)          
				begin	

						data_in_reg1[7] <= sda_regi;
					data_in_state <= data_in6;                             
				end
				else
					data_in_state <= data_in7; 
			end	
			data_in6:
			begin	
				if({scl_regi0,scl_regi,scl_reg}==3'b011)
				begin					     

						data_in_reg1[6] <= sda_regi;
					data_in_state <= data_in5;
				end
				else
					data_in_state <= data_in6; 
			end
			data_in5:
			begin	
				if({scl_regi0,scl_regi,scl_reg}==3'b011)
				begin					     
					data_in_state <= data_in4;
				
						data_in_reg1[5] <= sda_regi;
				end
				else
					data_in_state <= data_in5;     			
			end	
						
			data_in4:
			begin	
				if({scl_regi0,scl_regi,scl_reg}==3'b011)  	
				begin				    
					data_in_state <= data_in3;
						data_in_reg1[4] <= sda_regi;
				end	
				else
					data_in_state <= data_in4;    	
			end
					
			data_in3: 
			begin	
				if({scl_regi0,scl_regi,scl_reg}==3'b011)  
				begin					    
					data_in_state <= data_in2;

						data_in_reg1[3] <= sda_regi;
				
				end	
				else
					data_in_state <= data_in3;  	
			end
					
			data_in2:			 
			begin		
				if({scl_regi0,scl_regi,scl_reg}==3'b011)  
				begin				  

						data_in_reg1[2] <= sda_regi;
							
					data_in_state <= data_in1;
				end
				else
					data_in_state <= data_in2; 
			end
								
			data_in1:
			begin
				if({scl_regi0,scl_regi,scl_reg}==3'b011)   
				begin
					data_in_state <= data_in0;

						data_in_reg1[1] <= sda_regi;
					
				end	
				else
					data_in_state <= data_in1;   		
			end
							
			data_in0:
			begin
				if({scl_regi0,scl_regi,scl_reg}==3'b011) 
				begin
					data_in_state <= data_end;

						data_in_reg1[0] <= sda_regi;
				end	
				else
					data_in_state <= data_in0;   						    
			end 
					     
			data_end:
			begin

     
                toggle_writeToMemory<=~toggle_writeToMemory;
				data_in_state <= data_in7;
			end
			default: data_in_state <= data_in7;
			endcase
		else
			data_in_state <= data_in7;     
	end

//------------------------------------------------------------------	
//to read register addr from master

always @(posedge clock or negedge reset_n2)
begin
	if(!reset_n2)
	begin
		reg_addr       <= 8'b0010_0000;
		reg_addr_state <= reg_addr7; 
          flagToggle<=1'b0;

	end
	else
	begin
		if(main_state==reg_addr_read)
			case(reg_addr_state)	
			reg_addr7:
			begin	 
				if({scl_regi0,scl_regi,scl_reg}==3'b011)          
				begin	
					reg_addr[7]    <= sda_regi;          			    
					reg_addr_state <= reg_addr6;                             
				end
				else
					reg_addr_state <= reg_addr7; 
			end	
			reg_addr6:
			begin	
				if({scl_regi0,scl_regi,scl_reg}==3'b011)
				begin					     
					reg_addr[6]    <= sda_regi; 
					reg_addr_state <= reg_addr5;
				end
				else
					reg_addr_state <= reg_addr6; 
			end
			reg_addr5:
			begin	
				if({scl_regi0,scl_regi,scl_reg}==3'b011)
				begin	
					reg_addr[5]    <= sda_regi;				     
					reg_addr_state <= reg_addr4;						                      
				end
				else
					reg_addr_state <= reg_addr5;     			
			end	
			reg_addr4:
			begin	
				if({scl_regi0,scl_regi,scl_reg}==3'b011)  	
				begin				    
					reg_addr_state <= reg_addr3;
					reg_addr[4]    <= sda_regi;             
				end	
				else
					reg_addr_state <= reg_addr4;    	
			end
			reg_addr3: 
			begin	
				if({scl_regi0,scl_regi,scl_reg}==3'b011)  
				begin					    
					reg_addr_state <= reg_addr2;
					reg_addr[3]    <= sda_regi;          
				end	
				else
					reg_addr_state <= reg_addr3;  	
			end
			reg_addr2:			 
			begin		
				if({scl_regi0,scl_regi,scl_reg}==3'b011)  
				begin				  
					reg_addr[2]    <= sda_regi;           
					reg_addr_state <= reg_addr1;
				end
				else
					reg_addr_state <= reg_addr2; 
			end
			reg_addr1:
			begin
				if({scl_regi0,scl_regi,scl_reg}==3'b011)   
				begin
					reg_addr_state <= reg_addr0;
					reg_addr[1]    <= sda_regi;           
				end	
				else
					reg_addr_state <= reg_addr1;   		
			end
			reg_addr0:
			begin
				if({scl_regi0,scl_regi,scl_reg}==3'b011) 
				begin
					reg_addr_state <= reg_addr_end;
					reg_addr[0]    <= sda_regi;      
				end	
				else
					reg_addr_state<= reg_addr0;   						    
			end 
			reg_addr_end:
			begin
				reg_addr_state  <= reg_addr7;

                flagToggle<=~flagToggle;


			end                        
			default: reg_addr_state <= reg_addr7;
			endcase
		else
			reg_addr_state <= reg_addr7;     
	end
end
//---------------------------trans address to memory----------


//--------------------trans address to memory and count the address
always @(posedge clock or negedge reset_n2)
    begin
    if(!reset_n2)
        begin
            address<=8'b00100000;
        end
    else if(address_load)
        begin
            address<=reg_addr;
        end
    else if(address_add)
        begin
            if(address<55)
                begin
                    address<=address+1;
                end
            else if(address==55)
                begin
                    address<=32;
                end
            else
                begin
                    address<=8'b00100000;
                end
        end

    end

always @(posedge clock or negedge reset_n2)
    begin
        if(!reset_n2)
            begin
                
                address_FlagCreater<=3'b000;
            end
        else
            begin
                address_FlagCreater<={address_FlagCreater[1:0],flagToggle}; 
            end
    end

assign address_load=address_FlagCreater[2]^address_FlagCreater[1];

always @(posedge clock or negedge reset_n2)
    begin
        if(!reset_n2)
            begin
                
                address_FlagCreater_add2<= 3'b000;
            end
        else
            begin
                address_FlagCreater_add2<={address_FlagCreater_add2[1:0],flagToggle_add_write}; 
            end
    end

always @(posedge clock or negedge reset_n2)
    begin
        if(!reset_n2)
            begin
                address_FlagCreater_add1<= 3'b000;
            end
        else
            begin
                address_FlagCreater_add1<={address_FlagCreater_add1[1:0],flagToggle_add_read}; 
            end
    end
assign  address_add=(address_FlagCreater_add1[2]^address_FlagCreater_add1[1])||(address_FlagCreater_add2[2]^address_FlagCreater_add2[1]);

//---------------------to read data in task-------------------a-------------
 
always@(posedge clock or negedge reset_n2) //data read
	if(!reset_n2)
	begin
		data_out_state <= data_out7;
		sda_out2       <= 1'b0;  
        flagToggle_add_read<=1'b0;
	end
	else
	begin   
		case(data_out_state)
		data_out7:
		begin			                    
			if(main_state==data_read&&{scl_regi0,scl_regi,scl_reg}==3'b100)
			begin		                          
            
				sda_out2 <= data_in_reg0[7]; 
				data_out_state   <= data_out6;					                         
			end                         
			else                        
			begin                       
				data_out_state   <= data_out7; 
			end  
		end 
		data_out6:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b100)
			begin
				data_out_state   <= data_out5;
			                            
            
				sda_out2 <= data_in_reg0[6]; 
			end                         
			else                        
				data_out_state   <= data_out6;		
		end
		data_out5:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b100)
			begin
				data_out_state   <= data_out4;		                          
		 
				sda_out2 <= data_in_reg0[5]; 
			end                         
			else                        
				data_out_state   <= data_out5; 
		end
		data_out4:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b100)
			begin
				data_out_state   <= data_out3;			                          
            
				sda_out2 <= data_in_reg0[4]; 
			end	                    
			else                        
				data_out_state   <= data_out4; 		
		end
		data_out3:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b100)
			begin
				data_out_state   <= data_out2;		                          
           
				sda_out2 <= data_in_reg0[3]; 
			end	                    
			else                        
				data_out_state   <= data_out3; 		
		end
		data_out2:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b100) 
			begin
				data_out_state   <= data_out1;			                          
				             
				sda_out2 <= data_in_reg0[2]; 
			end                         
			else                        
				data_out_state   <= data_out2; 			
		end
		data_out1:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b100)
			begin
				data_out_state   <= data_out0;		                          
				
				sda_out2 <= data_in_reg0[1]; 
			end	
			else
				data_out_state   <=data_out1; 	
		end
		data_out0:
		begin
			if({scl_regi0,scl_regi,scl_reg}==3'b100)
			begin  
				data_out_state   <= data_out_end;

				sda_out2 <= data_in_reg0[0]; 
			end
			else
				data_out_state   <= data_out0;
			  			
		end
		data_out_end:
		begin
                //flagToggle_add_read<=~flagToggle_add_read;
			if({scl_regi0,scl_regi,scl_reg}==3'b100)
				begin
                    data_out_state <= data_out7;

                flagToggle_add_read<=~flagToggle_add_read;
                end
			else                      
				data_out_state <= data_out_end; 
		end                               
			                          
		default:	data_out_state <= data_out7;
		endcase	     
	end
//----------------------------load memory ----------- 

always @(posedge clock or negedge reset_n2)
    begin
        if(!reset_n2)
            begin 
                synchronizer_writeFromMemory<=3'b000;
            end
        else
            begin
                synchronizer_writeFromMemory<={synchronizer_writeFromMemory[1:0],toggle_writeFromMemory}; 
            end
    end

always @(posedge clock or negedge reset_n2)
    begin
        if(!reset_n2)
            begin 
                synchronizer_writeToMemory<=3'b000;
            end
        else
            begin
                synchronizer_writeToMemory<={synchronizer_writeToMemory[1:0],toggle_writeToMemory}; 
            end
    end

assign enable_writeToMemory=synchronizer_writeToMemory[2]^synchronizer_writeToMemory[1];
assign enable_writeFromMemory=synchronizer_writeFromMemory[2]^synchronizer_writeFromMemory[1];


assign data_in_reg0=data_from_memory;
assign data_to_memory=data_in_reg1;

endmodule

