
//发送模块

module spi_rx
(
    input               I_clk          , // 全局时钟50MHz
    input               I_rst_n        , // 复位信号，低电平有效
    input               I_cpol         , // 时钟极性-----//传输模式选择
    input               I_rx_en        , // 接收使能信号
    input               I_tx_en        , // 发送使能信号
    output  reg  [7:0]  O_data_out     , // 接收到的数据
    output  reg         O_rx_done      , // 接收一个字节完毕标志位
    
    // 四线标准SPI信号定义
    input               I_spi_miso     , // SPI串行输入，用来接收从机的数据
	input        [4:0]  state          , // SPI输出，用来给从机发送数据       
    output  reg         O_spi_sck_rx   , // SPI时钟
    output  reg         O_spi_cs_rx      // SPI片选信号
);


reg [3:0]   R_rx_state       ;


parameter idle  =  5'b00001  ;//空闲状态
parameter mode0 =  5'b00010  ;//模式0
parameter mode1 =  5'b00100  ;//模式1
parameter mode2 =  5'b01000  ;//模式2
parameter mode3 =  5'b10000  ;//模式3
	
	
//*********************************************************接收****************************************************************************	
	always @(posedge I_clk or negedge I_rst_n)
    begin
	    if(!I_rst_n)//复位情况
		 begin
			case(I_cpol)
			1'b0:
				  begin
					R_rx_state    <=   4'd0    ;
					O_spi_cs_rx   <=   1'b1    ;			
					O_rx_done     <=   1'b0    ;
					O_data_out    <=   8'd0    ;
					O_spi_sck_rx  <=   1'b0	   ;					
				  end
			1'b1:
				  begin
					R_rx_state    <=  4'd0    ;
					O_spi_cs_rx   <=  1'b1    ;			
					O_rx_done     <=  1'b0    ;
					O_data_out    <=  8'd0    ;
					O_spi_sck_rx  <=  1'b1	  ;									
			      end
			endcase	  
		 end		  
	    else 
		  case(state)
//////////////////////////////////////////////////////idle///////////////////////////////////////////////////////
		    idle: begin
			R_rx_state    <=   4'd0    ;
			O_spi_cs_rx   <=   1'b1    ;			
			O_rx_done     <=   1'b0    ;
			O_data_out    <=   8'd0    ;   
				   end
				   
//////////////////////////////////////////////////////mode0///////////////////////////////////////////////////////		    
			mode0: begin
					if((!I_tx_en)&&(!I_rx_en))
						O_spi_sck_rx   <=  1'b0;//既不发送也不接收
						
						      else if(I_rx_en) // 接收使能信号打开的情况下
						     	begin
						     		O_spi_cs_rx    <=  1'b0        ; // 拉低片选信号CS
						     		case(R_rx_state)
						     			4'd0, 4'd2 , 4'd4 , 4'd6  , 
						     			4'd8, 4'd10, 4'd12, 4'd14 : //整合偶数状态
						     				begin
						     					O_spi_sck_rx    <=  1'b0                ;
						     					R_rx_state      <=  R_rx_state + 1'b1   ;
						     					O_rx_done       <=  1'b0                ;
						     				end
						     			4'd1:    // 接收第7位
						     				begin                       
						     					O_spi_sck_rx    <=  1'b1                ;
						     					R_rx_state      <=  R_rx_state + 1'b1   ;
						     					O_rx_done       <=  1'b0                ;
						     					O_data_out[7]   <=  I_spi_miso          ;   
						     				end
						     			4'd3:    // 接收第6位
						     				begin
						     					O_spi_sck_rx    <=  1'b1                ;
						     					R_rx_state      <=  R_rx_state + 1'b1   ;
						     					O_rx_done       <=  1'b0                ;
						     					O_data_out[6]   <=  I_spi_miso          ; 
						     				end
						     			4'd5:    // 接收第5位
						     				begin
						     					O_spi_sck_rx    <=  1'b1                ;
						     					R_rx_state      <=  R_rx_state + 1'b1   ;
						     					O_rx_done       <=  1'b0                ;
						     					O_data_out[5]   <=  I_spi_miso          ; 
						     				end 
						     			4'd7:    // 接收第4位
						     				begin
						     					O_spi_sck_rx    <=  1'b1                ;
						     					R_rx_state      <=  R_rx_state + 1'b1   ;
						     					O_rx_done       <=  1'b0                ;
						     					O_data_out[4]   <=  I_spi_miso          ; 
						     				end 
						     			4'd9:    // 接收第3位
						     				begin
						     					O_spi_sck_rx    <=  1'b1                ;
						     					R_rx_state      <=  R_rx_state + 1'b1   ;
						     					O_rx_done       <=  1'b0                ;
						     					O_data_out[3]   <=  I_spi_miso          ; 
						     				end                            
						     			4'd11:    // 接收第2位
						     				begin
						     					O_spi_sck_rx    <=  1'b1                ;
						     					R_rx_state      <=  R_rx_state + 1'b1   ;
						     					O_rx_done       <=  1'b0                ;
						     					O_data_out[2]   <=  I_spi_miso          ; 
						     				end 
						     			4'd13:    // 接收第1位
						     				begin
						     					O_spi_sck_rx    <=  1'b1                ;
						     					R_rx_state      <=  R_rx_state + 1'b1   ;
						     					O_rx_done       <=  1'b0                ;
						     					O_data_out[1]   <=  I_spi_miso          ; 
						     				end 
						     			4'd15:    // 接收第0位
						     				begin
						     					O_spi_sck_rx    <=  1'b1                ;
						     					R_rx_state      <=  R_rx_state + 1'b1   ;
						     					O_rx_done       <=  1'b1                ;
						     					O_data_out[0]   <=  I_spi_miso          ; 
						     				end
						     			default:R_rx_state  <=  4'd0                    ;   
						     		endcase 			
						     	end 
				             
				              else if(!I_tx_en)
						     	begin
						     		R_rx_state    <=  4'd0    ;
						     		O_rx_done     <=  1'b0    ;
						     		O_spi_cs_rx   <=  1'b1    ;
						     		O_spi_sck_rx  <=  1'b0    ;
						     		O_data_out    <=  8'd0    ;
						     	end      
				             
				   end       
	                         
