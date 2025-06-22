-- Top level module UART control module
-- This module receives an eight byte burst of serial data over UART
-- After 8 bytes are received, the control module converts the bytes into four 16-bit numbers
-- The four 16-bit numbers are sorted largest to smallest and retransmitted over UART, again
-- as a burst of eight bytes.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.uart_transmitter.all;
use work.uart_receiver.all;
-- Add sorter or other module here too

entity uart_control is
    port (
        clk           : in std_logic; -- System clock
        rst           : in std_logic; -- Reset
        rx_data       : in std_logic; -- Serial data in to module
        frame_receive : out std_logic; -- Signal to indicate that the 8 byte frame has been received
        rx_dv_out     : out std_logic; -- Bring the rx_dv signal out to the top level
        tx_data       : out std_logic; -- Serial data out of module
        tx_done_out   : out std_logic -- Bring out the transmission done signal to the top level
    );
end entity uart_control;

architecture rtl of uart_control is
    type t_SM_MAIN is (
        STATE_IDLE,
        STATE_RECEIVE,
        STATE_SORT,
        STATE_TRANSMIT
    );

    type t_byte_array is array (0 to 7) of std_logic_vector(7 downto 0); -- Array to hold received bytes
    type word_array_t is array (0 to 3) of std_logic_vector(15 downto 0); -- Type for 16-bit words which we work with

    signal r_SM_MAIN        : t_SM_MAIN := STATE_IDLE;
    signal rx_buffer        : t_byte_array := (others => (others => '0')); -- Buffer for received bytes
    signal tx_buffer        : t_byte_array := (others => (others => '0')); -- Buffer for sorted bytes to transmit
    signal numbers_unsorted : word_array_t;
    signal numbers_sorted   : word_array_t; -- This should get optimized away since its redundant with tx_buffer
    signal rx_byte          : std_logic_vector(7 downto 0); -- Temporary signal for current received byte
    signal tx_byte          : std_logic_vector(7 downto 0); -- Temporary signal for byte to transmit 
    signal rx_count         : unsigned(2 downto 0) := (others => '0'); -- Count of received bytes
    signal tx_count         : unsigned(2 downto 0) := (others => '0'); -- Count of transmitted bytes
    signal tx_dv            : std_logic := '0'; -- Signal to tell uart_tx new data is ready
    signal rx_dv            : std_logic := '0'; -- Signal from uart_rx indicating new data is ready
    signal frame_done       : std_logic := '0'; -- Indicate that the 8 byte frame has been received

    -- Instantiate UART receiver
    uart_rx_inst : entity work.uart_receiver
        generic map (
            g_CLKS_PER_BIT => 115 -- TODO: Set for your clock frequency
        )
        port map (
            i_clk       => clk,
            i_rx_serial => rx_data,
            o_rx_dv     => rx_dv,
            o_rx_byte   => rx_byte
        );

    uart_tx_inst : entity work.uart_transmitter
        generic map (
            g_CLKS_PER_BIT => 115 -- TODO: Set for your clock frequency
        )
        port map (
            clk          => clk,
            i_tx_dv      => tx_dv
            i_tx_byte    => tx_byte,
            o_tx_serial  => tx_data,
            o_tx_active  => open, -- Not used in this design
            o_tx_done    => tx_done
        );

begin
    -- AI generated crap below. Check
    -- Main state machine process
    p_UART_Control : process(clk, rst)
    begin
        if rst = '1' then
            -- Asynchronous reset
            r_SM_MAIN <= STATE_IDLE; -- Reset state machine to idle

            -- Zero out internal signals
            rx_count <= (others => '0');
            tx_count <= (others => '0');
            tx_dv <= '0';
            rx_buffer <= (others => (others => '0'));
            tx_buffer <= (others => (others => '0'));
            numbers_unsorted <= (others => (others => '0'));
            numbers_sorted <= (others => (others => '0'));
            frame_done <= '0';

            -- Zero out the controller output signals
            rx_dv_out <= '0';
            tx_data <= '0';
            tx_done_out <= '0';
            frame_receive <= '0';

        elsif rising_edge(clk) then
            case r_SM_MAIN is
                when STATE_IDLE =>
                    -- What control signals do we look out for in idle state?
                    if rx_dv_out = '1' then
                        rx_buffer(to_integer(rx_count)) <= rx_byte; -- Store received byte
                        rx_count <= rx_count + 1;
                        if rx_count = 7 then -- Received 8 bytes
                            r_SM_MAIN <= STATE_RECEIVE;
                        end if;
                    end if;

                when STATE_RECEIVE =>
                    -- Convert received bytes to 16-bit words
                    numbers_unsorted(0) <= rx_buffer(0) & rx_buffer(1);
                    numbers_unsorted(1) <= rx_buffer(2) & rx_buffer(3);
                    numbers_unsorted(2) <= rx_buffer(4) & rx_buffer(5);
                    numbers_unsorted(3) <= rx_buffer(6) & rx_buffer(7);
                    r_SM_MAIN <= STATE_SORT;

                when STATE_SORT =>
                    -- Sort the numbers (simple bubble sort for demonstration)
                    for i in 0 to 2 loop
                        for j in i+1 to 3 loop
                            if unsigned(numbers_unsorted(i)) < unsigned(numbers_unsorted(j)) then
                                -- Swap
                                numbers_sorted(i) <= numbers_unsorted(j);
                                numbers_sorted(j) <= numbers_unsorted(i);
                            end if;
                        end loop;
                    end loop;
                    r_SM_MAIN <= STATE_TRANSMIT;

                when STATE_TRANSMIT =>
                    if tx_count < 4 then
                        tx_byte <= std_logic_vector(numbers_sorted(tx_count));
                        tx_dv <= '1'; -- Indicate new data is ready to transmit
                        tx_count <= tx_count + 1;
                    else
                        tx_dv <= '0'; -- No more data to transmit
                        r_SM_MAIN <= STATE_IDLE; -- Go back to idle state after transmission
                        tx_count <= (others => '0'); -- Reset transmit count
                    end if;

                when others =>
                    r_SM_MAIN <= STATE_IDLE; -- Default case to avoid latches

            end case;
        end if;

end architecture rtl;
