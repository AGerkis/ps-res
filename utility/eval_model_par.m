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