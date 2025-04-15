% uq_psres.m
%
% Does a pseudo-vectorization of the psres function with respect to a set 
% of user defined parameters.
%
% This is a wrapper function to call the power system resiliency model 
% from UQ-Lab. Takes an input from UQ-Lab & a user-defined parameter set 
% and evaluates the power system resiliency model. Errors in the resiliency 
% model are not handled here, and must be handled at a higher level.
%
% Inputs:
%   X: An array of samples of a random vector, containing outage times in
%      the first N indices, and recovery times in the second N indices. [N_in x 2N double]
%   P: A structure containing the parameters of the resilience model
%       P.ac_cfm_settings: The settings for the AC-CFM model [struct]
%       P.network: The network to be analyzed. Must be initialized to s
%                  to support the PSres model. [MATPOWER case format]
%       P.event: A structure containing information about the resilience event
%           event.state: An array containing wind speed values at each time step [1 x event.length double]
%           event.active_set: A string array containing the set of active components, with
%                             indices in the first row and component types in the second. [2 x N String]
%           event.length: The length of the event. [Integer]
%           event.step: The amount of time represented by one time-step. [Double]
%       P.num_workers: An array containing the number of workers available to repair each component. [3 x 1 Integer]
%       P.Output: An array defining the outputs to compute. Should contain 
%                 the enumeration of the indicator to use in index 1 and the 
%                 enumeration of the metric to output in index 2. [N_out x 2 Integer]
% Outputs:
%   Y: The resilience metric computed using the given input and parameters. [N_out x N_in double]
%
% Author: Aidan Gerkis
% Date: 10-04-2025
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
function Y = uq_psres(X, P)
    %% Constants
    % Output Automation
    output_enumeration;

    %% Parameters
    % Extract parameters from UQ-Lab input
    recovery_params = struct("n_workers", P.num_workers, 'Mode', 'Explicit');
    resilience_event = struct("state", P.event.state, "active", P.event.active_set, "length", P.event.length, "step", P.event.step, 'Mode', 'Explicit'); % Compile all event parameters
    
    % Extract network parameters
    n_comp = [length(P.network.branch(:,1)); length(P.network.bus(:,1)); length(P.network.gen(:,1))]; % The number of each type of component

    %% Process Inputs & Run Model
    % Initialize output array
    Y = zeros(size(X, 1), size(P.output, 1));
    N = size(X, 2)/2;

    % Initialize input arrays
    recovery_times = struct("branches", zeros(1, n_comp(1)), "busses", zeros(1, n_comp(2)), "gens", zeros(1, n_comp(3)));
    contingencies = struct("branches", zeros(1, n_comp(1)), "busses", zeros(1, n_comp(2)), "gens", zeros(1, n_comp(3)));
    
    % Loop through each input
    for i=1:length(X(:, 1)) % For each row (inputs are stored as row vectors)
        % Assign Inputs
        % Failure time inputs
        contingencies.branches(str2double(P.event.active_set(1, :))) = ceil(X(i, 1:(N)));
        resilience_event.contingencies = contingencies; % Round input contingencies to integers

        % Recovery Time Inputs
        recovery_times.branches(str2double(P.event.active_set(1, :))) = X(i, (N + 1):end);
        recovery_params.recovery_times = recovery_times;
       
        % Run Model
        [~, ri, rm, ~] = psres(P.ac_cfm_settings, P.network, recovery_params, resilience_event, P.analysis_params, '', '');
        
        % Save all requested outputs
        for j=1:size(P.output, 1)
            switch P.type % Save output - dependent on specified type
                case "metric"
                    Y(i, j) = rm.(i_one(P.output(j, 1))).(i_two(P.output(j, 1))).(m(P.output(j, 2)));
                case "indicator"
                    Y(i, j, :) = ri.(i_one(P.output(j, 1))).(i_two(P.output(j, 1)));
                otherwise
                    disp("Error in uq_psres: Unrecognized output type");
            end
        end
    end
end