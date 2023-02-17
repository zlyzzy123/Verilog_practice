module i2c
#(
    parameter SLAVE_ADDR = 7'b1010_000,//EEPROM从机地址
    parameter CLK_FREQ = 26'd50_000_000,//模块输入的时钟频率
    parameter I2C_FREQ = 18'd250_000//IIC_SCL的时钟频率
)
(
    input clk,
    input rst_n,

    input i2c_exec,//I2C触发执行信号
    input bit_ctrl,//字地址位控制（16bit or 8bit）
    input i2c_rh_wl,//I2C读写控制信号
    input [15:0] i2c_addr,//I2C器件内地址
    input [7:0] i2c_data_w,//I2C写的数据
    output reg [7:0] i2c_data_r,//I2C读的数据
    output reg i2c_done,//I2C一次操作完成
    output reg i2c_ack,//I2C应答标志，0为应答，1为未应答
    output reg scl,//I2C的SCL时钟信号
    inout sda,//I2C的SDA信号
    output reg dri_clk//驱动I2C操作的四倍频驱动时钟
);

localparam st_idle = 8'b0000_0001;//空闲状态
localparam st_sladdr = 8'b0000_0010;//发送器件地址（slave address）
localparam st_addr16 = 8'b0000_0100;//发送16位字地址
localparam st_addr8 = 8'b0000_1000;//发送8位字地址
localparam st_data_wr = 8'b0001_0000;//写数据8bit
localparam st_addr_rd = 8'b0010_0000;//发送器件地址
localparam st_data_rd = 8'b0100_0000;//读数据8bit
localparam st_stop = 8'b1000_0000;//结束I2C操作

reg sda_dir;//I2C的SDA数据方向控制
reg sda_out;//SDA输出信号
reg st_done;//状态结束
reg wr_flag;//写标志
reg [9:0] clk_cnt;//分频时钟计数
reg [7:0] cur_state;//状态机当前状态
reg [7:0] next_state;//状态机下一状态
reg [7:0] data_r;//读取的数据
reg [7:0] data_wr_t;//I2C需要写入的数据的临时寄存
reg [15:0] addr_t;//I2C地址
reg [6:0] cnt;//计数

wire sda_in;//SDA输入信号
wire [8:0] clk_divide;//模块驱动时钟分频系数

assign sda = sda_dir ? sda_out : 1'bz;//SDA数据输出或高阻
assign sda_in = sda;//SDA数据输入
assign clk_divide = (CLK_FREQ/I2C_FREQ) >> 2'd2;//模块驱动时钟的分频系数

