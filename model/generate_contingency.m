% generate_contingency.m
%
% Generates a contingency set based on the failure curves of the components
% in the network by generating a random number r~uniform(0,1) and comparing
% this to the value of the failure curve at the current environmental
% state, F(env). Note that the failure curve represents the probability of
% the component failure as a function of the environmental state. Currently
% this function assumes that each component type has only one failure
% curve, where each components failure curve may have a unique
% environmental state variable.
%
% Author: Aidan Gerkis
%
% Date: 14-11-2023
%
% Inputs:
%   network: The network (in AC-CFM format) for which to compute the
%            contingency set.
%   f_curves: The failure curves for each component, organized as a
%             structure, with the failure curves for each component type stored
%             in separate cell arrays.
%   env_state: The environmental state variable at each time step and for 
%              each component types failure curve variable, with time steps
%              as columns and component types as rows.
%   active_set: The set of components which should be considered in
%               contingency generation. IDs should correspond to position
%               in corresponding arrays.
%
% Outputs:
%   contingency_set: An array containing the time index when each component
%                    fails, set to 0 if the component does not fail.
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
function contingencies = generate_contingency(network, f_curves, env_state, active_set)
    % Process input parameters
    n_branch = length(network.branch(:, 1));
    n_bus = length(network.bus(:, 1));
    n_gen = length(network.gen(:, 1));

    if length(env_state(:, 1)) == 1 % If only one environmental state variable was given assume this is used for all components
        env_state = [env_state; env_state; env_state];
    end

    if ~exist('active_set', 'var') || isempty(active_set) % If optional variable was not passed assume all components are active
        active_set = [linspace(1, n_branch, n_branch), network.bus(:,1)', linspace(1, n_gen, n_gen);
                      repelem("branch", length(network.branch(:,1))), repelem("bus", length(network.bus(:,1))), repelem("gen", length(network.gen(:,1)))];
    end
    
    % Initialize output
    contingencies = struct("branches", zeros(1, n_branch), "busses", zeros(1, n_bus), "gens", zeros(1, n_gen));
    
    for i=1:length(env_state(1, :)) % Loop through each time
        % Loop through all components and compute failure
        % Branches
        [~, F_env_index] = min(abs(f_curves.branches{1,1}{:,1} - env_state(1, i))); % Determine index corresponding to current environmental state
    
        for j=1:sum(count(active_set(2,:), "branch"))
            index = str2double(active_set(1, j));
    
            r = rand; % Generate random number in [0,1]
            F_env = f_curves.branches{1, index}{1, 2}(F_env_index); % Extract failure probability w.r.t current environmental state
    
            if r < F_env % If component fails add it to the contingency set
                contingencies.branches(index) = contingencies.branches(index) + i*(1 - network.failed_branches(index)); % ensures that a component can only fail once
                network.failed_branches(index) = 1;
            end
        end
        
        % Busses
        [~, F_env_index] = min(abs(f_curves.busses{1,1}{:,1} - env_state(2, i))); % Determine index corresponding to current environmental state
    
        for j=1:sum(count(active_set(2,:), "bus"))
            index = str2double(active_set(1, j + sum(count(active_set(2,:), "branch"))));
    
            r = rand; % Generate random number in [0,1]
            F_env = f_curves.busses{1, index}{1, 2}(F_env_index); % Extract failure probability w.r.t current environmental state
    
            if r < F_env % If component fails add it to the contingency set
                contingencies.busses(index) = contingencies.busses(index) + i*(1 - network.failed_busses(index));
                network.failed_busses(index) = 1;
            end
        end
        
        % Generators
        [~, F_env_index] = min(abs(f_curves.gens{1,1}{:,1} - env_state(3, i))); % Determine index corresponding to current environmental state
    
        for j=1:sum(count(active_set(2,:), "gen"))
            index = str2double(active_set(1, j + sum(count(active_set(2,:), "branch")) + sum(count(active_set(2,:), "bus"))));
    
            r = rand; % Generate random number in [0,1]
            F_env = f_curves.gens{1, index}{1, 2}(F_env_index); % Extract failure probability w.r.t current environmental state
    
            if r < F_env % If component fails add it to the contingency set
                contingencies.gens(index) = contingencies.gens(index) + i*(1 - network.failed_gens(index));
                network.failed_gens(index) = 1;
            end
        end
    end
end