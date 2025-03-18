% duration_metric.m
%
% Calculates the duration metric of a resiliency event as a time to a 
% certain percent of restoration as specified in equation (16) of [1].
%
% Author: Aidan Gerkis
%
% Date: 23-11-2023
%
% Inputs:
%   q: The percent of restoration desired. q should be in [0, 100]
%   data: The resiliency indicator data for which the duration metric is
%       being calculated. Containing resiliency indicator data in the first 
%       row and time in the second.
%
% Outputs:
%   d: The duration metric for the given data set.
%
% References:
%   [1]: Dobson, I. and S. Ekisheva (2023). "How Long is a Resilience Event 
%        in a Transmission System?: Metrics and Models Driven by Utility Data." 
%        IEEE Transactions on Power Systems: 1-12.

function d = duration_metric(q, data)
    % Extract the indices corresponding to unique entries
    [~, index_set] = unique(data(1, :), "stable");

    % Using the extracted index set build the array only containing the
    % restoration times
    steps = data(:, index_set);
    
    % Compute duration metric
    n = max([steps(1, 1), steps(1, end)]); % We want to find when the indicator takes a value corresponding to q% of its maximum

    if steps(1, 1) > steps(1, length(steps(1,:))) % If the indicator is decreasing then we need to inverse the quantile percent
        q = 100 - q;
    end

    u = min([1/3 + (n + 1/3)*q/100, n]); % Value corresponding to q%-th quantile of the indicator
    
    % Compute the index range so that u is in [steps(u_floor), steps(u_ceil)]    
    [M, index_test] = min(abs(steps(1,:) - u), [], "linear");
    
    if index_test == length(index_set) % Edge case, if the test index is the last index
        u_ceil = index_test;
        u_floor = index_test - 1;
    elseif index_test == 1 % Edge case, if the test index is the first index
        u_ceil = index_test + 1;
        u_floor = index_test;
    elseif (u - steps(index_test)) > 0 % If the test index is the upper bound
        u_ceil = index_test;
        u_floor = index_test - 1;
    else % Otherwise the test index must be the lower bound
        u_ceil = index_test + 1;
        u_floor = index_test;
    end

    D_ul = steps(2, u_floor); % D_n of lower step
    D_uu = steps(2, u_ceil); % D_n of upper step

    d = (1 - (u - floor(u)))*D_ul + (u - floor(u))*D_uu; % Interpret duration according to (16) in [1]
end