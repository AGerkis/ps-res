% gen_exp_defaults.m
%
% Set the default parameters for MCS of the PSres model.
%
% Author: Aidan Gerkis
% Date: 14-04-2025
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

% Simulation Parameters
n_s = 10000; % Number of input samples (therefore, evaluations of the model)
n_r = 1; % Number of replications for each sample (relevant for stochastic models)
n_pool = 1; % Number of parallel pools for parallel execution

% Model parameters (by default this simulates the IEEE 39-Bus's response to
% an extreme windstorm)
% Create model
Params = ps_resilience_params("39bus_exp"); % Get default parameters
Params.output = [1 1]; % Compute only Phi_LS metric
model_opts.mFile = 'uq_psres';
model_opts.Parameters = Params;
model = uq_createModel(model_opts); % Create Model

% Specify Input
load("example_input_39bus.mat");
input = uq_createInput(input.Options);

% Specify number of inptus and outputs
n_in = 12; % Number of inputs
n_out = 10; % Number of outputs

% Plotting Parameters
n_bin = 25; % The number of bins to use when plotting histograms
make_plots = true; % Whether or not to make validation plots

% Saving parameters (DO NOT SAVE BY DEFAULT)
savdir = ''; % Saving directory
fname_out = ''; % Default output name