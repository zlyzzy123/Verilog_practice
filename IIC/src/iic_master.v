`timescale 1ns / 1ps

module iic_master(
    input                  I_clk                        ,  // 系统时钟
    input                  I_rst_n                      ,  // 系统复位
    input                  I_send_en                    ,  // IIC发送使能
    input                  I_recv_en                    ,  // IIC接收使能
    input          [6:0]   I_dev_addr                   ,  // IIC设备的物理地址
    input          [7:0]   I_word_addr                  ,  // IIC设备的字地址，即操作的IIC设备的内部地址
    input          [7:0]   I_write_data                 ,  // 往IIC设备的字地址写入的数据
	input                  I_send_stop                  ,  // 发送操作结束信号
	input                  I_recv_stop                  ,  // 接收操作结束信号
    output   reg           O_send_done                  ,  // 写IIC设备字节，发送完成标志位
    output   reg           O_send_end                   ,  // 写IIC设备操作，完成标志位
    output   reg           O_recv_done                  ,  // 读IIC设备字节，接收完成标志位
    output   reg           O_recv_end                   ,  // 读IIC设备操作，完成标志位
    output   reg   [7:0]   O_recv_data                  ,  // 从IIC设备的字地址读出的数据
	// 标准的IIC总线相关信号线
	input                  I_sda_in                     ,  // SDA输入信号线
    output   reg           O_sda_out                    ,  // SDA输出信号线
    output   reg           O_sda_oe                     ,  // 设置SDA（方向）模式，1为输出，0为输入	
    output                 O_scl                           // IIC总线的串行时钟线SCL          
);
	
	
parameter    C_DIV_SEL  =  10'd500                      ;  // 分频系数选择
parameter    C_DIV_SEL0 = (C_DIV_SEL>>2) -1             ;  // 用来产生IIC总线SCL高电平最中间的标志位
parameter    C_DIV_SEL1 = (C_DIV_SEL>>1) -1             ;  // 用来产生SCL高低电平             
parameter    C_DIV_SEL2 = (C_DIV_SEL0 + C_DIV_SEL1) +1  ;  // 用来产生IIC总线SCL低电平最中间的标志位
parameter    C_DIV_SEL3 = (C_DIV_SEL>>1) +1             ;  // 用来产生IIC总线SCL下降沿标志位


parameter    IDLE               =    4'd0                ;  // 空闲状态    
parameter    LOAD_DEV_ADDR      =    4'd1                ;  // 加载IIC设备地址
parameter    LOAD_WORD_ADDR     =    4'd2                ;  // 加载IIC设备字（存储）地址
parameter    LOAD_DATA          =    4'd3                ;  // 加载要发送的数据
parameter    START_SIG          =    4'd4                ;  // 发送起始信号
parameter	 SEND_BYTE          =    4'd5                ;  // 发送字节数据
parameter	 WAIT_ACK           =    4'd6                ;  // 接收应答状态的应答位        
parameter	 CHECK_ACK          =    4'd7                ;  // 校验应答位
parameter    STOP_SIG           =    4'd8                ;  // 发送停止信号
parameter	 W_OR_R_DONE        =    4'd9                ;  // 写/读操作完成标志     
parameter	 SEND_ACK_OR_NOACK  =    4'd10               ;  // 发送应答状态的非应答位      
parameter    LOAD_DEV_ADDR_R    =    4'd11               ;  // 读操作中第二次加载IIC设备物理地址
parameter    GET_BYTE           =    4'd12               ;  // 读操作中接收一个字节数据
parameter	 RDY_FOR_STOP       =    4'd13               ;  // 准备停止
parameter    SEND_ADDR          =    4'd14               ;  // 发送地址信息
            
reg          [9:0]       R_scl_cnt                      ;  // 用来产生SCL的计数器
reg                      R_scl_en                       ;  // SCL使能信号
reg          [3:0]       R_state                        ;  // 状态机
reg          [1:0]       R_scl_state                    ;  // SCL状态寄存器
reg          [7:0]       R_load_data                    ;  // 发送或接收过程中加载的数据，比如设备物理地址，字地址和数据等
reg          [3:0]       R_bit_cnt                      ;  // 发送字节状态中bit个数计数
reg                      R_ack_flag                     ;  // 应答标志
reg          [3:0]       R_jump_state                   ;  // 跳转状态，传输一个字节成功并应答后通过这个变量跳转到导入下一个数据的状态
reg          [7:0]       R_read_data                    ;  // 从IIC设备地址中读出来的数据

wire                     W_scl_low_mid                  ;  // SCL的低电平中间标志位
wire                     W_scl_high_mid                 ;  // SCL的高电平中间标志位
wire                     W_scl_neg                      ;  // SCL下降沿标志位

//reg       O_sda_oe;
//reg       O_sda_out;

//assign I_sda_in = O_sda_oe ? O_sda_out: 1'bz;//inout
                                                           
assign  O_scl           =  (R_scl_cnt <= C_DIV_SEL1) ? 1'b1 : 1'b0        ;  // 产生串行时钟线信号SCL
assign  W_scl_high_mid  =  (R_scl_cnt == C_DIV_SEL0) ? 1'b1 : 1'b0        ;  // SCL高电平中间标志位
assign  W_scl_low_mid   =  (R_scl_cnt == C_DIV_SEL2) ? 1'b1 : 1'b0        ;  // SCL低电平中间标志位                                                               
assign  W_scl_neg       =  (R_scl_cnt == C_DIV_SEL3) ? 1'b1 : 1'b0        ; // 产生scl下降沿标志位
                                                        
                                                    
always@(posedge I_clk , negedge I_rst_n ) //分频计数器
begin
    if(!I_rst_n)
        R_scl_cnt    <=   10'd0                          ;
    else if(R_scl_en) //SCL使能打开
        if(R_scl_cnt == C_DIV_SEL-1)
            R_scl_cnt <=  10'd0                          ;
        else
            R_scl_cnt <=  R_scl_cnt + 1'b1               ;
    else
        R_scl_cnt   <=   10'd0                           ;
end 
  

always @(posedge I_clk ,negedge I_rst_n)
begin
    if(!I_rst_n)
        begin                                             
            R_state           <=      IDLE                ;
            O_sda_oe          <=      1'b1                 ;  // SDA为输出
            O_sda_out         <=      1'b1                 ;  // SDA输出1
            R_scl_en          <=      1'b0                 ;  // SCL使能关
            R_load_data       <=      8'h00                ;
            R_bit_cnt         <=      4'd0                 ;
            O_send_end        <=      1'b0                 ;
			O_recv_end        <=      1'b0                 ; 
			O_send_done       <=      1'b0                 ;
			O_recv_done       <=      1'b0                 ;
            R_jump_state      <=      IDLE                ;
            R_ack_flag        <=      1'b0                 ;  
            R_read_data       <=      8'h00                ;   
            O_recv_data       <=      8'h00                ;                    
        end                                               
    else if(I_send_en || I_recv_en)
        case(R_state)
            IDLE:   // 准备状态，设置SCL与SDA均为高电平
                begin                                            
                    R_state         <=    LOAD_DEV_ADDR          ;  // 下一状态是加载设备物理地址      
                    O_sda_oe        <=    1'b1                   ;  // 设置SDA为输出  
                    O_sda_out       <=    1'b1                   ;  // 设置SDA为高电平
                    R_scl_en        <=    1'b0                   ;  // 关闭SCL时钟线
                    R_load_data     <=    8'h00                  ;  
                    R_bit_cnt       <=    4'd0                   ;  // 发送字节状态中bit个数计数清零
                    O_send_end      <=    1'b0                   ;  
					O_recv_end      <=    1'b0                   ;
					O_send_done     <=    1'b0                   ;
					O_recv_done     <=    1'b0                   ;
                    R_jump_state    <=    IDLE                  ;   
                    R_ack_flag      <=    1'b0                   ;     
                end
            LOAD_DEV_ADDR:   // 加载IIC设备物理地址
                begin                                           
                    R_state         <=    START_SIG                 ; // 下一状态为发送起始信号
                    R_load_data     <=    {I_dev_addr,1'b0}         ; // 第一次写或者读操作都是0
                    R_jump_state    <=    LOAD_WORD_ADDR            ; // 跳转状态为加载字地址 
                end                                             
            LOAD_WORD_ADDR:  // 加载IIC设备字地址               
                begin                                           
                    R_state         <=    SEND_ADDR                 ; // 下一状态为发送一个字节数据
                    R_load_data     <=    I_word_addr               ;
                    if(I_send_en)                               
                        begin                                       
                            R_jump_state     <=   LOAD_DATA         ; // 跳转状态为加载要发送的数据
                        end                                         
                    else if(I_recv_en)                          
                        begin                                
                            R_jump_state     <=   LOAD_DEV_ADDR_R   ; // 跳转状态为第二次加载设备物理地址，最低位为1
                        end   
                end
            LOAD_DEV_ADDR_R:  // 读操作中第二次加载IIC设备物理地址
                begin                                           
                    R_state         <=    START_SIG                 ;  // 下一状态为（第二次）发送起始信号
                    R_load_data     <=    {I_dev_addr,1'b1}         ;  // 读操作第二次加载设备物理地址最低位是1
                    R_jump_state    <=    GET_BYTE                  ;  // 跳转状态为接收一个字节数据
                end                                             
            LOAD_DATA:  // 加载要发送的数据                     
                begin                                           
                    R_state         <=    SEND_BYTE                 ;  // 下一状态为发送一个字节数据					
                    R_load_data     <=    I_write_data              ;
				    R_jump_state    <=    LOAD_DATA                 ;
                end 
            START_SIG:  // 发送起始信号
                begin
                    R_scl_en        <=   1'b1                       ;  // 产生SCL
                    O_sda_oe        <=   1'b1                       ;  // 将SDA设置为输出
                    if(W_scl_high_mid)
                        begin
                            R_state     <=   SEND_ADDR              ;  // 下一状态为发送一个字节数据
                            O_sda_out   <=   1'b0                   ;
                        end
                    else
                        begin
                            R_state     <=   START_SIG              ;  // 继续等待SCL高电平中间标志位有效
                            O_sda_out   <=   O_sda_out              ;
                        end
                end
            SEND_ADDR:
                begin
                    R_scl_en       <=    1'b1                          ;
                    O_sda_oe       <=    1'b1                          ;  // SDA模式设置为输出
                    if(W_scl_low_mid)
                        if(R_bit_cnt == 8'd8)  // 一个字节数据发送完成
                            begin
                                R_bit_cnt      <=   8'd0                ;
                                R_state        <=   WAIT_ACK            ;  // 下一状态为接受应答位								
								O_send_done    <=   1'b0                ;
                            end              
                        else                 
                            begin            
                                R_state        <=   SEND_ADDR                ;  // 下一状态仍然为发送一个字节数据，继续发下一位数据
                                O_sda_out      <=   R_load_data[7-R_bit_cnt] ;  // 从高位到低位按位发送
                                R_bit_cnt      <=   R_bit_cnt + 1            ;	
                                O_send_done    <=   1'b0                     ;								
                            end
                    else
                        R_state   <=   SEND_ADDR                   ;  // 继续等待SCL低电平中间标志位有效
                end       			   
            SEND_BYTE:  // 发送一个字节数据,从高位到低位串行发
                begin
                    R_scl_en       <=    1'b1                          ;
                    O_sda_oe       <=    1'b1                          ;  // SDA模式设置为输出
                    if(W_scl_low_mid)
                        if(R_bit_cnt == 8'd8)  // 一个字节数据发送完成
                            begin
                                R_bit_cnt      <=   8'd0                ;
                                R_state        <=   WAIT_ACK            ;  // 下一状态为接受应答位								
								O_send_done    <=   1'b1                ;
                            end              
                        else                 
                            begin            
                                R_state        <=   SEND_BYTE                ;  // 下一状态仍然为发送一个字节数据，继续发下一位数据
                                O_sda_out      <=   R_load_data[7-R_bit_cnt] ;  // 从高位到低位按位发送
                                R_bit_cnt      <=   R_bit_cnt + 1            ;	
                                O_send_done    <=   1'b0                     ;								
                            end
                    else
                        R_state   <=   SEND_BYTE                   ;  // 继续等待SCL低电平中间标志位有效
                end       
            WAIT_ACK:  // 接收应答状态的应答位
                begin
				    O_send_done  <=   1'b0                  ;
					O_recv_done  <=   1'b0                  ;
                    R_scl_en     <=   1'b1                  ;
                    O_sda_oe     <=   1'b0                  ;  // SDA模式设置为输入
                    if(W_scl_high_mid)
                        begin
                            R_ack_flag   <=    I_sda_in            ;
                            R_state      <=    CHECK_ACK           ;  // 下一状态为校验应答位
                        end
                    else
                        begin                                    
                            R_ack_flag   <=    R_ack_flag          ;
                            R_state      <=    WAIT_ACK            ;  // 继续等待SCL高电平中间标志位有效
                        end
                end       
            CHECK_ACK:  // 校验应答位
                begin
                    R_scl_en    <=    1'b1                         ;
                    if(!R_ack_flag)  // ACK有效
                        begin 
						    if(W_scl_neg)
                                begin                                    
                                    if(I_send_stop)
					                    begin   
										   R_state    <=    STOP_SIG           ;  // 跳转状态为发送停止信号
									    end 
					                else  
									    begin
										   R_state    <=    R_jump_state       ;  // 下一状态为跳转状态	
										end    
                                    O_sda_oe      <=    1'b1                   ;  // 设置SDA为输出模式
                                    if(I_send_en)       O_sda_out   <=  1'b0   ;  // 读取完应答信号以后要把SDA信号设置成输出并拉低，因为如果这个状态
                                                                                  // 后面是停止状态的话，需要SDA信号的上升沿，所以这里需要提前拉低它
									else if(I_recv_en)  O_sda_out   <=  1'b1   ;  // 把SDA信号设置成输出并拉高方便产生第二次起始信号
                                    else                O_sda_out   <=  1'b0   ;
                                end                                      
                            else   R_state   <=   CHECK_ACK                 ;  // 继续等待SCL下降沿出现  
						end 	                                         
                    else     R_state   <=   IDLE                            ;  // 出错？                      
                end		
            GET_BYTE:  // 接收一个字节数据，按位接收
                begin                 
                    R_scl_en      <=    1'b1          ;
                    O_sda_oe      <=    1'b0          ;  // SDA模式设置为输入
                    O_sda_out     <=    1'b0          ;               
                    if( W_scl_neg && R_bit_cnt == 8)  //需要在低电平中间进行ACK
                        begin                                    
                            R_bit_cnt       <=     4'd0                   ;                            
                            O_recv_data     <=     R_read_data            ;
                            O_recv_done     <=     1'b1                   ;  // 产生字节数据接收完成标志
						    R_state         <=     SEND_ACK_OR_NOACK      ;  // 下一状态为发送应答位或非应答位 
                        end                                               
                    else if( W_scl_high_mid && O_scl)  //在一次读结束后到下一次读开始的scl的周期会大于500，导致一个周期多次采样，因此要加上&& O_scl
                        begin
                            R_bit_cnt       <=     R_bit_cnt + 1               ;
                            R_state         <=     GET_BYTE                    ;  // 下一状态仍然为接收一个字节数数据，继续按位接收
                            R_read_data     <=     {R_read_data[6:0],I_sda_in} ;  // 从高位到低位接收
                            O_recv_done     <=     1'b0                        ;
                        end                        
                    else    R_state   <=     GET_BYTE       ;	             	    	 
                end
            SEND_ACK_OR_NOACK:  // 发送应答状态的应答位   
                begin                      
                    R_scl_en      <=     1'b1                     ;
                    O_sda_oe      <=     1'b1                     ;  // SDA模式设置为输出
					O_recv_done   <=     1'b0                     ;
                    if(W_scl_low_mid && !I_recv_stop)                               
                        begin                                                               
                            O_sda_out     <=   1'b0               ;  // 注意 ack 为0							  
                        end                                     
                    else if(W_scl_neg && !I_recv_stop)
					     begin
						    R_state       <=   GET_BYTE           ;  // 准备再次接收数据
						 end
					else if(W_scl_low_mid && I_recv_stop)
                        begin                                   
                            R_state     <=   RDY_FOR_STOP         ;  // 准备产生停止信号
                            O_sda_out   <=   1'b1                 ;  // 注意 noack 为1
                        end                                     					
					else                                        
                        begin                                   
                            R_state    <=   SEND_ACK_OR_NOACK     ;  // 在scl_low_mid之前都可等待I_recv_stop信号的输入
                        end                                         
                end              								                                     
            RDY_FOR_STOP:  // 准备停止                                           
                begin                                             
                    R_scl_en     <=   1'b1                        ;
                    O_sda_oe     <=   1'b1                        ;  
                    if(W_scl_neg)                              
                        begin                                
                            R_state      <=   STOP_SIG            ;  // 下一状态为发送停止信号
                            O_sda_out    <=   1'b0                ;  // 后面是停止状态，需要SDA信号的上升沿，所以这里提前拉低它
                        end                                 
                    else                                     
                        begin                                
                            R_state    <=     RDY_FOR_STOP        ;  
                        end                                  
                end                                          
            STOP_SIG:  // 发送停止信号                       
                begin                                        
                    R_scl_en        <=    1'b1                    ;
                    O_sda_oe        <=    1'b1                    ;
                    if(W_scl_high_mid)                            
                        begin                                
                            R_state    <=    W_OR_R_DONE          ;  // 下一状态为产生写操作完成标志
                            O_sda_out  <=    1'b1                 ;  // 释放SDA，产生停止信号     
                        end                                  
                    else                                       
                        R_state    <=   STOP_SIG                  ;  // 继续等待SCL高电平中间标志位有效
                end                                         
            W_OR_R_DONE:  // 产生写/读操作完成标志              
                begin
                    R_scl_en		  <=       1'b0            ;   	
                    R_state           <=       IDLE            ;
                    R_scl_en          <=       1'b0            ;   
                    O_sda_oe          <=       1'b1            ;   
                    O_sda_out         <=       1'b1            ;    
                    R_load_data       <=       8'h00           ;   
                    R_bit_cnt         <=       4'd0            ;                        
                    R_jump_state      <=       IDLE            ;  // 跳转状态为IDLE
                    R_ack_flag        <=       1'b0            ;   
					if(I_send_en)   
					    begin
						  O_send_end   <=      1'b1          ;  // 产生发送完成标志 
						  O_recv_end   <=      1'b0          ; 
						end
                    if(I_recv_en)   
					    begin
					      O_recv_end   <=      1'b1          ;
                          O_send_end   <=      1'b0          ;						  
                          O_recv_data  <=      8'h00         ; 	
                        end						  
                end  
            default:  R_state    <=    IDLE                    ;
        endcase                                             
    else                                                    
        begin                                               
            R_state            <=        IDLE                  ;
            R_scl_en           <=        1'b0                  ;   
            O_sda_oe           <=        1'b1                  ;   
            O_sda_out          <=        1'b1                  ;    
            R_load_data        <=        8'h00                 ;   
            R_bit_cnt          <=        4'd0                  ;    
            O_send_end         <=        1'b0                  ;
			O_recv_end         <=        1'b0                  ; 
			O_send_done        <=        1'b0                  ;
			O_recv_done        <=        1'b0                  ;
            R_jump_state       <=        IDLE                  ; 
            R_ack_flag         <=        1'b0                  ;   
        end                                                 
end
    

endmodule
