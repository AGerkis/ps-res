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
        
        % Determine Start and End of Each Phase
        td_s = x(2);
        td_e = x(length(ri.t.cf) + 1);
        to_s = td_e;
        to_e = x(length(ri.t.cf) + 2); % Outage is always one time-step on x-axis
        tr_s = to_e;
        tr_e = ri.t.recovery(end);

        % Make Plot
        f = figure('Name', ind_names(ind));
        hold on;
        % Draw Boxes Corresponding to Stages
        fill([td_s; td_s; td_e; td_e], [min(y)-1000; max(y)+1000; max(y)+1000; min(y)-1000], [202,216,240]./255, 'LineStyle', 'none');
        fill([to_s; to_s; to_e; to_e], [min(y)-1000; max(y)+1000; max(y)+1000; min(y)-1000], [197,215,159]./255, 'LineStyle', 'none');
        fill([tr_s; tr_s; tr_e; tr_e], [min(y)-1000; max(y)+1000; max(y)+1000; min(y)-1000], [208,150,145]./255, 'LineStyle', 'none');
        % Plot resilience
        plot(x, y, 'k','LineWidth', 2);
        set(gca, 'Layer', 'top'); % Force x-axis to top layer
        fontsize(f, 18, 'points');
        title(sprintf("\\textbf{%s vs. Time}", ind_names(ind)), 'Interpreter', 'latex');
        ylabel(sprintf("%s [%s]", ind_names(ind), ind_units(ind)), 'Interpreter', 'latex');
        xlabel("Time [Hrs]", 'Interpreter', 'latex');
        xlim([0, max(x)]);
        ylim([min(y)-abs(min(y) + 1)*0.1, max(y)+abs(max(y))*0.1])
        legend("Disturbance", "Outage", "Restoration", "");
        grid on;
        hold off
    end
end