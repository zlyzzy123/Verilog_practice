`timescale 1ns / 1ps

module tb_spi_whole;

    // Inputs
    reg          I_clk       ;
    reg          I_rst_n     ;
    reg          I_rx_en     ;
    reg          I_tx_en     ;
    reg   [7:0]  I_data_in   ;
    reg          I_spi_miso  ;
    reg          I_cpol      ;  //传输模式选择
    reg          I_cpha      ;  //传输模式选择


    // Outputs
    wire  [7:0]  O_data_out  ;
    wire         O_tx_done   ;
    wire         O_rx_done   ;
    wire         O_spi_sck   ;
    wire         O_spi_cs    ;
    wire         O_spi_mosi  ;
	wire  [4:0]  state       ;
	
	
	reg          data_clk    ;
	
	
    // Instantiate the Unit Under Test (UUT)
    spi_whole uut (
        .I_clk           (I_clk       ), 
        .I_rst_n         (I_rst_n     ), 
        .I_rx_en         (I_rx_en     ), 
        .I_tx_en         (I_tx_en     ), 
        .I_data_in       (I_data_in   ), 
        .O_data_out      (O_data_out  ), 
        .O_tx_done       (O_tx_done   ), 
        .O_rx_done       (O_rx_done   ), 
        .I_spi_miso      (I_spi_miso  ), 
        .O_spi_sck       (O_spi_sck   ), 
        .O_spi_cs        (O_spi_cs    ), 
        .O_spi_mosi      (O_spi_mosi  ),
		.I_cpol          (I_cpol      ),
		.I_cpha          (I_cpha      ),
		.state           (state       )	
    );

/*
//*****************************************仅仅发送********************************************************
    initial begin
        // Initialize Inputs
        I_clk = 0;
        I_rst_n = 0;
        I_rx_en = 0;
        I_tx_en = 1;
        I_data_in = 8'h00;
		I_cpol = 0;
		I_cpha = 0;

        // Wait 100 ns for global reset to finish
        #100;
        I_rst_n = 1;  

			end
    
    always #10 I_clk = ~I_clk ;
    
    always @(posedge I_clk or negedge I_rst_n)
    begin
         if(!I_rst_n)
            I_data_in <= 8'h00;
         else 
            I_data_in <= I_data_in + 1'b1 ;            
    end

	

//*****************************************仅仅接收********************************************************
    initial begin
        // Initialize Inputs
        I_clk = 0;
		data_clk = 0;
        I_rst_n = 0;
        I_rx_en = 1;
        I_tx_en = 0;
        I_data_in = 8'h00;
		I_cpol = 0;//传输模式选择
		I_cpha = 0;//传输模式选择

        // Wait 100 ns for global reset to finish
        #100;
        I_rst_n = 1;  

			end
    
    always #10 I_clk = ~I_clk ;
    always #5 data_clk = ~data_clk ;
	
    always @(posedge data_clk or negedge I_rst_n)
    begin
         if(!I_rst_n)
            I_spi_miso <= 1'b0;
         else 
            I_spi_miso <= I_spi_miso + 1'b1 ;            
    end	  
*/

	
//*****************************************同时发送和接收********************************************************
//发送的测试激励
initial begin
        // Initialize Inputs
        I_clk = 0;
		data_clk = 0;
        I_rst_n = 0;
        I_rx_en = 1;
        I_tx_en = 1;
        I_data_in = 8'h00;
		I_cpol = 0;
		I_cpha = 0;

        // Wait 100 ns for global reset to finish
        #100;
        I_rst_n = 1;  

    end
    
    always #10 I_clk = ~I_clk ;
    
    always @(posedge I_clk or negedge I_rst_n)
    begin
         if(!I_rst_n)
            I_data_in <= 8'h00;
         else 
            I_data_in <= I_data_in + 1'b1 ;            
    end


//接收的测试激励    
    always #5 data_clk = ~data_clk ;
	
    always @(posedge data_clk or negedge I_rst_n)
    begin
         if(!I_rst_n)
            I_spi_miso <= 1'b0;
         else 
            I_spi_miso <= I_spi_miso + 1'b1 ;            
    end	  


endmodule