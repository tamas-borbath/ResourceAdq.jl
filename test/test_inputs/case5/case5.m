% Downloaded from: https://github.com/power-grid-lib/pglib-opf/blob/master/pglib_opf_case5_pjm.m
%                  commit: ffc3397d0476f33a4475f2bc226d8b765b463f55
% Added two more areas: 1-> Contains buses 1 and 2
%                       2-> Contains buses 3 and 4
%                       3-> Contains bus 5

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%                                                                  %%%%%
%%%%    IEEE PES Power Grid Library - Optimal Power Flow - v21.07     %%%%%
%%%%          (https://github.com/power-grid-lib/pglib-opf)           %%%%%
%%%%               Benchmark Group - Typical Operations               %%%%%
%%%%                         29 - July - 2021                         %%%%%
%%%%                                                                  %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   CASE5  Power flow data for modified 5 bus, 5 gen case based on PJM 5-bus system
%   Please see CASEFORMAT for details on the case file format.
%
%   Based on data from ...
%     F.Li and R.Bo, "Small Test Systems for Power System Economic Studies",
%     Proceedings of the 2010 IEEE Power & Energy Society General Meeting
%
%   Created by Rui Bo in 2006, modified in 2010, 2014.
%
%   Copyright (c) 2010 by The Institute of Electrical and Electronics Engineers (IEEE)
%   Licensed under the Creative Commons Attribution 4.0
%   International license, http://creativecommons.org/licenses/by/4.0/
%
%   Contact M.E. Brennan (me.brennan@ieee.org) for inquries on further reuse of
%   this dataset.
%
function mpc = pglib_opf_case5_pjm
mpc.version = '2';
mpc.baseMVA = 100.0;

%% bus data
%	bus_i	type	Pd	Qd	Gs	Bs	area	Vm	Va	baseKV	zone	Vmax	Vmin
mpc.bus = [
	1	 2	 0.0	 0.0001	 0.0	 0.0	 1	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
	2	 1	 300.0	 98.61	 0.0	 0.0	 1	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
	3	 2	 300.0	 98.61	 0.0	 0.0	 2	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
	4	 3	 400.0	 131.47	 0.0	 0.0	 2	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
	5	 2	 0.0	 0.0001	 0.0	 0.0	 3	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
];

%% generator data
%	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin Name
mpc.gen = [
	1	 20.0	 0.0	 30.0	 -30.0	 1.0	 100.0	 1	 40.0	 0.0;
	1	 85.0	 0.0	 127.5	 -127.5	 1.0	 100.0	 1	 170.0	 0.0;
	3	 260.0	 0.0	 390.0	 -390.0	 1.0	 100.0	 1	 520.0	 0.0;
	4	 100.0	 0.0	 150.0	 -150.0	 1.0	 100.0	 1	 200.0	 0.0;
	5	 300.0	 0.0	 450.0	 -450.0	 1.0	 100.0	 1	 600.0	 0.0;
];

%% generator cost data
%	2	startup	shutdown	n	c(n-1)	...	c0
mpc.gencost = [
	2	 0.0	 0.0	 3	   0.000000	  14.000000	   0.000000;
	2	 0.0	 0.0	 3	   0.000000	  15.000000	   0.000000;
	2	 0.0	 0.0	 3	   0.000000	  30.000000	   0.000000;
	2	 0.0	 0.0	 3	   0.000000	  40.000000	   0.000000;
	2	 0.0	 0.0	 3	   0.000000	  10.000000	   0.000000;
];

%% branch data
%	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle	status	angmin	angmax
mpc.branch = [
	1	 2	 0.00281	 0.0281	 0.00712	 300.0	 400.0	 400.0	 0.0	 0.0	 1	 -30.0	 30.0;
	1	 4	 0.00304	 0.0304	 0.00658	 300	 426	 426	 0.0	 0.0	 1	 -30.0	 30.0;
	1	 5	 0.00064	 0.0064	 0.03126	 300	 426	 426	 0.0	 0.0	 1	 -30.0	 30.0;
	2	 3	 0.00108	 0.0108	 0.01852	 300	 426	 426	 0.0	 0.0	 1	 -30.0	 30.0;
	3	 4	 0.00297	 0.0297	 0.00674	 300	 426	 426	 0.0	 0.0	 1	 -30.0	 30.0;
	4	 5	 0.00297	 0.0297	 0.00674	 300.0	 240.0	 240.0	 0.0	 0.0	 1	 -30.0	 30.0;
];

% area names
%column_names%	name
mpc.area_name = {
	'Area_1';
	'Area_2';
	'Area_3';
};

% bus names
%column_names%	name
mpc.bus_name = {
	'Center';
	'North';
	'West';
	'South';
	'East';
};

% generator names types and fuels
%column_names%	name    type    fuel
mpc.gen_name = {
	'1_SOLAR_1'	'PV'	'Solar';
	'1_FOSSIL_1'	'CT'	'Gas';
	'3_FOSSIL_1'	'CT'	'Gas';
	'4_WIND_1'	'WIND'	'Wind';
	'5_FOSSIL_1'	'CT'	'Gas';
};

% branch names 
%column_names%	name
mpc.branch_name = {
	'Center-North';
	'Center-South';
	'Center-East';
	'North-West';
	'West-South';
	'South-East';
};

% CNECs 
%column_names%	name    CNE    Contingency
mpc.CNECs = {
	'bc_Center-North'    'Center-North'    '';
	'bc_Center-South'    'Center-South'    '';
	'bc_Center-East'    'Center-East'    '';
	'bc_North-West'    'North-West'    '';
	'bc_West-South'    'West-South'    '';
	'bc_South-East'    'South-East'    '';
};

% INFO    : === Translation Options ===
% INFO    : Phase Angle Bound:           30.0 (deg.)
% INFO    : Line Capacity Model:         stat
% INFO    : Setting Flat Start
% INFO    : Line Capacity PAB:           15.0 (deg.)
% INFO    : 
% INFO    : === Generator Bounds Update Notes ===
% INFO    : 
% INFO    : === Base KV Replacement Notes ===
% INFO    : 
% INFO    : === Transformer Setting Replacement Notes ===
% INFO    : 
% INFO    : === Line Capacity Stat Model Notes ===
% INFO    : Updated Thermal Rating: on line 1-4 : Rate A, Rate B, Rate C , 9900.0, 0.0, 0.0 -> 426
% INFO    : Updated Thermal Rating: on line 1-5 : Rate A, Rate B, Rate C , 9900.0, 0.0, 0.0 -> 426
% INFO    : Updated Thermal Rating: on line 2-3 : Rate A, Rate B, Rate C , 9900.0, 0.0, 0.0 -> 426
% INFO    : Updated Thermal Rating: on line 3-4 : Rate A, Rate B, Rate C , 9900.0, 0.0, 0.0 -> 426
% INFO    : 
% INFO    : === Line Capacity Monotonicity Notes ===
% INFO    : 
% INFO    : === Voltage Setpoint Replacement Notes ===
% INFO    : Bus 1	: V=1.0, theta=0.0 -> V=1.0, theta=0.0
% INFO    : Bus 2	: V=1.0, theta=0.0 -> V=1.0, theta=0.0
% INFO    : Bus 3	: V=1.0, theta=0.0 -> V=1.0, theta=0.0
% INFO    : Bus 4	: V=1.0, theta=0.0 -> V=1.0, theta=0.0
% INFO    : Bus 5	: V=1.0, theta=0.0 -> V=1.0, theta=0.0
% INFO    : 
% INFO    : === Generator Setpoint Replacement Notes ===
% INFO    : Gen at bus 1	: Pg=40.0, Qg=0.0 -> Pg=20.0, Qg=0.0
% INFO    : Gen at bus 1	: Vg=1.0 -> Vg=1.0
% INFO    : Gen at bus 1	: Pg=170.0, Qg=0.0 -> Pg=85.0, Qg=0.0
% INFO    : Gen at bus 1	: Vg=1.0 -> Vg=1.0
% INFO    : Gen at bus 3	: Pg=323.49, Qg=0.0 -> Pg=260.0, Qg=0.0
% INFO    : Gen at bus 3	: Vg=1.0 -> Vg=1.0
% INFO    : Gen at bus 4	: Pg=0.0, Qg=0.0 -> Pg=100.0, Qg=0.0
% INFO    : Gen at bus 4	: Vg=1.0 -> Vg=1.0
% INFO    : Gen at bus 5	: Pg=466.51, Qg=0.0 -> Pg=300.0, Qg=0.0
% INFO    : Gen at bus 5	: Vg=1.0 -> Vg=1.0
% INFO    : 
% INFO    : === Writing Matpower Case File Notes ===