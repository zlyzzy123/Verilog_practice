
//接收模块

module spi_tx
(
	input        [4:0]  state          , // SPI输出，用来给从机发送数据     
    input               I_clk          , // 全局时钟50MHz
    input               I_rst_n        , // 复位信号，低电平有效
    input               I_cpol         , // 时钟极性-----//传输模式选择
    input               I_rx_en        , // 接收使能信号
    input               I_tx_en        , // 发送使能信号
    input        [7:0]  I_data_in      , // 要发送的数据
    output  reg         O_tx_done      , // 发送一个字节完毕标志位
    
    // 四线标准SPI信号定义
    output  reg         O_spi_sck_tx   , // SPI时钟
    output  reg         O_spi_cs_tx    , // SPI片选信号
    output  reg         O_spi_mosi       // SPI输出，用来给从机发送数据          
);


reg [3:0]   R_tx_state      ; 


parameter idle  =  5'b00001  ;//空闲状态
parameter mode0 =  5'b00010  ;//模式0
parameter mode1 =  5'b00100  ;//模式1
parameter mode2 =  5'b01000  ;//模式2
parameter mode3 =  5'b10000  ;//模式3


//*********************************************************发送****************************************************************************		 
always @(posedge I_clk or negedge I_rst_n)
    begin
	    if(!I_rst_n)//复位情况
		 begin
			case(I_cpol)
			1'b0:
				  begin
					R_tx_state     <=   4'd0    ;
					O_spi_cs_tx    <=   1'b1    ;			
					O_spi_mosi     <=   1'b0    ;
					O_tx_done      <=   1'b0    ;
					O_spi_sck_tx   <=   1'b0	;					
				  end
			1'b1:
				  begin
					R_tx_state     <=   4'd0    ;
					O_spi_cs_tx    <=   1'b1    ;			
					O_spi_mosi     <=   1'b0    ;
					O_tx_done      <=   1'b0    ;
					O_spi_sck_tx   <=   1'b1	;									
			      end
			endcase	  
		 end		  
	    else 
		  case(state)
//////////////////////////////////////////////////////idle///////////////////////////////////////////////////////
		    idle: begin
	              	R_tx_state    <=  4'd0    ;
	            	O_spi_cs_tx   <=  1'b1    ;			
	            	O_spi_mosi    <=  1'b0    ;
	            	O_tx_done     <=  1'b0    ;
				  end
				   
//////////////////////////////////////////////////////mode0///////////////////////////////////////////////////////		    
			mode0: begin
					if((!I_tx_en)&&(!I_rx_en))
						O_spi_sck_tx   <=  1'b0;//既不发送也不接收
						     else if(I_tx_en) // 发送使能信号打开的情况下
						     	begin
						     		O_spi_cs_tx    <=  1'b0    ; // 把片选CS拉低
						     		case(R_tx_state)
						     			4'd1, 4'd3 , 4'd5 , 4'd7  , 
						     			4'd9, 4'd11, 4'd13, 4'd15 : //整合奇数状态
						     				begin
						     					O_spi_sck_tx   <=   1'b1                ;
						     					R_tx_state     <=   R_tx_state + 1'b1   ;
						     					O_tx_done      <=   1'b0                ;
						     				end
						     			4'd0:    // 发送第7位
						     				begin
						     					O_spi_mosi     <=   I_data_in[7]        ;
						     					O_spi_sck_tx   <=   1'b0                ;
						     					R_tx_state     <=   R_tx_state + 1'b1   ;
						     					O_tx_done      <=   1'b0                ;
						     				end
						     			4'd2:    // 发送第6位
						     				begin
						     					O_spi_mosi     <=   I_data_in[6]        ;
						     					O_spi_sck_tx   <=   1'b0                ;
						     					R_tx_state     <=   R_tx_state + 1'b1   ;
						     					O_tx_done      <=   1'b0                ;
						     				end
						     			4'd4:    // 发送第5位
						     				begin
						     					O_spi_mosi     <=   I_data_in[5]        ;
						     					O_spi_sck_tx   <=   1'b0                ;
						     					R_tx_state     <=   R_tx_state + 1'b1   ;
						     					O_tx_done      <=   1'b0                ;
						     				end 
						     			4'd6:    // 发送第4位
						     				begin
						     					O_spi_mosi     <=   I_data_in[4]        ;
						     					O_spi_sck_tx   <=   1'b0                ;
						     					R_tx_state     <=   R_tx_state + 1'b1   ;
						     					O_tx_done      <=   1'b0                ;
						     				end 
						     			4'd8:    // 发送第3位
						     				begin
						     					O_spi_mosi     <=   I_data_in[3]        ;
						     					O_spi_sck_tx   <=   1'b0                ;
						     					R_tx_state     <=   R_tx_state + 1'b1   ;
						     					O_tx_done      <=   1'b0                ;
						     				end                            
						     			4'd10:    // 发送第2位
						     				begin
						     					O_spi_mosi     <=   I_data_in[2]        ;
						     					O_spi_sck_tx   <=   1'b0                ;
						     					R_tx_state     <=   R_tx_state + 1'b1   ;
						     					O_tx_done      <=   1'b0                ;
						     				end 
						     			4'd12:    // 发送第1位
						     				begin
						     					O_spi_mosi     <=   I_data_in[1]        ;
						     					O_spi_sck_tx   <=   1'b0                ;
						     					R_tx_state     <=   R_tx_state + 1'b1   ;
						     					O_tx_done      <=   1'b0                ;
						     				end 
						     			4'd14:    // 发送第0位
						     				begin
						     					O_spi_mosi     <=   I_data_in[0]        ;
						     					O_spi_sck_tx   <=   1'b0                ;
						     					R_tx_state     <=   R_tx_state + 1'b1   ;
						     					O_tx_done      <=   1'b1                ;
						     				end
						     			default:R_tx_state  <=  4'd0                    ;   
						     		endcase 
						     	end
						   
				              else if(!I_rx_en)
						     	begin
						     		R_tx_state     <=   4'd0    ;
						     		O_tx_done      <=   1'b0    ;
						     		O_spi_cs_tx    <=   1'b1    ;
						     		O_spi_sck_tx   <=   1'b0    ;
						     		O_spi_mosi     <=   1'b0    ;
						     	end      
				             
				   end       
	                         
