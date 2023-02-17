`timescale 1ns / 1ps

module iic_master(
    input                  I_clk                        ,  // ϵͳʱ��
    input                  I_rst_n                      ,  // ϵͳ��λ
    input                  I_send_en                    ,  // IIC����ʹ��
    input                  I_recv_en                    ,  // IIC����ʹ��
    input          [6:0]   I_dev_addr                   ,  // IIC�豸�������ַ
    input          [7:0]   I_word_addr                  ,  // IIC�豸���ֵ�ַ����������IIC�豸���ڲ���ַ
    input          [7:0]   I_write_data                 ,  // ��IIC�豸���ֵ�ַд�������
	input                  I_send_stop                  ,  // ���Ͳ��������ź�
	input                  I_recv_stop                  ,  // ���ղ��������ź�
    output   reg           O_send_done                  ,  // дIIC�豸�ֽڣ�������ɱ�־λ
    output   reg           O_send_end                   ,  // дIIC�豸��������ɱ�־λ
    output   reg           O_recv_done                  ,  // ��IIC�豸�ֽڣ�������ɱ�־λ
    output   reg           O_recv_end                   ,  // ��IIC�豸��������ɱ�־λ
    output   reg   [7:0]   O_recv_data                  ,  // ��IIC�豸���ֵ�ַ����������
	// ��׼��IIC��������ź���
	input                  I_sda_in                     ,  // SDA�����ź���
    output   reg           O_sda_out                    ,  // SDA����ź���
    output   reg           O_sda_oe                     ,  // ����SDA������ģʽ��1Ϊ�����0Ϊ����	
    output                 O_scl                           // IIC���ߵĴ���ʱ����SCL          
);
	
	
parameter    C_DIV_SEL  =  10'd500                      ;  // ��Ƶϵ��ѡ��
parameter    C_DIV_SEL0 = (C_DIV_SEL>>2) -1             ;  // ��������IIC����SCL�ߵ�ƽ���м�ı�־λ
parameter    C_DIV_SEL1 = (C_DIV_SEL>>1) -1             ;  // ��������SCL�ߵ͵�ƽ             
parameter    C_DIV_SEL2 = (C_DIV_SEL0 + C_DIV_SEL1) +1  ;  // ��������IIC����SCL�͵�ƽ���м�ı�־λ
parameter    C_DIV_SEL3 = (C_DIV_SEL>>1) +1             ;  // ��������IIC����SCL�½��ر�־λ


parameter    IDLE               =    4'd0                ;  // ����״̬    
parameter    LOAD_DEV_ADDR      =    4'd1                ;  // ����IIC�豸��ַ
parameter    LOAD_WORD_ADDR     =    4'd2                ;  // ����IIC�豸�֣��洢����ַ
parameter    LOAD_DATA          =    4'd3                ;  // ����Ҫ���͵�����
parameter    START_SIG          =    4'd4                ;  // ������ʼ�ź�
parameter	 SEND_BYTE          =    4'd5                ;  // �����ֽ�����
parameter	 WAIT_ACK           =    4'd6                ;  // ����Ӧ��״̬��Ӧ��λ        
parameter	 CHECK_ACK          =    4'd7                ;  // У��Ӧ��λ
parameter    STOP_SIG           =    4'd8                ;  // ����ֹͣ�ź�
parameter	 W_OR_R_DONE        =    4'd9                ;  // д/��������ɱ�־     
parameter	 SEND_ACK_OR_NOACK  =    4'd10               ;  // ����Ӧ��״̬�ķ�Ӧ��λ      
parameter    LOAD_DEV_ADDR_R    =    4'd11               ;  // �������еڶ��μ���IIC�豸�����ַ
parameter    GET_BYTE           =    4'd12               ;  // �������н���һ���ֽ�����
parameter	 RDY_FOR_STOP       =    4'd13               ;  // ׼��ֹͣ
parameter    SEND_ADDR          =    4'd14               ;  // ���͵�ַ��Ϣ
            
reg          [9:0]       R_scl_cnt                      ;  // ��������SCL�ļ�����
reg                      R_scl_en                       ;  // SCLʹ���ź�
reg          [3:0]       R_state                        ;  // ״̬��
reg          [1:0]       R_scl_state                    ;  // SCL״̬�Ĵ���
reg          [7:0]       R_load_data                    ;  // ���ͻ���չ����м��ص����ݣ������豸�����ַ���ֵ�ַ�����ݵ�
reg          [3:0]       R_bit_cnt                      ;  // �����ֽ�״̬��bit��������
reg                      R_ack_flag                     ;  // Ӧ���־
reg          [3:0]       R_jump_state                   ;  // ��ת״̬������һ���ֽڳɹ���Ӧ���ͨ�����������ת��������һ�����ݵ�״̬
reg          [7:0]       R_read_data                    ;  // ��IIC�豸��ַ�ж�����������

wire                     W_scl_low_mid                  ;  // SCL�ĵ͵�ƽ�м��־λ
wire                     W_scl_high_mid                 ;  // SCL�ĸߵ�ƽ�м��־λ
wire                     W_scl_neg                      ;  // SCL�½��ر�־λ

//reg       O_sda_oe;
//reg       O_sda_out;

//assign I_sda_in = O_sda_oe ? O_sda_out: 1'bz;//inout
                                                           
assign  O_scl           =  (R_scl_cnt <= C_DIV_SEL1) ? 1'b1 : 1'b0        ;  // ��������ʱ�����ź�SCL
assign  W_scl_high_mid  =  (R_scl_cnt == C_DIV_SEL0) ? 1'b1 : 1'b0        ;  // SCL�ߵ�ƽ�м��־λ
assign  W_scl_low_mid   =  (R_scl_cnt == C_DIV_SEL2) ? 1'b1 : 1'b0        ;  // SCL�͵�ƽ�м��־λ                                                               
assign  W_scl_neg       =  (R_scl_cnt == C_DIV_SEL3) ? 1'b1 : 1'b0        ; // ����scl�½��ر�־λ
                                                        
                                                    
always@(posedge I_clk , negedge I_rst_n ) //��Ƶ������
begin
    if(!I_rst_n)
        R_scl_cnt    <=   10'd0                          ;
    else if(R_scl_en) //SCLʹ�ܴ�
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
            O_sda_oe          <=      1'b1                 ;  // SDAΪ���
            O_sda_out         <=      1'b1                 ;  // SDA���1
            R_scl_en          <=      1'b0                 ;  // SCLʹ�ܹ�
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
            IDLE:   // ׼��״̬������SCL��SDA��Ϊ�ߵ�ƽ
                begin                                            
                    R_state         <=    LOAD_DEV_ADDR          ;  // ��һ״̬�Ǽ����豸�����ַ      
                    O_sda_oe        <=    1'b1                   ;  // ����SDAΪ���  
                    O_sda_out       <=    1'b1                   ;  // ����SDAΪ�ߵ�ƽ
                    R_scl_en        <=    1'b0                   ;  // �ر�SCLʱ����
                    R_load_data     <=    8'h00                  ;  
                    R_bit_cnt       <=    4'd0                   ;  // �����ֽ�״̬��bit������������
                    O_send_end      <=    1'b0                   ;  
					O_recv_end      <=    1'b0                   ;
					O_send_done     <=    1'b0                   ;
					O_recv_done     <=    1'b0                   ;
                    R_jump_state    <=    IDLE                  ;   
                    R_ack_flag      <=    1'b0                   ;     
                end
            LOAD_DEV_ADDR:   // ����IIC�豸�����ַ
                begin                                           
                    R_state         <=    START_SIG                 ; // ��һ״̬Ϊ������ʼ�ź�
                    R_load_data     <=    {I_dev_addr,1'b0}         ; // ��һ��д���߶���������0
                    R_jump_state    <=    LOAD_WORD_ADDR            ; // ��ת״̬Ϊ�����ֵ�ַ 
                end                                             
            LOAD_WORD_ADDR:  // ����IIC�豸�ֵ�ַ               
                begin                                           
                    R_state         <=    SEND_ADDR                 ; // ��һ״̬Ϊ����һ���ֽ�����
                    R_load_data     <=    I_word_addr               ;
                    if(I_send_en)                               
                        begin                                       
                            R_jump_state     <=   LOAD_DATA         ; // ��ת״̬Ϊ����Ҫ���͵�����
                        end                                         
                    else if(I_recv_en)                          
                        begin                                
                            R_jump_state     <=   LOAD_DEV_ADDR_R   ; // ��ת״̬Ϊ�ڶ��μ����豸�����ַ�����λΪ1
                        end   
                end
            LOAD_DEV_ADDR_R:  // �������еڶ��μ���IIC�豸�����ַ
                begin                                           
                    R_state         <=    START_SIG                 ;  // ��һ״̬Ϊ���ڶ��Σ�������ʼ�ź�
                    R_load_data     <=    {I_dev_addr,1'b1}         ;  // �������ڶ��μ����豸�����ַ���λ��1
                    R_jump_state    <=    GET_BYTE                  ;  // ��ת״̬Ϊ����һ���ֽ�����
                end                                             
            LOAD_DATA:  // ����Ҫ���͵�����                     
                begin                                           
                    R_state         <=    SEND_BYTE                 ;  // ��һ״̬Ϊ����һ���ֽ�����					
                    R_load_data     <=    I_write_data              ;
				    R_jump_state    <=    LOAD_DATA                 ;
                end 
            START_SIG:  // ������ʼ�ź�
                begin
                    R_scl_en        <=   1'b1                       ;  // ����SCL
                    O_sda_oe        <=   1'b1                       ;  // ��SDA����Ϊ���
                    if(W_scl_high_mid)
                        begin
                            R_state     <=   SEND_ADDR              ;  // ��һ״̬Ϊ����һ���ֽ�����
                            O_sda_out   <=   1'b0                   ;
                        end
                    else
                        begin
                            R_state     <=   START_SIG              ;  // �����ȴ�SCL�ߵ�ƽ�м��־λ��Ч
                            O_sda_out   <=   O_sda_out              ;
                        end
                end
            SEND_ADDR:
                begin
                    R_scl_en       <=    1'b1                          ;
                    O_sda_oe       <=    1'b1                          ;  // SDAģʽ����Ϊ���
                    if(W_scl_low_mid)
                        if(R_bit_cnt == 8'd8)  // һ���ֽ����ݷ������
                            begin
                                R_bit_cnt      <=   8'd0                ;
                                R_state        <=   WAIT_ACK            ;  // ��һ״̬Ϊ����Ӧ��λ								
								O_send_done    <=   1'b0                ;
                            end              
                        else                 
                            begin            
                                R_state        <=   SEND_ADDR                ;  // ��һ״̬��ȻΪ����һ���ֽ����ݣ���������һλ����
                                O_sda_out      <=   R_load_data[7-R_bit_cnt] ;  // �Ӹ�λ����λ��λ����
                                R_bit_cnt      <=   R_bit_cnt + 1            ;	
                                O_send_done    <=   1'b0                     ;								
                            end
                    else
                        R_state   <=   SEND_ADDR                   ;  // �����ȴ�SCL�͵�ƽ�м��־λ��Ч
                end       			   
            SEND_BYTE:  // ����һ���ֽ�����,�Ӹ�λ����λ���з�
                begin
                    R_scl_en       <=    1'b1                          ;
                    O_sda_oe       <=    1'b1                          ;  // SDAģʽ����Ϊ���
                    if(W_scl_low_mid)
                        if(R_bit_cnt == 8'd8)  // һ���ֽ����ݷ������
                            begin
                                R_bit_cnt      <=   8'd0                ;
                                R_state        <=   WAIT_ACK            ;  // ��һ״̬Ϊ����Ӧ��λ								
								O_send_done    <=   1'b1                ;
                            end              
                        else                 
                            begin            
                                R_state        <=   SEND_BYTE                ;  // ��һ״̬��ȻΪ����һ���ֽ����ݣ���������һλ����
                                O_sda_out      <=   R_load_data[7-R_bit_cnt] ;  // �Ӹ�λ����λ��λ����
                                R_bit_cnt      <=   R_bit_cnt + 1            ;	
                                O_send_done    <=   1'b0                     ;								
                            end
                    else
                        R_state   <=   SEND_BYTE                   ;  // �����ȴ�SCL�͵�ƽ�м��־λ��Ч
                end       
            WAIT_ACK:  // ����Ӧ��״̬��Ӧ��λ
                begin
				    O_send_done  <=   1'b0                  ;
					O_recv_done  <=   1'b0                  ;
                    R_scl_en     <=   1'b1                  ;
                    O_sda_oe     <=   1'b0                  ;  // SDAģʽ����Ϊ����
                    if(W_scl_high_mid)
                        begin
                            R_ack_flag   <=    I_sda_in            ;
                            R_state      <=    CHECK_ACK           ;  // ��һ״̬ΪУ��Ӧ��λ
                        end
                    else
                        begin                                    
                            R_ack_flag   <=    R_ack_flag          ;
                            R_state      <=    WAIT_ACK            ;  // �����ȴ�SCL�ߵ�ƽ�м��־λ��Ч
                        end
                end       
            CHECK_ACK:  // У��Ӧ��λ
                begin
                    R_scl_en    <=    1'b1                         ;
                    if(!R_ack_flag)  // ACK��Ч
                        begin 
						    if(W_scl_neg)
                                begin                                    
                                    if(I_send_stop)
					                    begin   
										   R_state    <=    STOP_SIG           ;  // ��ת״̬Ϊ����ֹͣ�ź�
									    end 
					                else  
									    begin
										   R_state    <=    R_jump_state       ;  // ��һ״̬Ϊ��ת״̬	
										end    
                                    O_sda_oe      <=    1'b1                   ;  // ����SDAΪ���ģʽ
                                    if(I_send_en)       O_sda_out   <=  1'b0   ;  // ��ȡ��Ӧ���ź��Ժ�Ҫ��SDA�ź����ó���������ͣ���Ϊ������״̬
                                                                                  // ������ֹͣ״̬�Ļ�����ҪSDA�źŵ������أ�����������Ҫ��ǰ������
									else if(I_recv_en)  O_sda_out   <=  1'b1   ;  // ��SDA�ź����ó���������߷�������ڶ�����ʼ�ź�
                                    else                O_sda_out   <=  1'b0   ;
                                end                                      
                            else   R_state   <=   CHECK_ACK                 ;  // �����ȴ�SCL�½��س���  
						end 	                                         
                    else     R_state   <=   IDLE                            ;  // ����                      
                end		
            GET_BYTE:  // ����һ���ֽ����ݣ���λ����
                begin                 
                    R_scl_en      <=    1'b1          ;
                    O_sda_oe      <=    1'b0          ;  // SDAģʽ����Ϊ����
                    O_sda_out     <=    1'b0          ;               
                    if( W_scl_neg && R_bit_cnt == 8)  //��Ҫ�ڵ͵�ƽ�м����ACK
                        begin                                    
                            R_bit_cnt       <=     4'd0                   ;                            
                            O_recv_data     <=     R_read_data            ;
                            O_recv_done     <=     1'b1                   ;  // �����ֽ����ݽ�����ɱ�־
						    R_state         <=     SEND_ACK_OR_NOACK      ;  // ��һ״̬Ϊ����Ӧ��λ���Ӧ��λ 
                        end                                               
                    else if( W_scl_high_mid && O_scl)  //��һ�ζ���������һ�ζ���ʼ��scl�����ڻ����500������һ�����ڶ�β��������Ҫ����&& O_scl
                        begin
                            R_bit_cnt       <=     R_bit_cnt + 1               ;
                            R_state         <=     GET_BYTE                    ;  // ��һ״̬��ȻΪ����һ���ֽ������ݣ�������λ����
                            R_read_data     <=     {R_read_data[6:0],I_sda_in} ;  // �Ӹ�λ����λ����
                            O_recv_done     <=     1'b0                        ;
                        end                        
                    else    R_state   <=     GET_BYTE       ;	             	    	 
                end
            SEND_ACK_OR_NOACK:  // ����Ӧ��״̬��Ӧ��λ   
                begin                      
                    R_scl_en      <=     1'b1                     ;
                    O_sda_oe      <=     1'b1                     ;  // SDAģʽ����Ϊ���
					O_recv_done   <=     1'b0                     ;
                    if(W_scl_low_mid && !I_recv_stop)                               
                        begin                                                               
                            O_sda_out     <=   1'b0               ;  // ע�� ack Ϊ0							  
                        end                                     
                    else if(W_scl_neg && !I_recv_stop)
					     begin
						    R_state       <=   GET_BYTE           ;  // ׼���ٴν�������
						 end
					else if(W_scl_low_mid && I_recv_stop)
                        begin                                   
                            R_state     <=   RDY_FOR_STOP         ;  // ׼������ֹͣ�ź�
                            O_sda_out   <=   1'b1                 ;  // ע�� noack Ϊ1
                        end                                     					
					else                                        
                        begin                                   
                            R_state    <=   SEND_ACK_OR_NOACK     ;  // ��scl_low_mid֮ǰ���ɵȴ�I_recv_stop�źŵ�����
                        end                                         
                end              								                                     
            RDY_FOR_STOP:  // ׼��ֹͣ                                           
                begin                                             
                    R_scl_en     <=   1'b1                        ;
                    O_sda_oe     <=   1'b1                        ;  
                    if(W_scl_neg)                              
                        begin                                
                            R_state      <=   STOP_SIG            ;  // ��һ״̬Ϊ����ֹͣ�ź�
                            O_sda_out    <=   1'b0                ;  // ������ֹͣ״̬����ҪSDA�źŵ������أ�����������ǰ������
                        end                                 
                    else                                     
                        begin                                
                            R_state    <=     RDY_FOR_STOP        ;  
                        end                                  
                end                                          
            STOP_SIG:  // ����ֹͣ�ź�                       
                begin                                        
                    R_scl_en        <=    1'b1                    ;
                    O_sda_oe        <=    1'b1                    ;
                    if(W_scl_high_mid)                            
                        begin                                
                            R_state    <=    W_OR_R_DONE          ;  // ��һ״̬Ϊ����д������ɱ�־
                            O_sda_out  <=    1'b1                 ;  // �ͷ�SDA������ֹͣ�ź�     
                        end                                  
                    else                                       
                        R_state    <=   STOP_SIG                  ;  // �����ȴ�SCL�ߵ�ƽ�м��־λ��Ч
                end                                         
            W_OR_R_DONE:  // ����д/��������ɱ�־              
                begin
                    R_scl_en		  <=       1'b0            ;   	
                    R_state           <=       IDLE            ;
                    R_scl_en          <=       1'b0            ;   
                    O_sda_oe          <=       1'b1            ;   
                    O_sda_out         <=       1'b1            ;    
                    R_load_data       <=       8'h00           ;   
                    R_bit_cnt         <=       4'd0            ;                        
                    R_jump_state      <=       IDLE            ;  // ��ת״̬ΪIDLE
                    R_ack_flag        <=       1'b0            ;   
					if(I_send_en)   
					    begin
						  O_send_end   <=      1'b1          ;  // ����������ɱ�־ 
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
