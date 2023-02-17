//验证用
//四线SPI标准总线协议-----主从模式主从模式一对一

`timescale 1ns / 1ps

`define  ILA_SPI      0
`define  CLK_WIZ_SPI  1

module spi_whole
(  
    input               clk         ,// 全局时钟50MHz
    input               I_rst_n     ,// 复位信号，低电平有效
//    input               I_cpol      , // 时钟极性-----//传输模式选择
//    input               I_cpha      , // 时钟相位-----//传输模式选择
//    input               I_rx_en     , // 接收使能信号
//    input               I_tx_en     , // 发送使能信号
//    input      [7:0]    I_data_in   , // 要发送的数据
    output     [7:0]    O_data_out  , // 接收到的数据
    output              O_tx_done   , // 发送一个字节完毕标志位
    output              O_rx_done   , // 接收一个字节完毕标志位
                                    
    // 四线标准SPI信号定义         
    input               I_spi_miso  , // SPI串行输入，用来接收从机的数据
    output              O_spi_sck   , // SPI时钟
    output              O_spi_cs    , // SPI片选信号
    output              O_spi_mosi  , // SPI输出，用来给从机发送数据          
    output     [4:0]    state         // 模式状态    
 );

    
reg [4:0]   state                   ;

wire  I_clk                         ; //分频时钟10MHz	
wire  O_spi_sck_rx                  ; //接收中的SPI时钟
wire  O_spi_cs_rx                   ; //接收中的片选信号
wire  O_spi_sck_tx                  ; //发送中的SPI时钟
wire  O_spi_cs_tx                   ; //发送中的片选信号      
//wire  data_clk                      ;

parameter    idle  =  5'b00001      ; 
parameter    mode0 =  5'b00010      ;
parameter    mode1 =  5'b00100      ;
parameter    mode2 =  5'b01000      ;
parameter    mode3 =  5'b10000      ;
    

always @(*)
    if(!I_rst_n)
		state = idle;//复位状态
	else
	 begin
        if((!I_cpol)&&(!I_cpha))             state = mode0     ; //模式0     
	    else if((!I_cpol)&&(I_cpha))         state = mode1     ; //模式1
	    else if((I_cpol)&&(!I_cpha))         state = mode2     ; //模式2   
	    else if((I_cpol)&&(I_cpha))          state = mode3     ; //模式3  
		else                                 state = mode0     ; //模式0   
	 end

	
spi_rx U_spi_rx 
(
        .I_clk           (I_clk          ), 
        .I_rst_n         (I_rst_n        ), 
        .I_rx_en         (I_rx_en        ), 
        .I_tx_en         (I_tx_en        ), 
        .O_data_out      (O_data_out     ), 
        .O_rx_done       (O_rx_done      ), 
        .I_spi_miso      (I_spi_miso     ), 
        .O_spi_sck_rx    (O_spi_sck_rx   ), 
        .O_spi_cs_rx     (O_spi_cs_rx    ),
		.I_cpol          (I_cpol         ),
		.state           (state          )		
);	
	
spi_tx U_spi_tx 
(
        .I_clk           (I_clk          ), 
        .I_rst_n         (I_rst_n        ), 
        .I_rx_en         (I_rx_en        ), 
        .I_tx_en         (I_tx_en        ), 
        .I_data_in       (I_data_in      ), 
        .O_tx_done       (O_tx_done      ), 
        .O_spi_sck_tx    (O_spi_sck_tx   ), 
        .O_spi_cs_tx     (O_spi_cs_tx    ), 
        .O_spi_mosi      (O_spi_mosi     ),
		.I_cpol          (I_cpol         ),
	    .state           (state          )
);	
	
	
	assign O_spi_cs  = O_spi_cs_tx&O_spi_cs_rx     ;
	assign O_spi_sck = O_spi_sck_tx|O_spi_sck_rx   ;	
	
	
	
	
//****************************************debug************************************************	
            
reg         I_cpol       ;
reg         I_cpha       ;
reg         I_rx_en      ;
reg         I_tx_en      ;
reg  [7:0]  I_data_in    ;
wire        I_spi_miso   ;


/*
//***********************************************************************************
//发送的测试激励

    always @(posedge I_clk or negedge I_rst_n)
    begin
         if(!I_rst_n)
		    begin 
              I_data_in <=  8'h00   ;
		   	  I_cpol    <=  0       ;
		   	  I_cpha    <=  0       ;
		   	  I_rx_en   <=  0       ;
		   	  I_tx_en   <=  1       ;
		    end    
		 else if(I_data_in == 8'hff)                       
		    begin         
			  I_tx_en = 0 ;
			  I_rx_en = 0 ;
			end                 
         else if(O_tx_done)
            I_data_in <= I_data_in + 1'b1 ;  	 	    		
    end
//************************************************************************************
*/


//**********************************************************************************
//接收的测试激励

wire             ram_en      ;  //RAM使能    
wire             ram_wea     ;  //ram读写使能信号,高电平写入,低电平读出 
reg     [7:0]    ram_addr    ;  //ram读写地址 
reg     [7:0]    ram_wr_data ;  //ram写数据  
wire    [7:0]    ram_rd_data ;  //ram读数据

reg     [7:0]    rw_cnt      ;  //写RAM控制计数器(256byte)  


//ram ip核
blk_mem_gen_0  blk_mem_gen_0 (
	.clka  (I_clk        ),  // input wire clka
	.ena   (ram_en       ),  // input wire ena	
	.wea   (ram_wea      ),  // input wire [0 : 0] wea
	.addra (ram_addr     ),  // input wire [4 : 0] addra
	.dina  (ram_wr_data  )/*,  // input wire [7 : 0] dina
	.douta (ram_rd_data  )  // output wire [7 : 0] douta */
);

always @(posedge I_clk or negedge I_rst_n) 
begin
    if(!I_rst_n)
	    begin
            ram_wr_data <=  1'b0    ; 
			ram_addr    <=  1'b0    ; 
			rw_cnt	    <=  1'b0    ;
		  	I_cpol      <=  1'b0    ;
		   	I_cpha      <=  1'b0    ;
		   	I_rx_en     <=  1'b1    ;
   		    I_tx_en     <=  1'b0    ;
        end
	else if(rw_cnt==8'd255)  
        begin
            I_rx_en     <=  1'b0    ;
   		    I_tx_en     <=  1'b0    ; 
		end
    else if(O_rx_done)  //在计数器的0-255范围内，RAM写地址累加
	    begin
		  ram_wr_data <= O_data_out      ; 
          ram_addr    <= ram_addr + 1'b1 ; 	
          rw_cnt	  <= rw_cnt + 1'b1   ; 	         		  	  
        end 		  
end  

assign ram_en  = I_rst_n ; //1有效
assign ram_wea = 1'b1    ;

//*******************************************************************************

`ifdef ILA_SPI 
ila_spi U_ila_spi (
    .clk(clk), // input wire clk          

	.probe0  (I_rst_n     ), 
    .probe1  (I_tx_en     ),
    .probe2  (I_rx_en     ),
    .probe3  (I_data_in   ), // [7:0]
	.probe4  (O_data_out  ), // [7:0]
	.probe5  (O_tx_done   ),
	.probe6  (O_rx_done   ),
	.probe7  (I_spi_miso  ),
	.probe8  (O_spi_sck   ),
	.probe9  (O_spi_cs    ),
	.probe10 (O_spi_mosi  ),
	.probe11 (I_cpol      ),
	.probe12 (I_cpha      ),
	.probe13 (state       ),  // [4:0]
	.probe14 (I_clk       ),
	
	.probe15(ram_en),     // input wire [0:0]  probe0  
    .probe16(ram_wea),    // input wire [0:0]  probe1 
    .probe17(ram_addr),   // input wire [7:0]  probe2 
    .probe18(ram_wr_data)/*,// input wire [7:0]  probe3 
    .probe19(ram_rd_data) // input wire [7:0]  probe4 
*/
);
`endif


`ifdef CLK_WIZ_SPI
clk_wiz_spi U_clk_wiz_spi
(

    .clk_out1(I_clk     ),  
    .resetn  (I_rst_n   ), 
    .locked  (locked    ),       
    .clk_in1 (clk       )
 );     
`endif
 

	
endmodule 