//////////////////////////////////////////////////////mode1/////////////////////////////////////////////////////		    
			mode1: begin
					if((!I_tx_en)&&(!I_rx_en))
						O_spi_sck_rx   <=  1'b0;//既不发送也不接收
									
						 
						 else if(I_rx_en) // 接收使能信号打开的情况下
							begin
								O_spi_cs_rx    <=  1'b0        ; // 拉低片选信号CS
								case(R_rx_state)
									4'd0, 4'd2 , 4'd4 , 4'd6  , 
									4'd8, 4'd10, 4'd12, 4'd14 : //整合偶数状态
										begin
											O_spi_sck_rx    <=  1'b1                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
										end
									4'd1:    // 接收第7位
										begin                       
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[7]   <=  I_spi_miso          ;   
										end
									4'd3:    // 接收第6位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[6]   <=  I_spi_miso          ; 
										end
									4'd5:    // 接收第5位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[5]   <=  I_spi_miso          ; 
										end 
									4'd7:    // 接收第4位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[4]   <=  I_spi_miso          ; 
										end 
									4'd9:    // 接收第3位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[3]   <=  I_spi_miso          ; 
										end                            
									4'd11:    // 接收第2位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[2]   <=  I_spi_miso          ; 
										end 
									4'd13:    // 接收第1位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[1]   <=  I_spi_miso          ; 
										end 
									4'd15:    // 接收第0位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b1                ;
											O_data_out[0]   <=  I_spi_miso          ; 
										end
									default:R_rx_state  <=  4'd0                    ;   
								endcase 			
							end 
				
				         else if(!I_tx_en)
							begin
						     		R_rx_state     <=   4'd0    ;
						     		O_rx_done      <=   1'b0    ;
						     		O_spi_cs_rx    <=   1'b1    ;
						     		O_spi_sck_rx   <=   1'b0    ;
						     		O_data_out     <=   8'd0    ;
							end      
				
				   end
			
