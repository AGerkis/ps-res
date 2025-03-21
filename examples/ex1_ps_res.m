% ex1_ps_res.m
%
% Simulates the resilience of a power system using the default system
% settings. Assigns contingencies and recovery times manually.
%
% Author: Aidan Gerkis
% Date: 19-03-2025

clear; clc; close all;

%% Load Model Parameters
% Define Inputs
failure_times = [12 12 0 4 22 19];
repair_times = [3 2 0 9 7 1];

% Specify Outputs
% Resilience indicators are enumerated in the first column:
%   1: Load Served
%   2: Transmission Lines Disconnected
% Metrics are enumerated in the second column:
%   1: Phi
%   2: Lambda
%   3: E
%   4: Pi
%   5: Area
output = [1 1; 1 2; 1 3; 1 4; 1 5;
          2 1; 2 2; 2 3; 2 4; 2 5];

% Load default parameters in a structure, 'P'
P = ps_resilience_params('default');

%% Assign network
network = initialize_network(case39); % Network for analysis

% Extract parameters
n_comp = [length(network.branch(:,1)); length(network.bus(:,1)); length(network.gen(:,1))]; % The number of each type of component

%% Specify event model
% Specify file and profile to use
fname_env_state = "wind_profiles.mat"; % File containing wind profiles for analysis
profile_name = "wind_20181220_20181220";
profiles = load(fname_env_state, 'output').output;

% Specify Event Parameters
% Load Contingency Profiles
env_state = profiles.(profile_name).max_intensity_profile';
active_set = [19, 22, 23, 24, 25, 26;
    "branch", "branch", "branch", "branch", "branch", "branch"];
N = length(active_set(1, :)); % Number of failed components
t_event_end = length(env_state);  % Length of event [Hours]
t_step = 1; % Time step [Hours]

 %% Specify recovery parameters
num_workers = [2, 2, 1]; % Number of work crews available to perform restoration work on each component type

%% Input Definition
% Define Contingencies
% Initialize as empty array
contingencies = struct("branches", zeros(1, n_comp(1)), "busses", zeros(1, n_comp(2)), "gens", zeros(1, n_comp(3)));

% Assign contingencies to active set (in this example the active set consists only of branches)
contingencies.branches(str2double(active_set(1, :))) = failure_times;

% Specify Input Mode
event_mode = 'Explicit';

% Define Recovery Times
% Initialize as empty array
recovery_times = struct("branches", zeros(1, n_comp(1)), "busses", zeros(1, n_comp(2)), "gens", zeros(1, n_comp(3)));

% Assign repair times to active set (in this example the active set consists only of branches)
recovery_times.branches(str2double(active_set(1, :))) = repair_times;

% Specify Input Mode
recovery_mode = 'Explicit';

%% Simulation Initialization
% Compile Event Parameters in Structure
recovery_params = struct("n_workers", num_workers, 'recovery_times', recovery_times, 'Mode', recovery_mode);
resilience_event = struct("contingencies", contingencies, "state", env_state, "active", active_set, "length", t_event_end, "step", t_step, 'Mode', event_mode); % Compile all event parameters

%% Run Model
[state, ri, rm, info] = psres(P.ac_cfm_settings, network, recovery_params, resilience_event, P.analysis_params, '', '');

%% Print & Plot Outputs
ps_print(rm, output);
ps_plot(ri, output);