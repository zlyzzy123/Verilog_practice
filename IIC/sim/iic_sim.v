`timescale 1ns / 1ps

module iic_sim;
parameter CLK_PERIOD = 20; //仿真周期20ns=50M
parameter RST_CYCLE = 10; //复位周期数
parameter RST_TIME = RST_CYCLE * CLK_PERIOD; 

reg sim_clk;
reg sim_rst_n;
reg I_pin1 ;
reg I_pin0 ;

initial
begin
    sim_clk = 0;
    sim_rst_n = 0;
    I_pin1 = 0 ;
	I_pin0 = 1 ;
    #RST_TIME sim_rst_n = 1;
end  

always #(CLK_PERIOD/2) sim_clk = ~sim_clk;

///////////////////////////////////////////////////////

reg           I_send_en           ;  // IIC发送使能
reg           I_recv_en           ;  // IIC接收使能
reg   [6:0]   I_dev_addr          ;  // IIC设备的物理地址
reg   [7:0]   I_word_addr         ;  // IIC设备的字地址，即操作的IIC设备的内部地址
reg   [7:0]   I_write_data        ;  // 往IIC设备的字地址写入的数据
reg           I_send_stop         ;  // 发送操作结束信号
reg           I_recv_stop         ;  // 接收操作结束信号
wire          O_send_done         ;  // 写IIC设备字节，发送完成标志位
wire          O_send_end          ;  // 写IIC设备操作，完成标志位
wire          O_recv_done         ;  // 读IIC设备字节，接收完成标志位
wire          O_recv_end          ;  // 读IIC设备操作，完成标志位
wire   [7:0]  O_recv_data         ;  // 从IIC设备的字地址读出的数据
wire          O_sda_master_oe     ;  // 设置SDA（方向）模式，1为输出，0为输入
wire          O_sda_master_out    ;  // SDA寄存器，用于SDA输出
wire          I_sda_master_in     ;  // IIC总线的双向串行数据线SDA
wire          IO_sda              ;
wire          O_scl               ;

wire          O_sda_slave_out     ; // SDA输出寄存器       
                                
iic_master U_iic_master(        
    .I_clk               ( sim_clk            ),
    .I_rst_n             ( sim_rst_n          ),
    .I_send_en           ( I_send_en          ),
    .I_recv_en           ( I_recv_en          ),
    .I_dev_addr          ( I_dev_addr         ),
    .I_word_addr         ( I_word_addr        ),
    .I_write_data        ( I_write_data       ),
    .I_send_stop         ( I_send_stop        ),
    .I_recv_stop         ( I_recv_stop        ),
    .O_send_done         ( O_send_done        ),
    .O_send_end          ( O_send_end         ),
    .O_recv_done         ( O_recv_done        ),
    .O_recv_end          ( O_recv_end         ),
    .O_recv_data         ( O_recv_data        ),                                      
// 标准的IIC总线相关信号线                          
    .I_sda_in            ( I_sda_master_in    ), 
    .O_sda_out           ( O_sda_master_out   ),
    .O_sda_oe            ( O_sda_master_oe    ), 
    .O_scl               ( O_scl              )	
);        

// master接口三态门            
assign IO_sda           = O_sda_master_oe ? O_sda_master_out: O_sda_slave_out ;//inout
assign I_sda_master_in  = IO_sda ;
  
//********************************************************************************
reg    [7:0]   I_read_data        ; // 来自于存储地址的数据，或将要被主机读的数据
wire   [6:0]   O_dev_addr         ; // 从机接口将接收到的设备地址输出给从机
wire   [7:0]   O_word_addr        ; // 从机接口将接收到的存储地址输出给从机
wire   [7:0]   O_write_data       ; // 写入存储地址的数据，或从主机将要写入存储器的数据
wire           O_get_end          ; // 写存储器操作结束标志
wire           O_get_done         ; // 写存储器一个字节数据操作完成标志
wire           O_read_end         ; // 读存储器操作结束标志
wire           O_read_done        ; // 读存储器一个字节数据操作完成标志
wire           I_sda_slave_in     ; // SDA模式，1为输出，0为输入
//wire           O_sda_slave_out    ; // SDA输出寄存器                                                  
wire           O_sda_slave_oe     ;

			 
iic_slave U_iic_slave(            
    .I_clk             ( sim_clk            ),
    .I_rst_n           ( sim_rst_n          ),
	.I_pin0            ( I_pin0             ),
	.I_pin1            ( I_pin1             ),
    .I_read_data       ( I_read_data        ),
    .O_dev_addr        ( O_dev_addr         ),
    .O_word_addr       ( O_word_addr        ),
    .O_write_data      ( O_write_data       ),
    .O_get_end         ( O_get_end          ),
    .O_get_done        ( O_get_done         ),
    .O_read_end        ( O_read_end         ),
    .O_read_done       ( O_read_done        ),
	// 标准的IIC总线相关信号线
    .I_sda_in          ( I_sda_slave_in     ),
    .O_sda_out         ( O_sda_slave_out    ),
    .O_sda_oe          ( O_sda_slave_oe     ),
    .I_scl             ( O_scl              )
);

// slave接口三态门         
//assign IO_sda           =  O_sda_slave_oe ? O_sda_slave_out: O_sda_master_out ;
assign I_sda_slave_in   =  IO_sda ;

//**********************************************************************debug*****************************************************
/*                       
//**********************************写操作仿真*********************************
reg [7:0] cnt  ;
always@(posedge sim_clk , negedge sim_rst_n )
begin
    if(!sim_rst_n)
       begin
          I_send_en     <=  1'b1        ;
		  I_recv_en     <=  1'b0        ;
		  I_dev_addr    <=  7'b10100_00 ;
		  I_word_addr   <=  8'h23       ;
		  I_send_stop   <=  1'b0        ;
		  I_recv_stop   <=  1'b0        ;	       
	      I_write_data  <=  8'h01       ;
		  I_read_data	<=  8'h00       ;
		  cnt           <=  1'b0        ;
       end
	else if(cnt==251)  
	   begin	      
		  I_send_stop   <=  1'b1        ;
		  if(O_send_end)  
		     begin
			    I_send_en     <=  1'b0  ;
		     end 
		  else	I_send_stop   <=  1'b1  ; 
	   end	
	else if(O_send_done)    
	   begin
	      cnt  <=  cnt + 1 ; 
		  I_write_data  <=  I_write_data  + 1    ;
	   end 
end
*/
 
//**********************************读操作仿真*********************************
reg [7:0]  cnt ;
always@(posedge sim_clk , negedge sim_rst_n )
begin
    if(!sim_rst_n)
       begin            
          I_send_en     <=  1'b0        ;
		  I_recv_en     <=  1'b1        ;
		  I_dev_addr    <=  7'b10100_00 ;
		  I_word_addr   <=  8'h23       ;
		  I_send_stop   <=  1'b0        ;
		  I_recv_stop   <=  1'b0        ;
		  I_write_data  <=  8'h00       ;
		  I_read_data	<=  8'h00       ;
		  cnt           <=  1'b0        ;	
       end
	else if(cnt==251)  
	   begin
		  I_recv_stop   <=  1'b1        ;
		  if(O_recv_end)  
		     begin
			    I_recv_en     <=  1'b0  ;
		     end 
		  else	I_recv_stop   <=  1'b1  ; 
	   end   
	else if(O_recv_done)  
	   begin
	      cnt	<=  cnt + 1  ;
          I_read_data	<=  I_read_data + 1  ;	      
	   end   	   
end

// 写8个字节

////////////////////////////////////////////////////////
/*
// 写8个字节
reg [3:0] cnt  ;
always@(posedge sim_clk , negedge sim_rst_n )
begin
    if(!sim_rst_n)
       begin
          I_send_en     <=  1'b1        ;
		  I_recv_en     <=  1'b0        ;
		  I_dev_addr    <=  7'b10100_00 ;
		  I_word_addr   <=  8'h23       ;
		  I_send_stop   <=  1'b0        ;
		  I_recv_stop   <=  1'b0        ;	       
	      I_write_data  <=  8'h01       ;
		  I_read_data	<=  8'h00       ;
		  cnt           <=  1'b0        ;
       end
	else if(cnt==8)  
	   begin	      
		  I_send_stop   <=  1'b1        ;
		  if(O_send_end)  
		     begin
			    I_send_en     <=  1'b0  ;
		     end 
		  else	I_send_stop   <=  1'b1  ; 
	   end	
	else if(O_send_done)    
	   begin
	      cnt  <=  cnt + 1 ; 
		  I_write_data  <=  I_write_data  + 1    ;
	   end 
end
*/
/*
//读8个字节
reg [3:0]  cnt ;
always@(posedge sim_clk , negedge sim_rst_n )
begin
    if(!sim_rst_n)
       begin            
          I_send_en     <=  1'b0        ;
		  I_recv_en     <=  1'b1        ;
		  I_dev_addr    <=  7'b10100_00 ;
		  I_word_addr   <=  8'h23       ;
		  I_send_stop   <=  1'b0        ;
		  I_recv_stop   <=  1'b0        ;
		  I_write_data  <=  8'h00       ;
		  I_read_data	<=  8'h01       ;
		  cnt           <=  1'b0        ;	
       end
	else if(cnt==8)  
	   begin
		  I_recv_stop   <=  1'b1        ;
		  if(O_recv_end)  
		     begin
			    I_recv_en     <=  1'b0  ;
		     end 
		  else	I_recv_stop   <=  1'b1  ; 
	   end   
	else if(O_recv_done)  
	   begin
	      cnt	<=  cnt + 1  ;
          I_read_data	<=  I_read_data + 1  ;	      
	   end   	   
end
*/


endmodule
