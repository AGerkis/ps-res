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
failure_times = [8, 4, 4, 0, 12, 13];
repair_times = [3 2 2 0 7 1];

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
% Define Contingencies
% Initialize as empty array
contingencies = struct("branches", zeros(1, n_comp(1)), "busses", zeros(1, n_comp(2)), "gens", zeros(1, n_comp(3)));

% Assign contingencies to active set (in this example the active set consists only of branches)
contingencies.branches(str2double(active_set(1, :))) = failure_times;

% Specify Input Mode
event.mode = 'Explicit';

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
resilience_event = struct("contingencies", contingencies, "state", env_state, "active", active_set, "length", t_event_end, "step", t_step, 'Mode', event.mode); % Compile all event parameters

%% Run Model
[state, ri, rm, info] = psres(P.ac_cfm_settings, network, recovery_params, resilience_event, P.analysis_params, '', '');

%% Print & Plot Outputs
ps_print(rm, P.Output);
ps_plot(ri, P.Output);