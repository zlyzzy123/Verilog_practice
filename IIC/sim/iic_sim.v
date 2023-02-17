`timescale 1ns / 1ps

module iic_sim;
parameter CLK_PERIOD = 20; //��������20ns=50M
parameter RST_CYCLE = 10; //��λ������
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

reg           I_send_en           ;  // IIC����ʹ��
reg           I_recv_en           ;  // IIC����ʹ��
reg   [6:0]   I_dev_addr          ;  // IIC�豸�������ַ
reg   [7:0]   I_word_addr         ;  // IIC�豸���ֵ�ַ����������IIC�豸���ڲ���ַ
reg   [7:0]   I_write_data        ;  // ��IIC�豸���ֵ�ַд�������
reg           I_send_stop         ;  // ���Ͳ��������ź�
reg           I_recv_stop         ;  // ���ղ��������ź�
wire          O_send_done         ;  // дIIC�豸�ֽڣ�������ɱ�־λ
wire          O_send_end          ;  // дIIC�豸��������ɱ�־λ
wire          O_recv_done         ;  // ��IIC�豸�ֽڣ�������ɱ�־λ
wire          O_recv_end          ;  // ��IIC�豸��������ɱ�־λ
wire   [7:0]  O_recv_data         ;  // ��IIC�豸���ֵ�ַ����������
wire          O_sda_master_oe     ;  // ����SDA������ģʽ��1Ϊ�����0Ϊ����
wire          O_sda_master_out    ;  // SDA�Ĵ���������SDA���
wire          I_sda_master_in     ;  // IIC���ߵ�˫����������SDA
wire          IO_sda              ;
wire          O_scl               ;

wire          O_sda_slave_out     ; // SDA����Ĵ���       
                                
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
// ��׼��IIC��������ź���                          
    .I_sda_in            ( I_sda_master_in    ), 
    .O_sda_out           ( O_sda_master_out   ),
    .O_sda_oe            ( O_sda_master_oe    ), 
    .O_scl               ( O_scl              )	
);        

// master�ӿ���̬��            
assign IO_sda           = O_sda_master_oe ? O_sda_master_out: O_sda_slave_out ;//inout
assign I_sda_master_in  = IO_sda ;
  
//********************************************************************************
reg    [7:0]   I_read_data        ; // �����ڴ洢��ַ�����ݣ���Ҫ��������������
wire   [6:0]   O_dev_addr         ; // �ӻ��ӿڽ����յ����豸��ַ������ӻ�
wire   [7:0]   O_word_addr        ; // �ӻ��ӿڽ����յ��Ĵ洢��ַ������ӻ�
wire   [7:0]   O_write_data       ; // д��洢��ַ�����ݣ����������Ҫд��洢��������
wire           O_get_end          ; // д�洢������������־
wire           O_get_done         ; // д�洢��һ���ֽ����ݲ�����ɱ�־
wire           O_read_end         ; // ���洢������������־
wire           O_read_done        ; // ���洢��һ���ֽ����ݲ�����ɱ�־
wire           I_sda_slave_in     ; // SDAģʽ��1Ϊ�����0Ϊ����
//wire           O_sda_slave_out    ; // SDA����Ĵ���                                                  
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
	// ��׼��IIC��������ź���
    .I_sda_in          ( I_sda_slave_in     ),
    .O_sda_out         ( O_sda_slave_out    ),
    .O_sda_oe          ( O_sda_slave_oe     ),
    .I_scl             ( O_scl              )
);

// slave�ӿ���̬��         
//assign IO_sda           =  O_sda_slave_oe ? O_sda_slave_out: O_sda_master_out ;
assign I_sda_slave_in   =  IO_sda ;

//**********************************************************************debug*****************************************************
/*                       
//**********************************д��������*********************************
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
 
//**********************************����������*********************************
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

// д8���ֽ�

////////////////////////////////////////////////////////
/*
// д8���ֽ�
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
//��8���ֽ�
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
