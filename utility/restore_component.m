% restore_component.m
%
% Takes a component as an input and restores that component within the
% network. Updates all relevant component status variables.
%
% Author: Aidan Gerkis
%
% Date: 20-12-2023
%
% Inputs:
%   network: The network in which the component is being restored (in
%   MATPOWER case format).
%   comp: The component being restored, in the format [ID, type].
%   n_branch: The number of branches remaining to be restored
%   n_bus: The number of busses remaining to be restored
%   n_gen: The number of generators remaining to be restored
%
% Outputs:
%   network: The network, after restoration of the specified component.
%   n_branch: The number of branches remaining to be restored, after restoration of the specified component.
%   n_bus: The number of busses remaining to be restored, after restoration of the specified component.
%   n_gen: The number of generators remaining to be restored, after restoration of the specified component.

function [network, n_branch, n_bus, n_gen] = restore_component(network, comp, n_branch, n_bus, n_gen)
    % Initialize MATPOWER Constants
    define_constants;

    % Add component back to network & update recovery indicators
    if isequal(comp(2,1), "branch")
        network.branch(str2double(comp(1,1)), BR_STATUS) = 1; % Add branch back to network
        network.failed_branches(str2double(comp(1,1))) = 0; % Remove failed flag
        network = check_isolated(network, str2double(comp(1,1))); % Set connected node status to non-isolated
        n_branch = n_branch - 1; % Decrease number of branches remaining
    elseif isequal(comp(2,1), "gen")
        network.gen(str2double(comp(1, 1)), GEN_STATUS) = 1; % Add generator back to network
        network.failed_gens(str2double(comp(1, 1))) = 0; % Remove failed flag
        n_gen = n_gen - 1; % Decrease number of busses remaining
    elseif isequal(comp(2,1), "bus")
        network.failed_busses(str2double(comp(1,1))) = 0; % Remove failed flag
    
        if ismember(str2double(comp(1,1)), network.gen(:,1)) %&& network.bus(str2double(comp(1, 1)), BUS_TYPE) == 4 % If the bus is a generator bus
            network.bus(str2double(comp(1,1)), BUS_TYPE) = 2; % Set bus type to PV bus
        else % All other busses are PQ busses
            network.bus(str2double(comp(1,1)), BUS_TYPE) = 1;
        end
    
        n_bus = n_bus - 1; % Decrease number of busses remaining
    end
end