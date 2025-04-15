% random_sample.m
% 
% Uniformly generates random samples of a given dataset.
%
% Inputs:
%   data: The dataset to be sampled from. Each column should correspond to
%         one variable. If variables are vectors (with multiple rows of
%         data) then 
%   points: The number of samples to generate.
%
% Outputs:
%   samples: An array containing the generated samples. If variables are
%            vectors (with multiple rows of data) then the output is a
%            vector as well, with each column corresponding to one sample.
%
% Author: Aidan Gerkis
% Date: 14-12-2023
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

function samples = random_sample(data, points)
    % Parse inputs
    if isempty(data) % If data array is empty
        data = zeros(1, 100); % Create arbitrary length array of zeros
    end

    % Initialize Parameters
    n = length(data(1,:))';

    % Initialize Outputs
    %samples = zeros(length(data(:,1)), points);

    % Generate samples
    indices = randi(n, 1, points);
    samples = data(:, indices); 
end