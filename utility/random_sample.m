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

function samples = random_sample(data, points)
    % Initialize Parameters
    n = length(data(1,:))';

    % Initialize Outputs
    %samples = zeros(length(data(:,1)), points);

    % Generate samples
    indices = randi(n, 1, points);
    samples = data(:, indices); 
end