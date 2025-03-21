% ps_resilience_params.m
%
% Initialize resilience model parameters for the power system resilience 
% model.
%
% Inputs:
%   model: A string indicating the parameter set to initialize.
%
% Outputs:
%   P: A structure containing the parameters for the specified model.
%
% Author: Aidan Gerkis
% Date: 19-02-2024

function P = ps_resilience_params(model)
    P = struct(); % Initialize output structure

    switch model
        case "default" % Default settings
            % Specify default analysis settings
            P.analysis_params.q = 90;

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
        otherwise
            disp("Error: Invalid parameter type specified");
    end
end