-- smal example design for the Xyloni Efinix Eval Board
-- By Harald Werner
-- 15.10.2020
-- 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_loopback is
	port ( 
		clk 			: in std_logic;							-- clock input. Could be from internal osc (T8) or from the external 33.3MHz clock use GPIOl_20
		setn 		: in std_logic;							--  Set signal, low active; sett all outputs to '1' (LED are high active, means all LEDs msut be ON) GPIOR_02
		stopn 		: in std_logic;							-- Stop signal, low active Stop counting GPIOR_15
		Dataout 	: out std_logic_vector ( 3 downto 0); 	-- Output data connected to the LEDs (high active); GPIOR_17,GPIOR_16,GPIOR_37,GPIOL_21
		tx			: in std_logic; -- Serial out from FTDI
		rx			: out std_logic);
end UART_loopback;

architecture rtl of UART_loopback is
	signal tx_led : std_logic;
begin
	cnt_process: process(tx,setn)
	begin
		if setn = '0' then
			-- Asynchronous reset
			Dataout <= (others => '1');
		elsif rising_edge(tx) then
			tx_led <= not tx_led;
			Dataout <= "000" & tx_led; -- Connect intermediate rx and tx signal to output
		end if;
	end process cnt_process;

	-- Connect the tx and rx signals to the output
	rx <= tx; -- Loopback the tx signal to rx

end architecture rtl;

-- Constraint for clock
-- create_clock -period 30 [get_ports {clk}]
					