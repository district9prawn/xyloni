----------------------------------------------------------------
-- UART Receiver Module
-- This module receives serial data over a UART interface.
-- It receives 8 bits of data with a start and stop bit.
-- When receive is complete, o_rx_dv will be driven high for one clock cycle.
--
-- Set generics g_CLK_BIT as follows:
-- g_CLK_BIT = (i_clk_freq / uart_freq)
-- Example: 10MHz / 115200 = 87
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic (
        g_CLKS_PER_BIT : integer := 115 -- Remember to set this in instantiation as default won't work
    );
    port (
        i_clk            : in  std_logic;
        i_rx_serial      : in  std_logic; -- Data stream
        o_rx_dv          : out std_logic;  -- This stands for data valid?
        o_rx_byte        : out std_logic_vector(7 downto 0) -- Received data in parallel form
    );
end entity uart_rx;

architecture rtl of uart_rx is
    type t_SM_MAIN is(
        STATE_IDLE,
        STATE_START_BIT,
        STATE_DATA,
        STATE_STOP_BIT,
        STATE_CLEANUP
    );
    signal r_SM_MAIN : t_SM_MAIN := STATE_IDLE;
    signal r_RX_Data_R : std_logic := '0'; -- CLocked incoming rx data register?
    signal r_RX_Data   : std_logic := '0';
    signal r_Clk_Count : integer range 0 to g_CLKS_PER_BIT-1 := 0; -- TODO makes these unsigned to define synthesizable bit width
    signal r_Bit_Index : integer range 0 to 7 := 0; -- 8 bits total
    signal r_RX_Byte   : std_logic_vector(7 downto 0) := (others => '0');
    signal r_RX_DV     : std_logic := '0';

begin
    -- Process to double buffer the incoming data and avoid metastability
    p_SAMPLE : process(i_clk) -- TODO: crap name
    begin
        if rising_edge(i_clk) then
            r_RX_Data_R <= i_rx_serial;
            r_RX_Data   <= r_RX_Data_R;
        end if;
    end process p_SAMPLE;

    -- Process for the main state machine
    p_UART_RX : process(i_clk)
    begin
        if rising_edge(i_clk) then
            case r_SM_MAIN is
                -- Check for start bit during the idle state
                when STATE_IDLE =>
                    r_RX_DV <= '0';
                    r_Clk_Count <= 0;
                    r_Bit_Index <= 0;
                    
                    if r_RX_Data = '0' then -- Start bit detected
                        r_SM_MAIN <= STATE_START_BIT;
                    else
                        r_SM_MAIN <= STATE_IDLE;
                    end if;
                
                -- Check the start bit
                -- TODO: Is it a good approach to check just in the middle?
                -- Maybe it would be better to continuously check the line is low for a whole start bit
                when STATE_START_BIT =>
                    if r_Clk_Count = g_CLKS_PER_BIT/2 then -- Valid start bit. Start sampling data
                        if r_RX_Data = '0' then
                            r_Clk_Count <= 0; -- Reset the bit period counter
                            r_SM_MAIN <= STATE_DATA;
                        else
                            r_SM_MAIN <= STATE_IDLE; -- Invalid start bit
                        end if;
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_MAIN <= STATE_START_BIT; -- Keep waiting for the full start bit period
                    end if;

                -- Sample the serial data bits at the appropriate times during the bit period
                when STATE_DATA =>
                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1; -- Don't sample yet
                        r_SM_MAIN <= STATE_DATA;
                    else
                        r_Clk_Count <= 0; -- Reset the bit period counter
                        r_Rx_Byte(r_Bit_Index) <= r_RX_Data; -- Store the received bit
                        -- Check if all bits have been sent
                        if r_Bit_Index < 7 then
                            r_Bit_Index <= r_Bit_Index + 1; -- Move to the next bit
                            r_SM_MAIN <= STATE_DATA;
                        else
                            r_Bit_Index <= 0; -- Reset the bit index
                            r_SM_MAIN <= STATE_STOP_BIT; -- All bits received, go to stop bit state
                        end if;
                    end if;

                -- Check the stop bit
                when STATE_STOP_BIT =>
                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_MAIN <= STATE_STOP_BIT;
                    else
                        -- TODO: Actually check stop bit validity on the data line
                        r_Clk_Count <= 0; -- Reset the bit period counter
                        r_RX_DV <= '1'; -- Data valid signal
                        r_SM_MAIN <= STATE_CLEANUP;
                    end if;

                -- Cleanup state
                when STATE_CLEANUP =>
                    r_SM_MAIN <= STATE_IDLE; -- Go back to idle state
                    r_RX_Byte <= r_RX_Byte; -- Output the received byte
                    r_RX_DV <= '0'; -- Clear data valid signal

                when others =>
                    r_SM_MAIN <= STATE_IDLE;
                    r_RX_DV <= '0'; -- Clear data valid signal

            end case;
        end if;
    end process p_UART_RX;

    o_rx_dv <= r_RX_DV; -- Output the data valid signal
    o_rx_byte <= r_RX_Byte; -- Output the received byte

end architecture rtl;
            
            
                        


                    
                    