//////////////////////////////////////////////////////mode1/////////////////////////////////////////////////////		    
			mode1: begin
					if((!I_tx_en)&&(!I_rx_en))
						O_spi_sck_tx   <=  1'b0;//既不发送也不接收
									
						 else if(I_tx_en) // 发送使能信号打开的情况下
							begin
								O_spi_cs_tx    <=  1'b0    ; // 把片选CS拉低
								case(R_tx_state)
									4'd1, 4'd3 , 4'd5 , 4'd7  , 
									4'd9, 4'd11, 4'd13, 4'd15 : //整合奇数状态
										begin
											O_spi_sck_tx   <=   1'b0                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end
									4'd0:    // 发送第7位
										begin
											O_spi_mosi     <=   I_data_in[7]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end
									4'd2:    // 发送第6位
										begin
											O_spi_mosi     <=   I_data_in[6]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end
									4'd4:    // 发送第5位
										begin
											O_spi_mosi     <=   I_data_in[5]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end 
									4'd6:    // 发送第4位
										begin
											O_spi_mosi     <=   I_data_in[4]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end 
									4'd8:    // 发送第3位
										begin                  
											O_spi_mosi     <=   I_data_in[3]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                            
									4'd10:    // 发送第2位
										begin
											O_spi_mosi     <=   I_data_in[2]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end 
									4'd12:    // 发送第1位
										begin
											O_spi_mosi     <=   I_data_in[1]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end 
									4'd14:    // 发送第0位
										begin
											O_spi_mosi     <=   I_data_in[0]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b1                ;
										end
									default:R_tx_state  <=  4'd0                    ;   
								endcase 
							end
						 
				
				         else if(!I_rx_en)
							begin
						     		R_tx_state     <=   4'd0    ;
						     		O_tx_done      <=   1'b0    ;
						     		O_spi_cs_tx    <=   1'b1    ;
						     		O_spi_sck_tx   <=   1'b0    ;
						     		O_spi_mosi     <=   1'b0    ;
							end      
				
				   end
				
