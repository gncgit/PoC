-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	An upscaling gearbox module with a dependent clock (dc) interface.
--
-- Description:
-- -------------------------------------
--	This module provides a upscaling gearbox with a dependent clock (dc)
--	interface. It perfoems a 'byte' to 'word' collection. The default order is
--	LITTLE_ENDIAN (starting at byte(0)). Input "In_Data" is of clock domain
--	"Clock1"; output "Out_Data" is of clock domain "Clock2". The "In_Align"
--	is required to mark the starting byte in the word. An optional input
--	register can be added by enabling (ADD_INPUT_REGISTERS = TRUE).
--
-- Assertions:
-- ===========
--	- Clock periods of Clock1 and Clock2 MUST be multiples of each other.
--	- Clock1 and Clock2 MUST be phase aligned (related) to each other.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================


library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.components.all;


entity gearbox_up_dc is
  generic (
		INPUT_BITS						: POSITIVE				:= 8;														-- input bit width
		INPUT_ORDER						: T_BIT_ORDER			:= LSB_FIRST;										-- LSB_FIRST: start at byte(0), MSB_FIRST: start at byte(n-1)
		OUTPUT_BITS						: POSITIVE				:= 32;													-- output bit width
		ADD_INPUT_REGISTERS		: BOOLEAN					:= FALSE												-- add input register @Clock1
	);
  port (
	  Clock1								: in	STD_LOGIC;																	-- input clock domain
		Clock2								: in	STD_LOGIC;																	-- output clock domain
		In_Align							: in	STD_LOGIC;																	-- align word (one cycle high impulse)
		In_Data								: in	STD_LOGIC_VECTOR(INPUT_BITS - 1 downto 0);	-- input word
		Out_Data							: out STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0);	-- output word
		Out_Valid							: out	STD_LOGIC																		-- output is valid
	);
end entity;


architecture rtl OF gearbox_up_dc is
	constant BIT_RATIO				: REAL			:= real(OUTPUT_BITS) / real(INPUT_BITS);

	constant INPUT_CHUNKS			: POSITIVE	:= integer(BIT_RATIO);
	constant BITS_PER_CHUNK		: POSITIVE	:= INPUT_BITS;

	constant COUNTER_MAX			: POSITIVE	:= INPUT_CHUNKS - 1;
	constant COUNTER_BITS 		: POSITIVE	:= log2ceil(COUNTER_MAX + 1);

	subtype T_CHUNK			is STD_LOGIC_VECTOR(BITS_PER_CHUNK - 1 downto 0);
	type T_CHUNK_VECTOR	is array(NATURAL range <>) of T_CHUNK;

	-- convert chunk-vector to flatten vector
	function to_slv(slvv : T_CHUNK_VECTOR) return STD_LOGIC_VECTOR is
		variable slv			: STD_LOGIC_VECTOR((slvv'length * BITS_PER_CHUNK) - 1 downto 0);
	begin
		for i in slvv'range loop
			slv(((i + 1) * BITS_PER_CHUNK) - 1 downto i * BITS_PER_CHUNK)		:= slvv(i);
		end loop;
		return slv;
	end function;

	signal Counter_us					: UNSIGNED(COUNTER_BITS - 1 downto 0)					:= (others => '0');
	signal Select_us					: UNSIGNED(COUNTER_BITS - 1 downto 0);

	signal In_Data_d					: STD_LOGIC_VECTOR(INPUT_BITS - 1 downto 0)		:= (others => '0');
	signal Data_d							: T_CHUNK_VECTOR(INPUT_CHUNKS - 2 downto 0)		:= (others => (others => '0'));
	signal Collected					: STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0);
	signal Collected_swapped	: STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0);
	signal Collected_en				: STD_LOGIC;
	signal Collected_d				: STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0)	:= (others => '0');
	signal DataOut_d					: STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0)	:= (others => '0');

	signal Valid_r						: STD_LOGIC																		:= '0';
	signal Valid_d						: STD_LOGIC																		:= '0';
begin
	assert (INPUT_BITS < OUTPUT_BITS) report "INPUT_BITS must be less than OUTPUT_BITS, otherwise it's no up-sizing gearbox." severity FAILURE;

	-- input register @Clock1
	In_Data_d	<= In_Data when registered(Clock1, ADD_INPUT_REGISTERS);

	-- byte alignment counter @Clock1
	process(Clock1)
	begin
		if rising_edge(Clock1) then
			if (In_Align = '1') then
				Counter_us		<= to_unsigned(1, Counter_us'length);
				Valid_r				<= '0';
			elsif (upcounter_equal(cnt => Counter_us, value => COUNTER_MAX) = '1') then
				Counter_us		<= to_unsigned(0, Counter_us'length);
				Valid_r				<= '1';
			else
				Counter_us		<= Counter_us + 1;
			end if;
		end if;
	end process;

	Select_us		<= mux(In_Align, Counter_us, (Counter_us'range => '0'));

	-- delay registers @Clock1
	process(Clock1)
	begin
		if rising_edge(Clock1) then
			for j in 0 to INPUT_CHUNKS - 2 loop
				if (j = to_index(Select_us, COUNTER_MAX)) then					-- D-FF enable
					Data_d(j)		<= In_Data_d;
				end if;
			end loop;
		end if;
	end process;

	-- compose output word
	Collected					<= In_Data_d & to_slv(Data_d);
	Collected_swapped	<= ite((INPUT_ORDER = LSB_FIRST), Collected, swap(Collected, INPUT_BITS));

	-- register collected signals again @Clock1
	Collected_en	<= upcounter_equal(cnt => Select_us, value => COUNTER_MAX);
	Collected_d		<= ffdre(q => Collected_d, d => Collected_swapped, en => Collected_en) when rising_edge(Clock1);

	-- add output register @Clock2
	DataOut_d	<= Collected_d	when rising_edge(Clock2);
	Valid_d		<= Valid_r			when rising_edge(Clock2);
	Out_Data	<= DataOut_d;
	Out_Valid	<= Valid_d;
end architecture;
