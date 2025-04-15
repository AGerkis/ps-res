% eval_model_par.m
%
% A wrapper function for evaluating UQ-Lab models in parallel environments.
%
% If n_r is specified then the mean and standard deviation are also
% returned.
%
% Inputs:
%   X: The input points on which to evaluate the model. [N x M]
%   o: The options for the model to evaluate OR the uq-model to evaluate. [struct]
%   n_r: The number of replications to create. [Integer] (OPTIONAL)
%
% Outputs:
%   Y: The model evaluations on X. [N x N_Out]
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
function varargout = eval_model_par(X, o, n_r)
    uqlab;

    % Recreate model from options if specified
    if isa(o, "struct")
        m = uq_createModel(o);
    else
        m = o;
    end

    % Evaluate model
    switch nargout
        case 1
            Y = uq_evalModel(m, X);
            varargout{1} = Y;
        case 3
            [Y, mu, sd] = uq_evalModel(m, X, n_r);
            varargout{1} = Y;
            varargout{2} = mu;
            varargout{3} = sd;
    end
end