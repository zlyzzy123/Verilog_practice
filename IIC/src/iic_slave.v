`timescale 1ns / 1ps

module iic_slave(
    input                        I_clk          , // 50MHz系统时钟
    input                        I_rst_n        , // 系统复位
	input                        I_pin0         , // 从机7位地址的低两位
	input                        I_pin1         , // 从机7位地址的低两位
    input              [7:0]     I_read_data    , // 来自于存储地址的数据，或将要被主机读的数据
    output     reg     [6:0]     O_dev_addr     , // 从机接口将接收到的设备地址输出给从机
    output     reg     [7:0]     O_word_addr    , // 从机接口将接收到的存储地址输出给从机
    output     reg     [7:0]     O_write_data   , // 写入存储地址的数据，或从主机将要写入存储器的数据
    output     reg               O_get_end      , // 写存储器操作结束标志
    output     reg               O_get_done     , // 写存储器一个字节数据操作完成标志
    output     reg               O_read_end     , // 读存储器操作结束标志
	output     reg               O_read_done    , // 读存储器一个字节数据操作完成标志
	// 标准的IIC总线相关信号线
    input                        I_sda_in       , // SDA输入信号线
    output     reg               O_sda_out      , // SDA输出信号线
    output     reg               O_sda_oe       , // SDA模式，1为输出，0为输入
    input                        I_scl            // 来自于主机的SCL信号
);
parameter    fixed_addr =  5'b10100                       ;     // 设置的从机设备地址的高五位

parameter    C_DIV_SEL  =  10'd500                        ;     // 正好是100K bit/s
parameter    C_DIV_SEL0 =  (C_DIV_SEL>>2) -1              ;     // 用来产生IIC总线SCL高电平最中间的标志位
parameter    C_DIV_SEL1 =  (C_DIV_SEL>>1) -1              ;               
parameter    C_DIV_SEL2 =  (C_DIV_SEL0 + C_DIV_SEL1) +1   ;     // 用来产生IIC总线SCL低电平最中间的标志位

// 状态机状态定义
parameter    IDLE            =   4'd0   ;  // 空闲状态           
parameter    START_SIG       =   4'd1   ;  // 接收开始信号
parameter    GET_DEV_ADDR    =   4'd2   ;  // 读取设备地址
parameter    GET_WORD_ADDR   =   4'd3   ;  // 读取字（存储）地址
parameter    GET_DATA        =   4'd4   ;  // 写数据到存储器     
parameter 	 GET_BYTE        =   4'd5   ;  // 读取字节数据，比如设备物理地址，字地址和数据等 
parameter 	 SEND_ACK        =   4'd6   ;  // 发送响应ACK
parameter 	 STOP_SIG        =   4'd7   ;  // 接收停止信号
parameter    W_OR_R_DONE     =   4'd8   ;  // 写/读从机操作结束       
parameter 	 START_READ      =   4'd9   ;  // 进入读从机状态
parameter 	 SEND_BYTE       =   4'd10  ;  // 向主机发送字节数据
parameter 	 WAIT_CHECK_ACK  =   4'd11  ;  // 等待校验来自主机的ACK
parameter 	 R_GET_BYTE      =   4'd12  ;  // 多字节读从机操作中的再次读取字节数据
parameter    SEND_NOACK      =   4'd13  ;

reg    [3:0]    R_state            ;  // 状态机
reg    [3:0]    R_jump_state       ;  // 跳转状态
reg    [3:0]    R_bit_cnt          ;  // 处理字节数据位计数器
reg    [7:0]    R_receive_buff     ;  // 接收数据缓冲器
reg             R_w0_r1            ;  // 写0读1
reg    [1:0]    R_scl_state        ;  // SCL线状态
reg    [1:0]    R_sda_state        ;  // SDA线状态
reg    [9:0]    R_scl_cnt          ;  // SCL相关计数器

//reg O_sda_oe;
//reg O_sda_out;

//assign I_sda_in  = O_sda_oe ? O_sda_out: 1'bz;

wire       W_scl_low_mid       ;
wire       W_scl_high_mid      ;
wire       W_scl_neg           ;
wire       W_scl_pos           ;
wire       W_sda_neg           ;
wire       W_sda_pos           ;

always@(posedge I_clk , negedge I_rst_n)
begin
    if(!I_rst_n)
        begin
            R_scl_state <= 2'b00                   ;
            R_sda_state <= 2'b00                   ;
        end                            
    else
        begin
            R_scl_state <= {R_scl_state[0],I_scl }     ;
            R_sda_state <= {R_sda_state[0],I_sda_in}   ;
        end
end   

// 对来自于主机的SCL进行判断
assign    W_scl_high_mid   =   (R_scl_cnt == C_DIV_SEL0 ) ? 1:0     ;
assign    W_scl_low_mid    =   (R_scl_cnt == C_DIV_SEL2 ) ? 1:0     ;
assign    W_scl_neg        =   (R_scl_state == 2'b10) ? 1:0         ;
assign    W_scl_pos        =   (R_scl_state == 2'b01) ? 1:0         ;
assign    W_sda_pos        =   (R_sda_state == 2'b01) ? 1:0         ;
assign    W_sda_neg        =   (R_sda_state == 2'b10) ? 1:0         ;


always@(posedge I_clk , negedge I_rst_n)
begin
    if(!I_rst_n)
        R_scl_cnt <= 10'd0                     ;
    else if(W_scl_pos)//上升沿            
        R_scl_cnt <= 10'd0                     ;
    else if(R_scl_cnt == C_DIV_SEL - 1)     
        R_scl_cnt <= 10'd0                     ;
    else                                
        R_scl_cnt <= R_scl_cnt + 1'b1          ;
end 
    

always @(posedge I_clk ,negedge I_rst_n)
begin
    if(!I_rst_n)
        begin    
            O_sda_oe        <=   1'b0            ;//默认输入
            O_sda_out       <=   1'b0            ;//默认为0
            O_dev_addr      <=   7'd0            ;
            O_word_addr     <=   8'h00           ;
            O_write_data    <=   8'h00           ;
            O_get_end       <=   1'b0            ;
            O_read_end      <=   1'b0            ;
			O_get_done      <=   1'b0            ;
            O_read_done     <=   1'b0            ;
            R_state         <=   IDLE            ;
            R_jump_state    <=   GET_DEV_ADDR    ;
            R_bit_cnt       <=   4'd0            ;
            R_receive_buff  <=   8'h00           ; 
            R_w0_r1         <=   1'b0            ;   
        end
    else 
        case(R_state)
        IDLE:
            begin                    
                O_sda_oe        <=   1'b0               ; // 空闲态为输入
                O_sda_out       <=   1'b0               ;
                R_state         <=   START_SIG          ; // 下一状态：接收起始信号  
                R_jump_state    <=   GET_DEV_ADDR       ; // 跳转状态：读取设备地址
                R_bit_cnt       <=   4'd0               ;  
                O_get_end       <=   1'b0               ; // 其他保持  
                O_read_end      <=   1'b0               ;
				O_get_done      <=   1'b0               ;
                O_read_done     <=   1'b0               ;
                R_w0_r1         <=   1'b0               ; // 写状态
            end
        START_SIG:
            begin  
                O_sda_oe        <=    1'b0            ; // 设置为输入
                O_sda_out       <=    1'b0            ; 
                if(I_scl && W_sda_neg)                  // 接收到来自于主机的起始信号           
                    R_state    <=  GET_BYTE           ; // 下一状态：读取字节数据
                else                                 
                    R_state    <=  START_SIG          ;                      
            end                                      
        GET_DEV_ADDR:
            begin
                if(R_receive_buff[7:3]==fixed_addr && R_receive_buff[2:1]=={I_pin1,I_pin0})
				    begin     
						 R_state <= SEND_ACK                  ; // 下一状态为发送ACK
						  if(!R_receive_buff[0])  //写从机操作,或读从机操作的第一次设备地址写入
						      R_jump_state   <=  GET_WORD_ADDR      ; // 跳转状态为读取字节地址
						  else    //为1：开始读从机操作
						      R_jump_state   <=  SEND_BYTE          ; // 跳转状态为发送字节数据
					end			  
				else      R_state <= SEND_NOACK                      ; // 不是自己的设备地址，进入空闲状态
                {O_dev_addr,R_w0_r1}  <=  R_receive_buff  ; // 获取设备地址及读/写操作指令1/0
            end
        GET_WORD_ADDR:
            begin
                R_state         <=  SEND_ACK        ;
                O_word_addr     <=  R_receive_buff  ;
                R_jump_state    <=  GET_DATA        ;     
            end 
        GET_DATA:
            begin
                R_state         <=  SEND_ACK        ;
                O_write_data    <=  R_receive_buff  ; // 写进存储器
				O_get_done      <=  1'b1            ;
                R_jump_state    <=  STOP_SIG        ;     
            end  
        GET_BYTE:
            begin
                O_sda_oe        <= 1'b0     ; // 设置为输入
                O_sda_out       <= 1'b0     ;
                if(I_scl && W_sda_neg)  //检测是否有第二次开始信号，有的话就是读操作
                    begin
                        R_state            <=     START_READ     ;  // 开始读从机  
                        R_bit_cnt          <=     4'd0           ;
                        R_receive_buff[0]  <=     1'b0           ;
                    end
                else if( W_scl_neg && R_bit_cnt == 8)  //需要在SCL低电平中间进入发送ACK，因此在这里SCL下降沿要提前准备进入ACK
                    begin                   
                        R_bit_cnt          <=   4'd0              ;
                        R_state            <=   R_jump_state      ; // 注意 
                    end
                else if( W_scl_high_mid && I_scl) //在一次写结束后到下一次写开始的scl的周期会大于500，导致一个周期多次采样，因此要加上&& I_scl
                    begin                                                       
                        R_bit_cnt          <=    R_bit_cnt + 1'b1                  ;
                        R_state            <=    GET_BYTE                          ;
                        R_receive_buff     <=    {R_receive_buff[6:0],I_sda_in}    ;
                    end                    
                else
                    R_state <= GET_BYTE  ;
            end  
        SEND_ACK:
            begin     
                O_sda_oe      <=  1'b1      ; // 设置为输出
				O_get_done    <=  1'b0      ;
                if(W_scl_low_mid)
                    begin
					    O_sda_oe    <=  1'b1      ; // 设置为输出
                        O_sda_out   <=  1'b0      ; // 1、发送ACK，等SCL高电平中点读取
                    end
                else if( W_scl_neg )  // 2、等scl高电平过去
                    begin
                        if(R_jump_state == STOP_SIG)  //最后接收完数据
                            R_state <=  STOP_SIG               ;
                        else if(R_jump_state == SEND_BYTE )
                            R_state <=  SEND_BYTE              ;  
                        else 
                            R_state <= GET_BYTE                ; 
                    end
                else
                        R_state     <= SEND_ACK                ;
            end  
        SEND_NOACK:
            begin     
                O_sda_oe      <=  1'b1      ; // 设置为输出
				O_get_done    <=  1'b0      ;
                if(W_scl_low_mid)
                    begin
					    O_sda_oe    <=  1'b1      ; // 设置为输出
                        O_sda_out   <=  1'b1      ; // 1、发送NOACK，等SCL高电平中点读取
                    end
                else if( W_scl_neg )  // 2、等scl高电平过去
                    begin                        
                            R_state <= IDLE                    ; 
                    end
                else
                        R_state     <= SEND_NOACK                ;
            end  			
        START_READ:
            begin                                  
                O_sda_oe       <= 1'b0              ; // 设置SDA为输入
                O_sda_out      <= 1'b0              ;
                R_jump_state   <= GET_DEV_ADDR      ; //下一状态是GET_DEV_ADDR
                if(W_scl_neg) // 等待SCL高电平结束
                    R_state    <= GET_BYTE          ;
                else                                
                    R_state    <= START_READ        ;
            end                                     
        SEND_BYTE:
            begin
                O_sda_oe  <= 1'b1    ; // 设置SDA为输出
                if(W_scl_low_mid)
                    if(R_bit_cnt == 8)
                        begin                                 
                            R_bit_cnt     <=  4'd0                ;
                            R_state       <=  WAIT_CHECK_ACK      ;
                            O_sda_out     <=  O_sda_out           ;
                            O_read_done   <=  1'b1                ;
                        end
                    else
                        begin
                            R_state     <=  SEND_BYTE                   ;
                            O_sda_out   <=  I_read_data[7-R_bit_cnt]    ;
                            R_bit_cnt   <=  R_bit_cnt + 1'b1            ;
                        end                                             
                else
                    R_state <= SEND_BYTE      ;//其他信号保持
            end
        WAIT_CHECK_ACK:
            begin
                O_read_done     <=    1'b0              ;			
                O_sda_oe        <=    1'b0              ; // 设置SDA为输入
                O_sda_out       <=    1'b0              ;
                if(W_scl_high_mid && I_scl)             
                    if(I_sda_in)    // SDA上为1：NOACK  
                        R_state <= STOP_SIG             ;
                    else          // SDA上为0：ACK                              
                        R_state <= SEND_BYTE            ; // 进入多字节状态
                else                                    
                    R_state <= WAIT_CHECK_ACK           ;  
            end
        STOP_SIG:
            begin
                O_sda_oe     <= 1'b0  ;  // 设置为输入
                O_sda_out    <= 1'b0  ; 
                if( (!R_w0_r1) && (R_scl_cnt < C_DIV_SEL0+60) && I_scl )
				   begin
				      if(I_scl && W_sda_pos ) // 来自于主机的停止信号发生
                          begin               
                              R_state     <=  W_OR_R_DONE   ;
                          end                 
                      else                    
                          begin               
                              R_state     <=  STOP_SIG      ;
                          end           
                   end 
			    else if( (!R_w0_r1) && (R_scl_cnt == C_DIV_SEL0+60)&& I_scl)
			       begin
				      R_bit_cnt          <=    1'b1                              ;
				      R_receive_buff     <=    {R_receive_buff[6:0],I_sda_in}    ;
					  R_state            <=    R_GET_BYTE                        ;
					  R_jump_state       <=    GET_DATA                          ;
				   end
				else if(R_w0_r1  && W_sda_pos && I_scl)
				   begin				    
                       R_state   <=  W_OR_R_DONE     ;        
                   end 								
				else  
				   begin
				      R_state   <=  STOP_SIG      ;
				   end
			end	   
		R_GET_BYTE:
            begin
                O_sda_oe        <= 1'b0     ; // 设置为输入
                O_sda_out       <= 1'b0     ;               
                if( W_scl_neg && R_bit_cnt == 8)  //需要在SCL低电平中间进入发送ACK，因此在这里SCL下降沿要提前准备进入ACK
                    begin                   
                        R_bit_cnt          <=   4'd0              ;
                        R_state            <=   R_jump_state      ; // 注意 
                    end
                else if( W_scl_high_mid && I_scl) //在一次写结束后到下一次写开始的scl的周期会大于500，导致一个周期多次采样，因此要加上&& I_scl
                    begin
                        R_bit_cnt          <=    R_bit_cnt + 1'b1                  ;
                        R_state            <=    R_GET_BYTE                        ;
                        R_receive_buff     <=    {R_receive_buff[6:0],I_sda_in}    ;
                    end                    
                else
                    R_state <= R_GET_BYTE  ;
            end  	
        W_OR_R_DONE:   
            begin                       
                O_sda_oe                 <=   1'b0             ; // SDA空闲状态为输入
                O_sda_out                <=   1'b0             ; // 默认为0
                R_state                  <=   IDLE             ; // 进入空闲状态
                R_jump_state             <=   GET_DEV_ADDR     ; // 跳转状态为：获取设备地址
                R_bit_cnt                <=   4'd0             ;
                O_dev_addr               <=   7'd0             ;
                O_word_addr              <=   8'h00            ;
                O_write_data             <=   8'h00            ;
                R_receive_buff           <=   8'h00            ;
				R_w0_r1                  <=   1'b0             ;
                if(R_w0_r1) 
				   begin
				      O_read_end   <=   1'b1             ;
				      O_get_end    <=   1'b0             ;
				   end 
                else        
				   begin 
				       O_get_end    <=   1'b1             ;
				       O_read_end   <=   1'b0             ;
                   end 
            end  
        default: 
            begin                   
                O_sda_oe          <=   1'b0             ; // 默认输入
                O_sda_out         <=   1'b0             ; // 默认为0
                O_dev_addr        <=   7'd0             ;
                O_word_addr       <=   8'h00            ;
                O_write_data      <=   8'h00            ;
                O_get_end         <=   1'b0             ;
				O_read_end        <=   1'b0             ;
                R_state           <=   IDLE             ;
                R_jump_state      <=   GET_DEV_ADDR     ;
                R_bit_cnt         <=   4'd0             ;
                R_receive_buff    <=   8'h00            ;  
                R_w0_r1           <=   1'b0             ; 
            end  
        endcase
end 
       
   
endmodule
