% ex1_ps_res.m
%
% Simulates the resilience of a power system using the default system
% settings. Generates contingencies automatically using the
% 'generate_contingency' function.
%
% Author: Aidan Gerkis
% Date: 19-03-2025

clear; clc; close all;

%% Load Model Parameters
% Specify file containing fragility curves
fname_f_curve = "failure_curve.mat"; % File containing failure curves

% Load recovery data into arrays
rec_data = assign_rec_data("BPA_data_trimmed_cutoff-2000_min", "", "");

% Load default parameters in a structure, 'P'
P = ps_resilience_params('default');

% Specify outputs
% The field 'P.Output' identifies what values are to be output. 
% Column 1 indicates the indicator (1 for load served, 2 for transmission
% lines disconnected)
% Column 2 indicates the metric (1 for Phi, 2 for Lambda, 3 for E, 4 for
% Pi, and 5 for Area).
P.type = 'metric'; % Saving metrics
P.Output = [1, 1; 1, 2; 1, 3; 1, 4; 1, 5;
                 2, 1; 2, 2; 2, 3; 2, 4; 2, 5];    

% Output Automation - These arrays are used to place the outputs in an array
indicators_one = ["op_rel", "if_rel"];
indicators_two = ["load_served", "tl_dc"];
metrics = ["F", "L", "E", "P", "Area_lin"];
indicators_time = ["init", "outage", "end"];

% Analysis Constants
analysis_params.q = 90; % The quantile considered as the end of the resiliency event

%% Extract Parameters from the default structure
% Network Settings
network = P.network; % Network definition [MATPOWER case format]
num_workers = P.num_workers; % The number of workers available to repair each component type
n_comp = [length(network.branch(:,1)); length(network.bus(:,1)); length(network.gen(:,1))]; % The number of each type of component

% Extreme Event Definition
coeff = P.event.c; % Scaling Factor for environmental state
env_state = coeff*(P.event.env_state); % Array of wind speeds vs time (Representing the extreme event model)
N = P.N; % Number of components in active set
active_set = P.event.active_set; % Set of components affected by the extreme event
t_event_end = length(env_state);  % Length of event [Hours]
t_step = 1; % Time step [Hours]

% Load fragility curve data
% Load failure curve data into array
f_curve_data = load(fname_f_curve, 'failure_curve'); % Assign the same x & y data for each component type
f_curve_data = {[f_curve_data.failure_curve.x; f_curve_data.failure_curve.y], ... 
    [f_curve_data.failure_curve.x; -1*ones(1, length(f_curve_data.failure_curve.x))],... % The negative one here simply assumes components never fail
    [f_curve_data.failure_curve.x; -1*ones(1, length(f_curve_data.failure_curve.x))]}; 

% Place failure curve data into structure
failure_curves = struct;
[failure_curves.branches, failure_curves.busses, failure_curves.gens] = assign_failure_curves(f_curve_data, n_comp);

%% Simulation Initialization
% Store the initial demand and generation at each bus and generator
network.demand_init = zeros(2, length(network.bus(:,1))); % Original network loading
network.gen_init = zeros(2, length(network.gen(:,1))); % Original network generation

for i=1:length(network.demand_init) % Extract initial demand
    network.demand_init(:,i) = [network.bus(i,3); network.bus(i,4)];
end

for i=1:length(network.gen_init) % Extract initial generation
    network.gen_init(:,i) = [network.gen(i,2); network.gen(i,3)];
end

% Assign flag array to network that indicates which components have failed
network.failed_branches = zeros(1, length(network.branch(:,1)));
network.failed_busses = zeros(1, length(network.bus(:,1)));
network.failed_gens = zeros(1, length(network.gen(:,1)));

% Compile Event Parameters in Structure
recovery_params = struct("n_workers", num_workers, 'branch_recovery_samples', rec_data.branch_recovery_samples, 'bus_recovery_samples', rec_data.bus_recovery_samples, 'gen_recovery_samples', rec_data.bus_recovery_samples, 'Mode', P.recovery_mode);
resilience_event = struct("failure_curves", failure_curves, "state", env_state, "active", active_set, "length", t_event_end, "step", t_step, 'Mode', P.event.mode); % Compile all event parameters

%% Run Model
[ri, rm, info] = ps_resilience(P.ac_cfm_settings, network, recovery_params, resilience_event, analysis_params, '', '');

%% Extract Outputs
Y = zeros(1, size(P.Output, 1)); % Save Metrics

% Extract all requested outputs
for i=1:size(P.Output, 1)
    switch P.type % Save output - dependent on specified type
        case "metric"
            Y(i) = rm.(indicators_one(P.Output(i, 1))).(indicators_two(P.Output(i, 1))).(metrics(P.Output(i, 2)));
        case "indicator"
            Y(i) = ri.(indicators_one(P.Output(i, 1))).(indicators_two(P.Output(i, 1))).(indicators_time(P.Output(i, 2)));
        otherwise
            disp("Unrecognized output type");
    end
end

%% Print Outputs