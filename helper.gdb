define print_uart
	set $base = 0x10000000
	printf "\n"

	printf "input registers:\n" 
	printf "RBR at "
	x/tb (unsigned char *)$base + (char)UART_RBR_OFFSET
	printf "LSR at "
	x/tb (unsigned char *)$base + (char)UART_LSR_OFFSET
	printf "\n"

	printf "output registers:\n" 
	printf "DLL at "
	x/tb (unsigned char *)$base + (char)UART_DLL_OFFSET
	printf "DLM at "
	x/tb (unsigned char *)$base + (char)UART_DLM_OFFSET
	printf "FCR at "
	x/tb (unsigned char *)$base + (char)UART_FCR_OFFSET
	printf "LCR at "
	x/tb (unsigned char *)$base + (char)UART_LCR_OFFSET
	printf "\n"

	printf "input and output registers:\n" 
	printf "IER at "
	x/tb (unsigned char *)$base + (char)UART_IER_OFFSET
	printf "\n"
end

