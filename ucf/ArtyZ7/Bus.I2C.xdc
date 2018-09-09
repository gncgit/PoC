## =============================================================================================================================================================
## Xilinx Design Constraint File (XDC)
## =============================================================================================================================================================
## Board:         Digilent - ArtyZ7
## FPGA:          Xilinx Zynq 7000
## =============================================================================================================================================================
## Communication BUS
## =============================================================================================================================================================
## I2C
## =============================================================================================================================================================
## -----------------------------------------------------------------------------
##	Bank:				34	
##	VCCO:				VCC3V3	
##	Location:			J2	
## -----------------------------------------------------------------------------
## {INOUT}	 SerialClock - CK_SCL
set_property PACKAGE_PIN		P16		[ get_ports ArtyZ7_IIC_SerialClock ]	
## {INOUT}	 SerialData -  CK_SDA
set_property PACKAGE_PIN		P15		[ get_ports ArtyZ7_IIC_SerialData ]	

