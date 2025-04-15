% res_model_accfm_settings.m
%
% Returns the default settings used when calling the AC-CFM function in my
% resilience model.
%
% Author: Aidan Gerkis
% Date: 20-11-2024
%
% This file is part of PSres.
% Copyright © 2025 Aidan Gerkis
%
% PSres is free software: you can redistribute it and/or modify it under 
% the terms of the GNU General Public License as published by the Free 
% Software Foundation, either version 3 of the License, or (at your option) 
% any later version.
% 
% This program is distributed in the hope that it will be useful, but 
% WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
% or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License 
% for more details.
% 
% You should have received a copy of the GNU General Public License along 
% with this program.  If not, see <http://www.gnu.org/licenses/>.
function s = res_model_accfm_settings()
    % Load Default Settings
    s = get_default_settings(); % Load AC-CFM settings
    s.verbose = 0; % Turn off/on output. Switch to 1 for debugging.
    
    % Initialize Memory Settings
    s.keep_networks_after_cascade = 0; % Indicates whether to keep the final network structure for each contingency in a batch process
    
    % Set AC-CFM Solver Settings
    s.max_recursion_depth = 100; % Maximum number of recursive iterations allowed in cascading failure analysis
    
    % Set MATPOWER Solver Settings
    s.mpopt.opf.ac.solver = 'IPOPT'; % Use Interior Point Method
    
    % Protection Parameters
    s.uvls_per_step = 0.05; % Amount of load shed per step of UVLS. Default is 0.05. [p.u.]
    s.uvls_max_steps = 5; % Number of UVLS steps allowed. Default is 5. [unitless]
    s.dP_limit = 1; % Maximum imbalance between generation before UFLS is applied. Default is 0.15. [p.u.]
    s.P_overhead = 0.1; % Ratio of power lost to transmission line losses. Default is 0.1. [unitless]
    s.Q_tolerance = 0.1; % Ratio by which reactive power limits may be exceeded before O/UXL is applied. Default is 0.1. [unitless]
end