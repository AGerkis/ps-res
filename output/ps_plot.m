% ps_plot.m
%
% Plots the resilience indicators computed by the power system resilience
% model.
%
% Indicator categories are enumerated as follows:
%   1: Operational Indicators
%   2: Infrastructural Indicators
%
% Indicators are enumerated as follows:
%   1: Load Served
%   2: Transmission lines disconnected
%
% Inputs:
%   ri: The resilience indicator output structure. [struct]
%   o: The array indicating the indicators used and the metrics computed
%      for those indicators. [N_print x 2 integer]
%
% Author: Aidan Gerkis
% Date: 19-03-2025

function ps_plot(ri, o)
    %% Define Enumeration Arrays
    i_one = ["op_rel", "if_rel"];
    i_two = ["load_served", "tl_dc"];
    m = ["F", "L", "E", "P", "Area_lin"];
    
    %% Define Output Strings
    ind_names = ["Load Served", "TL DC"]; % Indicator names
    ind_units = ["MW", "Transmission Lines"];

    %% Print Outputs
    inds = unique(o(:, 1)); % Get all indicators to plot

    % Loop and plot all indicators
    for i=1:length(inds)
        ind = inds(i); % Enumeration of indicator to plot

        % Get x and y axes
        y = ri.(i_one(ind)).(i_two(ind)).tot; % Indicator values
        x = ri.t.tot; % Time-steps
        
        % Make Plot
        f = figure('Name', ind_names(ind));
        plot(x, y, 'LineWidth', 2);
        fontsize(f, 18, 'points');
        title(sprintf("\\textbf{%s vs. Time}", ind_names(ind)), 'Interpreter', 'latex');
        ylabel(sprintf("%s [%s]", ind_names(ind), ind_units(ind)), 'Interpreter', 'latex');
        xlabel("Time [Hrs]", 'Interpreter', 'latex');
        xlim([0, max(x)])
        grid on;
        hold off
    end
end