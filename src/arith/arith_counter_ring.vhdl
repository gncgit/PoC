-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	Ring counter/Johnson Counter
--
-- Description:
-- -------------------------------------
-- This module implements an up/down ring-counter with loadable initial value
-- (``seed``) on reset. The counter can be configured to a Johnson counter by
-- enabling ``INVERT_FEEDBACK``. The number of counter bits is configurable with
-- ``BITS``.
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

library PoC;
use			PoC.utils.all;


entity arith_counter_ring is
	generic (
		BITS						: POSITIVE;
		INVERT_FEEDBACK	: BOOLEAN		:= FALSE																	-- FALSE -> ring counter;		TRUE -> johnson counter
	);
	port (
		Clock		: in	STD_LOGIC;																							-- Clock
		Reset		: in	STD_LOGIC;																							-- Reset
		seed		: in	STD_LOGIC_VECTOR(BITS - 1 downto 0)	:= (others => '0');	-- initial counter vector / load value
		inc			: in	STD_LOGIC														:= '0';							-- increment counter
		dec			: in	STD_LOGIC														:= '0';							-- decrement counter
		value		: out STD_LOGIC_VECTOR(BITS - 1 downto 0)											-- counter value
	);
end entity;


architecture rtl of arith_counter_ring is
	constant invert		: std_logic			:= to_sl(INVERT_FEEDBACK);

	signal Counter		: std_logic_vector(BITS - 1 downto 0)	:= (others => '0');

begin
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Counter			<= seed;
			elsif (inc = '1') then
				Counter		<= Counter(Counter'high - 1 downto 0) & (Counter(Counter'high) xor invert);
			elsif (dec = '1') then
				Counter		<= (Counter(0) xor invert) & Counter(Counter'high downto 1);
			end if;
		end if;
	end process;

	value		<= Counter;
end architecture;
