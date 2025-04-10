% ps_print.m
% 
% Prints the resilience metrics computed by the power system resilience
% model to the console.
%
% Metrics are enumerated as follows:
%   1: Phi
%   2: Lambda
%   3: E
%   4: Pi
%   5: Area
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
%   rm: The resilience metric output structure. [struct]
%   o: The array indicating the indicators used and the metrics computed
%      for those indicators. [N_print x 2 integer]
%
% Author: Aidan Gerkis
% Date: 19-03-2025

function ps_print(rm, o)
    %% Define Enumeration Arrays
    output_enumeration;
    
    %% Define Output Strings
    m_chars = [char(934), char(923), "E", char(928), "A"]; % Contains the metrics in unicode format
    ind_names = ["Load Served", "Transmission Lines Disconnected"]; % Indicator names
    ind_units = ["MW", "Transmission Lines"];
    m_units = ["/Hr", "", "Hrs", "/Hr", " Hrs"];

    %% Print Outputs
    for i=1:size(o, 1) % Loop through all requested outputs
        % Print header on the first iteration or when the metric changes
        if (i == 1) || (o(i, 1) ~= o(i-1, 1))
            fprintf("\n============ %s ============\n", ind_names(o(i, 1)));
        end
        
        % Get metric value
        m_val = rm.(i_one(o(i, 1))).(i_two(o(i, 1))).(m(o(i, 2)));
        
        % Print metric
        fprintf("   %s: %2.2f [%s%s]\n", m_chars(o(i, 2)), m_val, ind_units(o(i, 1)), m_units(o(i, 2)));
    end
end