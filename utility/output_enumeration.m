% output_enumeration.m
%
% Creates the arrays defining the output enumeration used in the PSres
% model.
%
% Author: Aidan Gerkis
% Date: 10-04-2025

%% Define Enumerations
i_one = ["op_rel", "if_rel"]; % Enumerate indicator categories
i_two = ["load_served", "tl_dc"]; % Enumerate indicator types
m = ["F", "L", "E", "P", "Area_lin"]; % Enumerate metrics