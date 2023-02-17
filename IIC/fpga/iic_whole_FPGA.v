//FPGA验证用
`timescale 1ns / 1ps

module iic_whole(
    input                  I_clk                        ,  // 系统时钟
    input                  I_rst_n                      ,  // 系统复位
// master
	output                 O_scl                        ,  // IIC总线的串行时钟线SCL
	inout                  IO_sda_master                ,  // master SDA
// slave
	input                  I_scl                        ,  // IIC总线的串行时钟线SCL
	inout                  IO_sda_slave                    // slave SDA
);

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
wire          IO_sda_master       ;
                                
iic_master U_iic_master(        
    .I_clk               ( I_clk              ),
    .I_rst_n             ( I_rst_n            ),
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
assign IO_sda_master    = O_sda_master_oe ? O_sda_master_out: 1'bz ;//inout
assign I_sda_master_in  = IO_sda_master ;

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
wire           O_sda_slave_out    ; // SDA输出寄存器                                                       
wire           O_sda_slave_oe     ;
wire           IO_sda_slave       ;

// 用来配置验证中的该从机设备地址的低两位
reg            I_pin1 = 0 ;
reg            I_pin0 = 0 ;	
	
iic_slave U_iic_slave(            
    .I_clk             ( I_clk              ),
    .I_rst_n           ( I_rst_n            ),
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
    .I_scl             ( I_scl              )
);

// slave接口三态门         
assign IO_sda_slave     =  O_sda_slave_oe ? O_sda_slave_out: 1'bz ;
assign I_sda_slave_in   =  IO_sda_slave ;

//**********************************************************************debug*****************************************************  
/*                      
//**********************************读操作*********************************
reg [7:0]  cnt ;
always@(posedge I_clk , negedge I_rst_n )
begin
    if(!I_rst_n)
       begin            
          I_send_en     <=  1'b0        ;
		  I_recv_en     <=  1'b1        ;
		  I_dev_addr    <=  7'b1010_010 ;
		  I_word_addr   <=  8'h23       ;
		  I_send_stop   <=  1'b0        ;
		  I_recv_stop   <=  1'b0        ;
		  I_write_data  <=  8'h00       ;
		  I_read_data	<=  8'h01       ;
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
*/

//**********************************写操作*********************************
reg [7:0] cnt  ;
always@(posedge I_clk , negedge I_rst_n )
begin
    if(!I_rst_n)
       begin
          I_send_en     <=  1'b1        ;
		  I_recv_en     <=  1'b0        ;
		  I_dev_addr    <=  7'b1010_000 ;
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


ila_iic_whole U_ila_iic_whole (
    .clk(I_clk), // input wire clk          
// master
	.probe0   ( I_rst_n           ), 
    .probe1   ( I_send_en         ),
    .probe2   ( I_recv_en         ), 
    .probe3   ( I_dev_addr        ), // [6:0]
	.probe4   ( I_word_addr       ), // [7:0]
	.probe5   ( I_write_data      ), // [7:0]
	.probe6   ( I_send_stop       ),
	.probe7   ( I_recv_stop       ),
	.probe8   ( O_send_done       ),
	.probe9   ( O_send_end        ),
	.probe10  ( O_recv_done       ),
	.probe11  ( O_recv_end        ),
	.probe12  ( O_recv_data       ), // [7:0]
    .probe13  ( IO_sda_master     ),   
    .probe14  ( O_sda_master_out  ),   
    .probe15  ( O_sda_master_oe   ),
	.probe16  ( O_scl             ),
// slalve      
	.probe17  ( I_read_data       ), //[7:0]	
    .probe18  ( O_dev_addr        ), //[6:0]
    .probe19  ( O_word_addr       ), //[7:0]
    .probe20  ( O_write_data      ), //[7:0]
	.probe21  ( O_get_end         ),
	.probe22  ( O_get_done        ),
	.probe23  ( O_read_end        ),
	.probe24  ( O_read_done       ),
	.probe25  ( O_sda_slave_out   ),
	.probe26  ( IO_sda_slave      ),
	.probe27  ( O_sda_slave_oe    ),
	.probe28  ( I_scl             ),
	.probe29  ( I_sda_master_in   ),
	.probe30  ( I_sda_slave_in    ),
	.probe31  ( I_pin0            ),
	.probe32  ( I_pin1            )	
); 


endmodule 