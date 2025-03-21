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