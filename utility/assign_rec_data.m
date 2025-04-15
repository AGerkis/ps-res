% assign_rec_data.m
%
% Assigns data from input files into the correct input format for the
% resilience model. Currently accepts input data in the form of historical
% (or simulated) recovery times, from which realizations are sampled at
% run-time.
%
% If one filename is provided then the same data is provided for all
% components. Otherwise three filenames must be specified, one for each
% component. Filenames may be blank, however this should only be the case
% if component failures for that type are not modelled.
%
% Inputs:
%   fn_branch: The name of the file containing branch recovery data. [string]
%              OR
%              The name of the file containing recovery data for all components. [string]
%   fn_bus: The name of the file containing branch recovery data. [string]
%   fn_gen: The name of the file containing branch recovery data. [string]
%
% Outputs:
%   rec_data: A structure containing three fields, pertaining to the
%             recovery time samples for each component type. [struct]
%              - branch_recovery samples: Recovery data for branches. [1 x N_samples double]
%              - bus_recovery samples: Recovery data for buses. [1 x N_samples double]
%              - gen_recovery samples: Recovery data for generators. [1 x N_samples double]
%
% Author: Aidan Gerkis
% Date: 19-03-2025
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
function rec_data = assign_rec_data(fn_branch, fn_bus, fn_gen)
    %% Parse Inputs
    switch nargin
        case 1 % One file for all components
            fn_bus = fn_branch;
            fn_gen = fn_branch;
        case 3 % One file for each component (nothing to do
        otherwise % Error
            error("Incorrect number of inputs!");
    end
    
    %% Load Data & Populate Arrays
    % For branches
    if ~isequal(fn_branch, "")
        recovery_data = load(fn_branch).durations_trimmed';
        rec_data.branch_recovery_samples = recovery_data;
    else
        rec_data.branch_recovery_samples = [];
    end
    
    % For buses
    if ~isequal(fn_bus, "")
        recovery_data = load(fn_bus).durations_trimmed';
        rec_data.bus_recovery_samples = recovery_data;
    else
        rec_data.bus_recovery_samples = [];
    end
    
    % For generators
    if ~isequal(fn_gen, "")
        recovery_data = load(fname_gen_recovery_file).durations_trimmed';
        rec_data.gen_recovery_samples = recovery_data;
    else
        rec_data.gen_recovery_samples = [];
    end
end