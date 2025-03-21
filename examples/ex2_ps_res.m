% ex2_ps_res.m
%
% Simulates the resilience of a power system using the default system
% settings. Generates contingencies automatically using the
% 'generate_contingency' function.
%
% Author: Aidan Gerkis
% Date: 19-03-2025

clear; clc; close all;

%% Load Model Parameters
% Load default parameters in a structure, 'P'
P = ps_resilience_params('default');

%% Assign network
network = initialize_network(case39); % Network for analysis

% Extract parameters
n_comp = [length(P.network.branch(:,1)); length(P.network.bus(:,1)); length(P.network.gen(:,1))]; % The number of each type of component

%% Specify event model
% Specify file and profile to use
fname_env_state = "wind_profiles.mat"; % File containing wind profiles for analysis
profile_name = "wind_20181220_20181220";
load(fname_env_state, 'output');

% Specify Event Parameters
% Load Contingency Profiles
event.env_state = output.(profile_name).max_intensity_profile';
event.active_set = [19, 22, 23, 24, 25, 26;
    "branch", "branch", "branch", "branch", "branch", "branch"];
N = length(event.active_set(1, :)); % Number of failed components
t_event_end = length(env_state);  % Length of event [Hours]
t_step = 1; % Time step [Hours]

 %% Specify recovery parameters
num_workers = [2, 2, 1]; % Number of work crews available to perform restoration work on each component type

%% Input Definition
% Failure Times
% Specify file containing fragility curves
fname_f_curve = "frag_curve.mat"; % File containing failure curves

% Load failure curve data into array
f_curve_data = load(fname_f_curve, 'failure_curve'); % Assign the same x & y data for each component type
f_curve_data = {[f_curve_data.failure_curve.x; f_curve_data.failure_curve.y], ... 
    [f_curve_data.failure_curve.x; -1*ones(1, length(f_curve_data.failure_curve.x))],... % The negative one here simply assumes components never fail
    [f_curve_data.failure_curve.x; -1*ones(1, length(f_curve_data.failure_curve.x))]}; 

% Place failure curve data into structure
failure_curves = struct;
[failure_curves.branches, failure_curves.busses, failure_curves.gens] = assign_failure_curves(f_curve_data, n_comp);

% Specify Input Mode
event.mode = 'Implicit';

% Repair Times
% Specify file containing recovery data
fname_rec_data = "recovery_data";

% Load recovery data into arrays
rec_data = assign_rec_data(fname_rec_data, "", "");

% Specify Input Mode
recovery_mode = 'Implicit';

%% Simulation Initialization
% Compile Event Parameters in Structure
recovery_params = struct("n_workers", num_workers, 'branch_recovery_samples', rec_data.branch_recovery_samples, 'bus_recovery_samples', rec_data.bus_recovery_samples, 'gen_recovery_samples', rec_data.gen_recovery_samples, 'Mode', recovery_mode);
resilience_event = struct("failure_curves", failure_curves, "state", env_state, "active", active_set, "length", t_event_end, "step", t_step, 'Mode', event.mode); % Compile all event parameters

%% Run Model
[state, ri, rm, info] = psres(P.ac_cfm_settings, network, recovery_params, resilience_event, P.analysis_params, '', '');

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

%% Print & Plot Outputs
ps_print(rm, P.Output);
ps_plot(ri, P.Output);