//产生SCL的四倍频时钟进行操作
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        dri_clk <= 1'b0;
        clk_cnt <= 10'd0;
    end
    else if(clk_cnt == clk_divide[8:1] - 1'd1)begin
        clk_cnt <= 10'd0;
        dri_clk <= ~dri_clk;
    end
    else
        clk_cnt <= clk_cnt + 1'b1;
end

//同步时序描述状态转移
always @(posedge dri_clk or negedge rst_n)begin
    if(!rst_n)
        cur_state <= st_idle;
    else
        cur_state <=next_state;
end

//组合逻辑判断状态转移条件
always @(*)begin
    next_state = st_idle;
    if(i2c_ack)begin
        next_state = st_stop;
    end
    case(cur_state)
        st_idle:begin
            if(i2c_exec)begin
                next_state = st_sladdr;
            end
            else begin
                next_state = st_idle;
            end
        end
        st_sladdr:begin
            if(st_done)begin
                if(bit_ctrl)begin
                    next_state = st_addr16;
                end
                else begin
                    next_state = st_addr8;
                end
            end
            else begin
                next_state = st_sladdr;
            end
        end
        st_addr16:begin
            if(st_done)begin
                next_state = st_addr8;
            end
            else begin
                next_state = st_addr16;
            end
        end
        st_addr8:begin
            if(st_done)begin
                if(!wr_flag)begin
                    next_state = st_data_wr;
                end
                else begin
                    next_state = st_addr_rd;
                end
            end
            else begin
                next_state = st_addr8;
            end
        end
        st_data_wr:begin
            if(st_done)begin
                next_state = st_stop;
            end
            else begin
                next_state = st_data_wr;
            end
        end
        st_addr_rd:begin
            if(st_done)begin
                next_state = st_data_rd;
            end
            else begin
                next_state = st_addr_rd;
            end
        end
        st_data_rd:begin
            if(st_done)begin
                next_state = st_stop;
            end
            else begin
                next_state = st_data_rd;
            end
        end
        st_stop:begin
            if(st_done)begin
                next_state = st_idle;
            end
            else begin
                next_state = st_stop;
            end
        end
        default: next_state = st_idle;
    endcase
end

//时序电路描述状态输出
always @(posedge dri_clk or negedge rst_n)begin
    if(!rst_n)begin
        scl <= 1'b1;//scl时钟信号
        sda_out <= 1'b1;//sda输出信号
        sda_dir <= 1'b1;//i2c数据方向控制
        i2c_done <= 1'b0;//i2c一次操作完成
        i2c_ack <= 1'b0;//i2c应答
        cnt <= 1'b0;//计数
        st_done <= 1'b0;//状态结束
        data_r <= 1'b0;//读取的数据
        i2c_data_r <=1'b0;//i2c读出的数据
        wr_flag <= 1'b0;//写标志
        addr_t <= 1'b0;//地址
        data_wr_t <= 1'b0;//I2C需要写入的数据的临时寄存
    end
    else begin
        st_done <= 1'b0;
        cnt <= cnt +1'b1;
        case(cur_state)
            st_idle:begin
                scl <= 1'b1;
                sda_out <= 1'b1;
                sda_dir <= 1'b1;
                i2c_done <= 1'b0;
                cnt <= 1'b0;
                if(i2c_exec)begin
                    wr_flag <= i2c_rh_wl;
                    addr_t <= i2c_addr;
                    data_wr_t <= i2c_data_w;
                    i2c_ack <= 1'b0;
                end
            end
            st_sladdr:begin
                case(cnt)
                    7'd3: scl <= 1'b0;
                    7'd5: scl <= 1'b1;
                    7'd7: scl <= 1'b0;
                    7'd9: scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd33: scl <= 1'b1;
                    7'd35: scl <= 1'b0;
                    7'd37: scl <= 1'b1;
                    7'd39:begin scl <= 1'b0; cnt <=0; end
                    7'd1:begin sda_out <= 1'b0; scl <=1'b1; end//sda_out降为0时，scl仍然为高电平，形成开始信号
                    7'd4: sda_out <= SLAVE_ADDR[6];
                    7'd8: sda_out <= SLAVE_ADDR[5];
                    7'd12: sda_out <= SLAVE_ADDR[4];
                    7'd16: sda_out <= SLAVE_ADDR[3];
                    7'd20: sda_out <= SLAVE_ADDR[2];
                    7'd24: sda_out <= SLAVE_ADDR[1];
                    7'd28: sda_out <= SLAVE_ADDR[0];
                    7'd32: sda_out <= 1'b0;//RW信号
                    7'd36:begin
                        sda_dir <= 1'b0;
                        sda_out <= 1'b1;
                    end
                    7'd38:begin
                        st_done <= 1'b1;
                        if(sda_in == 1'b1)begin
                            i2c_ack <= 1'b1;
                        end
                    end
                    default: ;
                endcase
            end
            st_addr16:begin
                case(cnt)
                    7'd3: scl <= 1'b0;
                    7'd5: scl <= 1'b1;
                    7'd7: scl <= 1'b0;
                    7'd9: scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd33: scl <= 1'b1;
                    7'd35: scl <= 1'b0;
                    7'd37: scl <= 1'b1;
                    7'd39:begin scl <= 1'b0; cnt <=0; end
                    7'd1:begin sda_out <= 1'b0; scl <=1'b1; end
                    7'd4: sda_out <= addr_t[15];
                    7'd8: sda_out <= addr_t[14];
                    7'd12: sda_out <= addr_t[13];
                    7'd16: sda_out <= addr_t[12];
                    7'd20: sda_out <= addr_t[11];
                    7'd24: sda_out <= addr_t[10];
                    7'd28: sda_out <= addr_t[9];
                    7'd32: sda_out <= addr_t[8];
                    7'd36:begin
                        sda_dir <= 1'b0;
                        sda_out <= 1'b1;
                    end
                    7'd38:begin
                        st_done <= 1'b1;
                        if(sda_in == 1'b1)begin
                            i2c_ack <= 1'b1;
                        end
                    end
                    default: ; 
                endcase
            end
            st_addr8:begin
                case(cnt)
                    7'd3: scl <= 1'b0;
                    7'd5: scl <= 1'b1;
                    7'd7: scl <= 1'b0;
                    7'd9: scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd33: scl <= 1'b1;
                    7'd35: scl <= 1'b0;
                    7'd37: scl <= 1'b1;
                    7'd39:begin scl <= 1'b0; cnt <=0; end
                    7'd1:begin sda_out <= 1'b0; scl <=1'b1; sda_dir <= 1'b1; end
                    7'd4: sda_out <= addr_t[7];
                    7'd8: sda_out <= addr_t[6];
                    7'd12: sda_out <= addr_t[5];
                    7'd16: sda_out <= addr_t[4];
                    7'd20: sda_out <= addr_t[3];
                    7'd24: sda_out <= addr_t[2];
                    7'd28: sda_out <= addr_t[1];
                    7'd32: sda_out <= addr_t[0];
                    7'd36:begin
                        sda_dir <= 1'b0;
                        sda_out <= 1'b1;
                    end
                    7'd38:begin
                        st_done <= 1'b1;
                        if(sda_in == 1'b1)begin
                            i2c_ack <= 1'b1;
                        end
                    end
                    default: ; 
                endcase
            end
            st_data_wr:begin
                case(cnt)
                    7'd3: scl <= 1'b0;
                    7'd5: scl <= 1'b1;
                    7'd7: scl <= 1'b0;
                    7'd9: scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd33: scl <= 1'b1;
                    7'd35: scl <= 1'b0;
                    7'd37: scl <= 1'b1;
                    7'd39:begin scl <= 1'b0; cnt <=0; end
                    7'd1:begin sda_out <= 1'b0; scl <=1'b1; sda_dir <= 1'b1; end
                    7'd4: sda_out <= data_wr_t[7];
                    7'd8: sda_out <= data_wr_t[6];
                    7'd12: sda_out <= data_wr_t[5];
                    7'd16: sda_out <= data_wr_t[4];
                    7'd20: sda_out <= data_wr_t[3];
                    7'd24: sda_out <= data_wr_t[2];
                    7'd28: sda_out <= data_wr_t[1];
                    7'd32: sda_out <= data_wr_t[0];
                    7'd36:begin
                        sda_dir <= 1'b0;
                        sda_out <= 1'b1;
                    end
                    7'd38:begin
                        st_done <= 1'b1;
                        if(sda_in == 1'b1)begin
                            i2c_ack <= 1'b1;
                        end
                    end
                    default: ; 
                endcase
            end
            st_addr_rd:begin
                case(cnt)
                    7'd3: scl <= 1'b0;
                    7'd5: scl <= 1'b1;
                    7'd7: scl <= 1'b0;
                    7'd9: scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd33: scl <= 1'b1;
                    7'd35: scl <= 1'b0;
                    7'd37: scl <= 1'b1;
                    7'd39:begin scl <= 1'b0; cnt <=0; end
                    7'd1:begin sda_out <= 1'b0; scl <= 1'b1; sda_dir <= 1'b1; end
                    7'd4: sda_out <= SLAVE_ADDR[6];
                    7'd8: sda_out <= SLAVE_ADDR[5];
                    7'd12: sda_out <= SLAVE_ADDR[4];
                    7'd16: sda_out <= SLAVE_ADDR[3];
                    7'd20: sda_out <= SLAVE_ADDR[2];
                    7'd24: sda_out <= SLAVE_ADDR[1];
                    7'd28: sda_out <= SLAVE_ADDR[0];
                    7'd32: sda_out <= 1'b1;
                    7'd36:begin
                        sda_dir <= 1'b0;
                        sda_out <= 1'b1;
                    end
                    7'd38:begin
                     st_done <= 1'b1;
                        if(sda_in == 1'b1)begin
                            i2c_ack <= 1'b1;
                        end
                        else begin 
                            i2c_ack <= 1'b0;
                        end
                    end
                    default: ; 
                endcase
		end
                st_data_rd:begin
                    case(cnt)
                    7'd3: scl <= 1'b0;
                    7'd5: scl <= 1'b1;
                    7'd7: scl <= 1'b0;
                    7'd9: scl <= 1'b1;
                    7'd11: scl <= 1'b0;
                    7'd13: scl <= 1'b1;
                    7'd15: scl <= 1'b0;
                    7'd17: scl <= 1'b1;
                    7'd19: scl <= 1'b0;
                    7'd21: scl <= 1'b1;
                    7'd23: scl <= 1'b0;
                    7'd25: scl <= 1'b1;
                    7'd27: scl <= 1'b0;
                    7'd29: scl <= 1'b1;
                    7'd31: scl <= 1'b0;
                    7'd33: scl <= 1'b1;
                    7'd35: scl <= 1'b0;
                    7'd37: scl <= 1'b1;
                    7'd39:begin scl <= 1'b0; cnt <=0; i2c_data_r <= data_r; end
                    7'd1:begin sda_out <= 1'b0; scl <= 1'b1; sda_dir <= 1'b0; end
                    7'd4: data_r[7] <= sda_in;
                    7'd8: data_r[6] <= sda_in;
                    7'd12: data_r[5] <= sda_in;
                    7'd16: data_r[4] <= sda_in;
                    7'd20: data_r[3] <= sda_in;
                    7'd24: data_r[2] <= sda_in;
                    7'd28: data_r[1] <= sda_in;
                    7'd32: data_r[0] <= sda_in;
                    7'd36:begin
                        sda_dir <= 1'b1;
                        sda_out <= 1'b1;
                    end
                    7'd38:begin
                        st_done <= 1'b1;
                        i2c_ack <= 1'b0;
                    end
                    default: ; 
                endcase
		end
                st_stop:begin
                    case(cnt)
                    7'd1:begin
                        sda_dir <= 1'b1;
                        sda_out <= 1'b0;
                    end
                    7'd3:scl <= 1'b1;
                    7'd4:sda_out <= 1'b0;
                    7'd16:begin
                        if(!i2c_ack)begin
                            st_done <= 1'b1;
                            cnt <= 1'b0;
                        end
                        else begin
                            st_done <= 1'b0;
                            cnt <= 1'b0;
                            i2c_done <= 1'b1;
                        end
                    end
                    default: ;
                    endcase
                end
        endcase
    end
end
endmodule