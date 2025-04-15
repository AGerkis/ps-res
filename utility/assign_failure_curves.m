% assign_failure_curves.m
%
% Assigns a CDF representing the fragility curve to each component in the
% given set. Is capable of generating a variet of PDFs using different
% input specifications. Outputs the results as a cell array for each
% component type, with entries in the cell array containing the CDF and
% corresponding x values.
%
% Author: Aidan Gerkis
%
% Date: 13-11-2023
%
% Inputs:
%   branch_params: Statistical parameters for the branch components. In the
%                  form [a; b; distribution]. May be an
%                  array. Note that the distribution
%                  parameter is optional.
%   bus_params: Statistical parameters for the bus components. In the
%               form [mean; sigma; distribution]. May be an
%               array. Note that the distribution
%               parameter is optional.
%   gen_params: Statistical parameters for the generator components. In the
%               form [mean; sigma; distribution]. May be an
%               array. Note that the distribution
%               parameter is optional.
%   n_components: An array containing the number of each component.
%   distribution: The form of the PDF, all lower-case. May be an array
%                 containing the PDF type for each component. Optional. [String]
%   x_range: An array containing the minimum value of x and maximum value of x
%            for which the CDF should be plotted for each component type.
%            Input should be of the form [x_min_branch, x_max_branch;
%            x_min_bus, x_max_bus; x_min_gen, x_max_bus].
%
% Alternate Input Format:
%   arg1: A 1x3 cell array, where each cell contains a 2 x n array with x 
%         coordinates of failure curve on the first dimension and y coordinates 
%         of failure curve on the second dimension.
%   arg2: An array containing the number of each component.
%
% Outputs:
%   cdf_branch: An array containing the cdfs for all branches. In the form
%               [[x; cdf], ...].
%   cdf_bus: An array containing the cdfs for all busses. In the form
%            [[x; cdf], ...].
%   cdf_gen: An array containing the cdfs for all generators. In the form
%            [[x; cdf], ...].
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
function [cdf_branch, cdf_bus, cdf_gen] = assign_failure_curves(arg1, arg2, arg3, arg4, arg5, arg6)
    n = 100; % Number of points to evaluate CDF at
    
    % Process Input Parameters, Extracting Statistical Parameters
    % Describing CDFs
    switch nargin
        case 2 % x and y arrays corresponding to failure curves are given as inputs            
            n_branch = arg2(1);
            n_bus = arg2(2);
            n_gen = arg2(3);
            
            % Populate branch failure curves
            x = arg1{1}(1, :);
            y = arg1{1}(2, :);
            cdf_branch = cell(1, n_branch);

            for i=1:n_branch
                cdf_branch{i} = {x, y};
            end
            
            % Populate bus failure curves
            x = arg1{2}(1, :);
            y = arg1{2}(2, :);
            cdf_bus = cell(1, n_bus);

            for i=1:n_bus
                cdf_bus{i} = {x, y};
            end

            % Populate gen failure curves
            x = arg1{3}(1, :);
            y = arg1{3}(2, :);
            cdf_gen = cell(1, n_gen);

            for i=1:n_gen
                cdf_gen{i} = {x, y};
            end

            return;
        case 3 % Only mean and standard deviation provided. Assume Gaussian distribution.
            % Extract Mean and Standard Deviation
            a = arg1(1);
            b = arg1(2);
            
            % Extract amount of each component
            n_branch = arg2(1);
            n_bus = arg2(2);
            n_gen = arg2(3);
            
            % Extract range of x values
            x_l_branch = arg3(1, 1);
            x_u_branch = arg3(1, 2);
            x_l_bus = arg3(2, 1);
            x_u_bus = arg3(2, 2);
            x_l_gen = arg3(3, 1);
            x_u_gen = arg3(3, 2);

            % Assign generic statistical parameters
            branch_param = [a; b; "Normal"; x_l_branch; x_u_branch];
            bus_param = [a; b; "Normal"; x_l_bus; x_u_bus];
            gen_param = [a; b; "Normal"; x_l_gen; x_u_gen];
        case 4
            % Extract range of x values
            x_l_branch = arg4(1, 1);
            x_u_branch = arg4(1, 2);
            x_l_bus = arg4(2, 1);
            x_u_bus = arg4(2, 2);
            x_l_gen = arg4(3, 1);
            x_u_gen = arg4(3, 2);

            if isstring(arg3) % Generic mean and standard deviation provided with distribution type
                % Extract Mean and Standard Deviation
                a = arg1(1);
                b = arg1(2);
    
                % Extract amount of each component
                n_branch = arg2(1);
                n_bus = arg2(2);
                n_gen = arg2(3);
    
                % Extract distribution
                if length(arg3) == 1
                    dist_branch = arg3;
                    dist_bus = arg3;
                    dist_gen = arg3;
                else
                    dist_branch = arg3(1);
                    dist_bus = arg3(2);
                    dist_gen = arg3(3);
                end

                % Assign generic statistical parameters
                branch_param = [a; b; dist_branch];
                bus_param = [a; b; dist_bus];
                gen_param = [a; b; dist_gen];
            else % List of all parameters provided
                % Extract amount of each component
                n_branch = length(arg1);
                n_bus = length(arg2);
                n_gen = length(arg3);

                % Build parameter arrays from inputs
                if isstring(arg1(length(arg1),1)) % If distribution is provided in array return arguments
                    for i=1:length(arg1)
                        branch_param = [arg1(1, i); arg1(2, i); arg1(3, i)];
                    end

                    for i=1:length(arg2)
                        bus_param = [arg2(1, i); arg2(2, i); arg2(3, i)];
                    end

                    for i=1:length(arg3)
                        gen_param = [arg3(1, i); arg3(2, i); arg3(3, i)];
                    end
                else % If distribution is not provided insert distribution
                    for i=1:length(arg1)
                        branch_param = [arg1(1, i); arg1(2, i); "Normal"];
                    end
    
                    for i=1:length(arg2)
                        bus_param = [arg2(1, i); arg2(2, i); "Normal"];
                    end
    
                    for i=1:length(arg3)
                        gen_param = [arg3(1, i); arg3(2, i); "Normal"];
                    end
                end
            end
        case 5
            % Extract range of x values
            x_l_branch = arg5(1, 1);
            x_u_branch = arg5(1, 2);
            x_l_bus = arg5(2, 1);
            x_u_bus = arg5(2, 2);
            x_l_gen = arg5(3, 1);
            x_u_gen = arg5(3, 2);

            if ~isstring(arg4) % If distribution is not provided as an input
                % Extract Mean and Standard Deviation
                a_branch = arg1(1);
                b_branch = arg1(2);
    
                a_bus = arg2(1);
                b_bus = arg2(2);
    
                a_gen = arg3(1);
                b_gen = arg3(2);
    
                % Extract amount of each component
                n_branch = arg4(1);
                n_bus = arg4(2);
                n_gen = arg4(3);
    
                % Assign generic statistical parameters
                branch_param = [a_branch; b_branch; "Normal"];
                bus_param = [a_bus; b_bus; "Normal"];
                gen_param = [a_gen; b_gen; "Normal"];
            else % If distribution was provided as an input insert distribution into parameter array
                % Extract number of each component
                n_branch = length(arg1);
                n_bus = length(arg2);
                n_gen = length(arg3);

                % Extract distribution
                if length(arg4) == 1
                    dist_branch = arg4;
                    dist_bus = arg4;
                    dist_gen = arg4;
                else
                    dist_branch = arg4(1);
                    dist_bus = arg4(2);
                    dist_gen = arg4(3);
                end
                
                % Build parameter arrays
                for i=1:length(arg1)
                    branch_param = [arg1(1, i); arg1(2, i); dist_branch];
                end

                for i=1:length(arg2)
                    bus_param = [arg2(1, i); arg2(2, i); dist_bus];
                end

                for i=1:length(arg3)
                    gen_param = [arg3(1, i); arg3(2, i); dist_gen];
                end
            end
        case 6 % If parameters are provided for each type of component, and distribution is specified
            % Extract Mean and Standard Deviation
            a_branch = arg1(1);
            b_branch = arg1(2);
    
            a_bus = arg2(1);
            b_bus = arg2(2);
    
            a_gen = arg3(1);
            b_gen = arg3(2);
   
            % Extract amount of each component
            n_branch = arg4(1);
            n_bus = arg4(2);
            n_gen = arg4(3);

            % Extract distribution
            if length(arg5) == 1
                dist_branch = arg5;
                dist_bus = arg5;
                dist_gen = arg5;
            else
                dist_branch = arg5(1);
                dist_bus = arg5(2);
                dist_gen = arg5(3);
            end
            
            % Extract range of x values
            x_l_branch = arg6(1, 1);
            x_u_branch = arg6(1, 2);
            x_l_bus = arg6(2, 1);
            x_u_bus = arg6(2, 2);
            x_l_gen = arg6(3, 1);
            x_u_gen = arg6(3, 2);

            % Assign generic statistical parameters
            branch_param = [a_branch; b_branch; dist_branch];
            bus_param = [a_bus; b_bus; dist_bus];
            gen_param = [a_gen; b_gen; dist_gen];
    end
    
    % If length of parameter arrays is 1 then extend it
    if length(branch_param(1,:)) == 1
        for i=1:n_branch-1
            branch_param = [branch_param, branch_param(:, 1)];
        end
    end

    if length(bus_param(1,:)) == 1
        for i=1:n_bus-1
            bus_param = [bus_param, bus_param(:, 1)];
        end
    end

    if length(gen_param(1,:)) == 1
        for i=1:n_gen-1
            gen_param = [gen_param, gen_param(:, 1)];
        end
    end

    % Populate cell arrays with CDFs
    cdf_branch = cell(1, n_branch);
    cdf_bus = cell(1, n_bus);
    cdf_gen = cell(1, n_gen);

    x_branch = linspace(x_l_branch, x_u_branch, n);
    x_bus = linspace(x_l_bus, x_u_bus, n);
    x_gen = linspace(x_l_gen, x_u_gen, n);
    
    for i=1:n_branch
        cdf_branch{i} = {x_branch, cdf(branch_param(3, i), x_branch, str2double(branch_param(1, i)), str2double(branch_param(2, i)))};
    end

    for i=1:n_bus
        cdf_bus{i} = {x_bus, cdf(bus_param(3, i), x_bus, str2double(bus_param(1, i)), str2double(bus_param(2, i)))};
    end

    for i=1:n_gen
        cdf_gen{i} = {x_gen, cdf(gen_param(3, i), x_gen, str2double(gen_param(1, i)), str2double(gen_param(2, i)))};
    end

    return;
end