//////////////////////////////////////////////////////////////mode2////////////////////////////////////////////		    
			mode2: begin
					if((!I_tx_en)&&(!I_rx_en))
						O_spi_sck_rx   <=  1'b1;//既不发送也不接收
									
						
						 else if(I_rx_en) // 接收使能信号打开的情况下
							begin
								O_spi_cs_rx    <=  1'b0        ; // 拉低片选信号CS
								case(R_rx_state)
									4'd0, 4'd2 , 4'd4 , 4'd6  , 
									4'd8, 4'd10, 4'd12, 4'd14 : //整合偶数状态
										begin
											O_spi_sck_rx    <=  1'b1                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
										end
									4'd1:    // 接收第7位
										begin                       
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[7]   <=  I_spi_miso          ;   
										end
									4'd3:    // 接收第6位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[6]   <=  I_spi_miso          ; 
										end
									4'd5:    // 接收第5位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[5]   <=  I_spi_miso          ; 
										end 
									4'd7:    // 接收第4位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[4]   <=  I_spi_miso          ; 
										end 
									4'd9:    // 接收第3位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[3]   <=  I_spi_miso          ; 
										end                            
									4'd11:    // 接收第2位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[2]   <=  I_spi_miso          ; 
										end 
									4'd13:    // 接收第1位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[1]   <=  I_spi_miso          ; 
										end 
									4'd15:    // 接收第0位
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b1                ;
											O_data_out[0]   <=  I_spi_miso          ; 
										end
									default:R_rx_state  <=  4'd0                    ;   
								endcase 			
							end 
				
				         else if(!I_tx_en)
							begin
						     		R_rx_state     <=    4'd0    ;
						     		O_rx_done      <=    1'b0    ;
						     		O_spi_cs_rx    <=    1'b1    ;
						     		O_spi_sck_rx   <=    1'b0    ;
						     		O_data_out     <=    8'd0    ;
							end      
				
				   end
				   
//////////////////////////////////////////////////////mode3/////////////////////////////////////////////////////		    
			mode3: begin 
					if((!I_tx_en)&&(!I_rx_en))
						O_spi_sck_rx   <=  1'b1;//既不发送也不接收
						
						 else if(I_rx_en) // 接收使能信号打开的情况下
							begin
								O_spi_cs_rx    <=  1'b0        ; // 拉低片选信号CS
								case(R_rx_state)
									4'd0, 4'd2 , 4'd4 , 4'd6  , 
									4'd8, 4'd10, 4'd12, 4'd14 : //整合偶数状态
										begin
											O_spi_sck_rx    <=  1'b0                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
										end
									4'd1:    // 接收第7位
										begin                       
											O_spi_sck_rx    <=  1'b1                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[7]   <=  I_spi_miso          ;   
										end
									4'd3:    // 接收第6位
										begin
											O_spi_sck_rx    <=  1'b1                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[6]   <=  I_spi_miso          ; 
										end
									4'd5:    // 接收第5位
										begin
											O_spi_sck_rx    <=  1'b1                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[5]   <=  I_spi_miso          ; 
										end 
									4'd7:    // 接收第4位
										begin
											O_spi_sck_rx    <=  1'b1                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[4]   <=  I_spi_miso          ; 
										end 
									4'd9:    // 接收第3位
										begin
											O_spi_sck_rx    <=  1'b1                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[3]   <=  I_spi_miso          ; 
										end                            
									4'd11:    // 接收第2位
										begin
											O_spi_sck_rx    <=  1'b1                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[2]   <=  I_spi_miso          ; 
										end 
									4'd13:    // 接收第1位
										begin
											O_spi_sck_rx    <=  1'b1                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b0                ;
											O_data_out[1]   <=  I_spi_miso          ; 
										end 
									4'd15:    // 接收第0位
										begin
											O_spi_sck_rx    <=  1'b1                ;
											R_rx_state      <=  R_rx_state + 1'b1   ;
											O_rx_done       <=  1'b1                ;
											O_data_out[0]   <=  I_spi_miso          ; 
										end
									default:R_rx_state  <=  4'd0                    ;   
								endcase 			
							end 
				
				         else if(!I_tx_en)
							begin
								R_rx_state     <=    4'd0    ;
								O_rx_done      <=    1'b0    ;
								O_spi_cs_rx    <=    1'b1    ;
								O_spi_sck_rx   <=    1'b1    ;
								O_data_out     <=    8'd0    ;
							end      
				
				   end			
			
			
				default: begin
		                   R_rx_state     <=    4'd0    ;
		                   O_spi_cs_rx    <=    1'b1    ;			
		                   O_rx_done      <=    1'b0    ;
		                   O_data_out     <=    8'd0    ;   
				         end 	
	
		  endcase     	
	end
	
	
endmodule