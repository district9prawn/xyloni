----------------------------------------------------------------
-- UART Transmitter Module
-- This module transmits serial data over a UART interface.
-- It transmits 8 bits of data with a start and stop bit.
-- When receive is complete, o_tx_done will be driven high for one clock cycle.
--
-- Set generics g_CLK_BIT as follows:
-- g_CLK_BIT = (clk_freq / uart_freq)
-- Example: 10MHz / 115200 = 87
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic (
        g_CLKS_PER_BIT : integer := 115 -- Remember to set this in instantiation as default won't work
    );
    port (
        clk            : in  std_logic;
        i_tx_dv          : in  std_logic;
        i_tx_byte        : in  std_logic_vector(7 downto 0); -- Data to be transmitted
        o_tx_serial      : out std_logic; -- Serial data output
        o_tx_active      : out std_logic; -- Indicates if transmission is active
        o_tx_done        : out std_logic  -- Indicates if transmission is done
        );
end entity uart_tx;

architecture rtl of uart_tx is
    type t_SM_MAIN is(
        STATE_IDLE,
        STATE_START_BIT,
        STATE_DATA,
        STATE_STOP_BIT,
        STATE_CLEANUP
    );

    signal r_SM_MAIN     : t_SM_MAIN := STATE_IDLE;
    signal r_TX_Data     : std_logic_vector(7 downto 0) := (others => '0');
    signal r_Clk_Count   : integer range 0 to g_CLKS_PER_BIT-1 := 0; -- TODO makes these unsigned to define synthesizable bit width
    signal r_Bit_Index   : integer range 0 to 7 := 0; -- 8 bits total
    signal r_TX_Serial   : std_logic := '1'; -- Idle state for UART is high
    signal r_TX_Active   : std_logic := '0'; -- Transmission active signal
    signal r_TX_Done     : std_logic := '0'; -- Transmission done signal

begin
    p_UART_TX : process(clk)
    begin
        if rising_edge(clk) then
            case r_SM_MAIN is
                -- Check for data valid signal during the idle state
                when STATE_IDLE =>
                    r_TX_Active <= '0';
                    r_TX_Done <= '0';
                    r_TX_Serial <= '1'; -- Drive line to high idle state
                    r_Clk_Count <= 0;
                    r_Bit_Index <= 0;

                    if i_tx_dv = '1' then
                        r_SM_MAIN <= STATE_START_BIT;
                        r_TX_Data <= i_tx_byte; -- Load data to be transmitted
                    else
                        r_SM_MAIN <= STATE_IDLE;
                    end if;

                -- Transmit start bit
                when STATE_START_BIT =>
                    r_TX_Active <= '1';
                    r_TX_Serial <= '0';

                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_MAIN <= STATE_START_BIT; -- Wait for start bit to finish
                    else
                        r_SM_MAIN <= STATE_DATA;
                        r_Clk_Count <= 0;
                    end if;

                -- Transmit data bits
                when STATE_DATA =>
                    r_TX_Serial <= r_TX_Data(r_Bit_Index);
                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_MAIN <= STATE_DATA; -- Hold data bit longer
                    else
                        r_Clk_Count <= 0;   
                        if r_Bit_Index < 7 then
                            r_Bit_Index <= r_Bit_Index + 1; -- Move to next bit
                            r_SM_MAIN <= STATE_DATA;
                        else
                            r_SM_MAIN <= STATE_STOP_BIT; -- All data bits sent, move to stop bit
                            r_Bit_Index <= 0; -- Reset bit index
                        end if;
                end if;

                -- Transmit stop bit
                when STATE_STOP_BIT =>
                    r_TX_Serial <= '1'; -- Drive line to high idle state
                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_MAIN <= STATE_STOP_BIT; -- Hold stop bit longer
                    else
                        r_SM_MAIN <= STATE_CLEANUP;
                        r_Clk_Count <= 0;
                        r_TX_Done <= '1'; -- Indicate transmission is done
                    end if;

                -- Cleanup state
                when STATE_CLEANUP =>
                    r_TX_Active <= '0'; -- Clear active signal
                    r_TX_Done   <= '0'; -- Clear done signal
                    r_SM_MAIN <= STATE_IDLE; -- Go back to idle state

                when others =>
                    r_SM_MAIN <= STATE_IDLE; -- Default to idle state

            end case;
        end if;
    end process p_UART_TX;

    -- Assign internal signals to output ports
    o_tx_serial <= r_TX_Serial; -- Output the serial data
    o_tx_active <= r_TX_Active; -- Output the active signal
    o_tx_done   <= r_TX_Done;   -- Output the done signal

end architecture rtl;