% ps_resilience_params.m
%
% Initialize resilience model parameters for the power system resilience 
% model.
%
% Inputs:
%   model: A string indicating the parameter set to initialize.
%
% Outputs:
%   P: A structure containing the specified parameters, compatible with 
%      uq_ps_resiliency_v2 & uq_ps_resiliency_v3. Does not include P.Output.
%
% Author: Aidan Gerkis
% Date: 19-02-2024

function P = ps_resilience_params(model)
    P = struct(); % Initialize output structure

    switch model
        case "default" % Default settings
            % File Inputs
            fname_env_state = "wind_profiles.mat"; % File containing wind profiles for analysis
            profile_name = "wind_20181220_20181220";

            P.network = case39; % Network for analysis

            % Load Default Settings
            ac_cfm_settings = get_default_settings(); % Load AC-CFM settings
            ac_cfm_settings.verbose = 0; % Turn off/on output. Switch to 1 for debugging.

            % Initialize Memory Settings
            ac_cfm_settings.keep_networks_after_cascade = 0; % Indicates whether to keep the final network structure for each contingency in a batch process

            % Set AC-CFM Solver Settings
            ac_cfm_settings.max_recursion_depth = 100; % Maximum number of recursive iterations allowed in cascading failure analysis

            % Set MATPOWER Solver Settings
            ac_cfm_settings.mpopt.opf.ac.solver = 'IPOPT'; % Use Interior Point Method

            % Protection Parameters
            ac_cfm_settings.uvls_per_step = 0.05; % Amount of load shed per step of UVLS. Default is 0.05. [p.u.]
            ac_cfm_settings.uvls_max_steps = 5; % Number of UVLS steps allowed. Default is 5. [unitless]
            ac_cfm_settings.dP_limit = 1; % Maximum imbalance between generation before UFLS is applied. Default is 0.15. [p.u.]
            ac_cfm_settings.P_overhead = 0.1; % Ratio of power lost to transmission line losses. Default is 0.1. [unitless]
            ac_cfm_settings.Q_tolerance = 0.1; % Ratio by which reactive power limits may be exceeded before O/UXL is applied. Default is 0.1. [unitless]

            P.ac_cfm_settings = ac_cfm_settings;

            % Event Parameters
            P.event = struct();

            % Load Contingency Profiles
            P.event.c = 0.8; % Scaling Factor for environmental state

            % Load Environmental State Variables
            load(fname_env_state, 'output');

            P.event.env_state = output.(profile_name).max_intensity_profile';
            P.event.active_set = [19, 22, 23, 24, 25, 26;
                "branch", "branch", "branch", "branch", "branch", "branch"];
            P.N = length(P.event.active_set(1, :)); % Number of failed components

            % Recovery Parameters - Assume same recovery time curve for each type of component
            P.num_workers = [2, 2, 1]; % Number of work crews available to perform restoration work on each component type
        case "default_v3" % Default settings
            % File Inputs
            fname_f_curve = "failure_curve.mat"; % File containing failure curves
            fname_env_state = "wind_profiles.mat"; % File containing wind profiles for analysis
            profile_name = "wind_20181220_20181220"; % Name of specific wind profile

            P.network = case39; % Network for analysis
            n_comp = [length(P.network.branch(:,1)); length(P.network.bus(:,1)); length(P.network.gen(:,1))]; % The number of each type of component

            % Load Default Settings
            ac_cfm_settings = get_default_settings(); % Load AC-CFM settings
            ac_cfm_settings.verbose = 0; % Turn off/on output. Switch to 1 for debugging.

            % Initialize Memory Settings
            ac_cfm_settings.keep_networks_after_cascade = 0; % Indicates whether to keep the final network structure for each contingency in a batch process

            % Set AC-CFM Solver Settings
            ac_cfm_settings.max_recursion_depth = 100; % Maximum number of recursive iterations allowed in cascading failure analysis

            % Set MATPOWER Solver Settings
            ac_cfm_settings.mpopt.opf.ac.solver = 'IPOPT'; % Use Interior Point Method

            % Protection Parameters
            ac_cfm_settings.uvls_per_step = 0.05; % Amount of load shed per step of UVLS. Default is 0.05. [p.u.]
            ac_cfm_settings.uvls_max_steps = 5; % Number of UVLS steps allowed. Default is 5. [unitless]
            ac_cfm_settings.dP_limit = 1; % Maximum imbalance between generation before UFLS is applied. Default is 0.15. [p.u.]
            ac_cfm_settings.P_overhead = 0.1; % Ratio of power lost to transmission line losses. Default is 0.1. [unitless]
            ac_cfm_settings.Q_tolerance = 0.1; % Ratio by which reactive power limits may be exceeded before O/UXL is applied. Default is 0.1. [unitless]

            P.ac_cfm_settings = ac_cfm_settings;

            % Event Parameters
            P.event = struct();

            % Load Contingency Profiles
            P.event.c = 0.8; % Scaling Factor for environmental state

            % Load Environmental State Variables & Failure curves
            load(fname_env_state, 'output');
            f_curve_data = load(fname_f_curve, 'failure_curve');
            f_curve_data = {[f_curve_data.failure_curve.x; f_curve_data.failure_curve.y], ...
                [f_curve_data.failure_curve.x; -1*ones(1, length(f_curve_data.failure_curve.x))],...
                [f_curve_data.failure_curve.x; -1*ones(1, length(f_curve_data.failure_curve.x))]};

            failure_curves = struct;
            [failure_curves.branches, failure_curves.busses, failure_curves.gens] = assign_failure_curves(f_curve_data, n_comp);

            % Assign event parameters
            P.event.env_state = output.(profile_name).max_intensity_profile';
            P.event.active_set = [19, 22, 23, 24, 25, 26;
                "branch", "branch", "branch", "branch", "branch", "branch"];
            P.event.failure_curves = failure_curves;

            % Recovery Parameters - Assume same recovery time curve for each type of component
            P.recovery_mode = 'Internal'; % Set recovery to be computed internally
            P.num_workers = [2, 2, 1]; % Number of work crews available to perform restoration work on each component type

            % Load Recovery Time Data
            % File names for recovery time samples, set to "" if no data is used
            fname_branch_recovery_file = "BPA_data_trimmed_cutoff-2000_min.mat";
            fname_bus_recovery_file = "";
            fname_gen_recovery_file = "";

            % Load data and populate arrays
            recovery_data = load(fname_branch_recovery_file).durations_trimmed';

            if ~isequal(fname_branch_recovery_file, "")
                data = load(fname_branch_recovery_file);
                P.branch_recovery_samples = recovery_data;
            else
                P.branch_recovery_samples = [];
            end

            if ~isequal(fname_bus_recovery_file, "")
                data = load(fname_bus_recovery_file);
                P.bus_recovery_samples = recovery_data;
            else
                P.bus_recovery_samples = [];
            end

            if ~isequal(fname_gen_recovery_file, "")
                data = load(fname_gen_recovery_file);
                P.gen_recovery_samples = recovery_data;
            else
                P.gen_recovery_samples = [];
            end

            % Assign generator parameters
            % Default asssumes G10 are random
            P.Generation = struct();

            P.Generation.wind1 = struct(); % G10 parameters
            P.Generation.wind1.ID = 10;
            P.Generation.wind1.Type = 'Deterministic';
            P.Generation.wind1.PG = NaN;
            P.Generation.wind1.QG = NaN;
            
            P.network.bus(39, 2) = 1; % Manual forcing bad, remove later

            P.Ng_p = 1; % Number of generators with random active power
            P.Ng_q = 1; % Number of generators with random reactive power

            % No random demand
            P.Demand = struct();

            P.Nd_p = 0; % Number of loads with random active power
            P.Nd_q = 0; % Number of load with random reactive power
        otherwise
            disp("Error: Invalid parameter type specified");
    end
end