% ex3_ps_res_mcs.m
%
% An example showcasing how MCS may be performed using the PSres model.
% Uses UQ-Lab formatted random input variables
%
% Author: Aidan Gerkis
% Date: 10-04-2025

clear; close all; clc;
uqlab;

%% Specify Simulation Options
sim_opt = struct(); % Create empty structure

% Simulation Parameters
sim_opt.n_s = 1000; % Number of model evaluations to perform in MCS        
sim_opt.n_r = 1; % Number of replications (useful for stochastic models)
sim_opt.n_pool = 6; % Number of parallel pools to use (IMPORTANT: SHOULD BE LESS THAN NUMBER OF AVAILABLE CORES, RUN feature('numcores') to see this value)
sim_opt.plotting = 1; % Make plots visualizing MCS results

% Experiment Saving Parameters
sim_opt.savdir = "C:\Users\user\Desktop"; % <------------------- Set this to a convenient location!
sim_opt.outname = "psres_mcs_example"; % Output filename

% Model Parameters
sim_opt.n_in = 12; % Number of model inputs (2*Size of Active Set)
sim_opt.n_out = 10; % Computing all metrics for 2 indicators

% Specify Inputs
load("example_input_39bus.mat");
sim_opt.input = input;

% Specify Model
Params = ps_resilience_params("39bus_exp"); % Get default parameters
model_opts.mFile = 'uq_psres';
model_opts.Parameters = Params;

sim_opt.model = uq_createModel(model_opts); % Create Model

%% Perform MCS
% gen_exp with no other options runs MCS of the specified model, sampled
% according to the UQ-Lab input's random vector definition
exp = gen_exp(sim_opt); 