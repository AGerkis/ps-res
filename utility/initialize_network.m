% initialize_network.m
%
% Adds additional fields to the MATPOWER case format network needed for the
% computation of resilience indicators.
%
% Inputs:
%   net: The network to be modified. [MATPOWER case format]
%
% Outputs:
%   net: The modified network. [MATPOWER case format]
%
% Author: Aidan Gerkis
% Date: 21-03-2025
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
function net = initialize_network(net)
    % Store the initial demand and generation at each bus and generator
    net.demand_init = zeros(2, length(net.bus(:,1))); % Original network loading
    net.gen_init = zeros(2, length(net.gen(:,1))); % Original network generation
    
    for i=1:length(net.demand_init) % Extract initial demand
        net.demand_init(:,i) = [net.bus(i,3); net.bus(i,4)];
    end
    
    for i=1:length(net.gen_init) % Extract initial generation
        net.gen_init(:,i) = [net.gen(i,2); net.gen(i,3)];
    end
    
    % Assign flag array to network that indicates which components have failed
    net.failed_branches = zeros(1, length(net.branch(:,1)));
    net.failed_busses = zeros(1, length(net.bus(:,1)));
    net.failed_gens = zeros(1, length(net.gen(:,1)));
end