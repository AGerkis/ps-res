% check_isolated.m
%
% Checks the nodes connected to a given branch to see if they are isolated,
% and sets them to be non-isolated if they are. Sets generators to be PV
% nodes and sets all other node types to be PQ.
%
% Author: Aidan Gerkis
%
% Date: 27-11-2023
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
function network = check_isolated(network, branch_id)
    % Define MATPOWER constants
    define_constants;

    % Extract to and from node IDs
    to = network.branch(branch_id, T_BUS);
    from = network.branch(branch_id, F_BUS);
    
    % Check For Isolated Nodes
    if network.bus(to, BUS_TYPE) == 4 % If bus was marked as isolated change its type
        if ismember(to, network.gen(:, GEN_BUS)) % Set to PV if it is a generator node
            network.bus(to, BUS_TYPE) = PV;
        else % Set to PQ for any other type of node
            network.bus(to, BUS_TYPE) = PQ;
        end
    end

    if network.bus(from, BUS_TYPE) == 4 % If bus was marked as isolated change its type
        if ismember(from, network.gen(:, GEN_BUS)) % Set to PV if it is a generator node
            network.bus(from, BUS_TYPE) = PV;
        else % Set to PQ for any other type of node
            network.bus(from, BUS_TYPE) = PQ;
        end
    end
end