//////////////////////////////////////////////////////////////mode2////////////////////////////////////////////		    
			mode2: begin
					if((!I_tx_en)&&(!I_rx_en))
						O_spi_sck_tx   <=  1'b1;//既不发送也不接收
									
						 else if(I_tx_en) // 发送使能信号打开的情况下
							begin
								O_spi_cs_tx    <=  1'b0    ; // 把片选CS拉低
								case(R_tx_state)
									4'd1, 4'd3 , 4'd5 , 4'd7  , 
									4'd9, 4'd11, 4'd13, 4'd15 : //整合奇数状态
										begin                   
											O_spi_sck_tx   <=   1'b0                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd0:    // 发送第7位       
										begin                   
											O_spi_mosi     <=   I_data_in[7]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd2:    // 发送第6位       
										begin                   
											O_spi_mosi     <=   I_data_in[6]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd4:    // 发送第5位       
										begin                   
											O_spi_mosi     <=   I_data_in[5]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd6:    // 发送第4位       
										begin                   
											O_spi_mosi     <=   I_data_in[4]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd8:    // 发送第3位       
										begin                   
											O_spi_mosi     <=   I_data_in[3]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                             
									4'd10:    // 发送第2位      
										begin                   
											O_spi_mosi     <=   I_data_in[2]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd12:    // 发送第1位      
										begin                   
											O_spi_mosi     <=   I_data_in[1]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd14:    // 发送第0位      
										begin                   
											O_spi_mosi     <=   I_data_in[0]        ;
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b1                ;
										end 
									default:R_tx_state  <=  4'd0                    ;   
								endcase  
							end
						 
				
				         else if(!I_rx_en)
							begin
						     		R_tx_state     <=   4'd0    ;
						     		O_tx_done      <=   1'b0    ;
						     		O_spi_cs_tx    <=   1'b1    ;
						     		O_spi_sck_tx   <=   1'b0    ;
						     		O_spi_mosi     <=   1'b0    ;
							end      
				
				   end
				   
//////////////////////////////////////////////////////mode3/////////////////////////////////////////////////////		    
			mode3: begin 
					if((!I_tx_en)&&(!I_rx_en))
						O_spi_sck_tx   <=  1'b1;//既不发送也不接收
						
						 else if(I_tx_en) // 发送使能信号打开的情况下
							begin
								O_spi_cs_tx    <=  1'b0    ; // 把片选CS拉低
								case(R_tx_state)
									4'd1, 4'd3 , 4'd5 , 4'd7  , 
									4'd9, 4'd11, 4'd13, 4'd15 : //整合奇数状态
										begin
											O_spi_sck_tx   <=   1'b1                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd0:    // 发送第7位       
										begin                   
											O_spi_mosi     <=   I_data_in[7]        ;
											O_spi_sck_tx   <=   1'b0                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd2:    // 发送第6位       
										begin                   
											O_spi_mosi     <=   I_data_in[6]        ;
											O_spi_sck_tx   <=   1'b0                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd4:    // 发送第5位       
										begin                   
											O_spi_mosi     <=   I_data_in[5]        ;
											O_spi_sck_tx   <=   1'b0                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd6:    // 发送第4位       
										begin                   
											O_spi_mosi     <=   I_data_in[4]        ;
											O_spi_sck_tx   <=   1'b0                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd8:    // 发送第3位       
										begin                   
											O_spi_mosi     <=   I_data_in[3]        ;
											O_spi_sck_tx   <=   1'b0                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                             
									4'd10:    // 发送第2位      
										begin                   
											O_spi_mosi     <=   I_data_in[2]        ;
											O_spi_sck_tx   <=   1'b0                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd12:    // 发送第1位      
										begin                   
											O_spi_mosi     <=   I_data_in[1]        ;
											O_spi_sck_tx   <=   1'b0                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b0                ;
										end                     
									4'd14:    // 发送第0位      
										begin                   
											O_spi_mosi     <=   I_data_in[0]        ;
											O_spi_sck_tx   <=   1'b0                ;
											R_tx_state     <=   R_tx_state + 1'b1   ;
											O_tx_done      <=   1'b1                ;
										end 
									default:R_tx_state  <=  4'd0                    ;   
								endcase 
							end
						 
				
				         else if(!I_rx_en)
							begin
								R_tx_state     <=   4'd0    ;
								O_tx_done      <=   1'b0    ;
								O_spi_cs_tx    <=   1'b1    ;
								O_spi_sck_tx   <=   1'b1    ;
								O_spi_mosi     <=   1'b0    ;
							end      
				
				   end			
			
			
				default:begin
		                  R_tx_state     <=   4'd0    ;
		                  O_spi_cs_tx    <=   1'b1    ;			
		                  O_spi_mosi     <=   1'b0    ;
		                  O_tx_done      <=   1'b0    ;
				        end				

	
		  endcase     	
	end 

endmodule