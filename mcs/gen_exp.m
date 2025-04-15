% gen_exp.m
%
% Sets up and runs a numerical experiment of a given UQ-Lab model using
% MATLAB's parallel computing capabilities. 
% 
% Analyzes the outputs to generate statistical resilience properties of the 
% system. Supports sampling of inputs specified as UQ-Lab and the 
% specification of a custom function for generating inputs.
%
% Provides support for replications.
%
% Inputs:
%   o: A MATLAB script or structure which configures the options for the experiment.
%      Should specify the number of simulations to run, the number of
%      replications, as well as the UQ-Lab formatted model and UQ-Lab
%      formatted input. [.m script OR Struct]
%      For structures, the fiels should be:
%      - n_s: The number of simulations to run. [Integer]
%      - n_r: The number of replications to run. [Integer]
%      - n_pool: The number of parallel pools to us. [Integer]
%      - n_in: The number of inputs. [Integer]
%      - n_out: The number of outputs. [Integer]
%      - model: The model to simulate. [UQ-Model]
%      - input: The model input [UQ-Input]
%      - plotting: A boolean indicating whether plots should be made. [Boolean]
%      - savdir: The directory under which to save the results. [String]
%      - outname: The output filename for the results. [String]
%   ed: A function to generate the inputs to the UQ-Lab model. Should
%       accept one input, N, the number of samples to generate and
%       return an n_s x n_in matrix of sample points. [function handle] (OPTIONAL)
%
% Outputs:
%   exp: A structure containing the experiment results. [struct]
%
% Author: Aidan Gerkis
% Date: 10-04-2025

function exp = gen_exp(o, ed)
    %% Initialize UQ-Lab
    evalc('uqlab'); % Quiet output

    %% Initialize Parameters
    % Set defaults
    gen_exp_defaults;
    
    % Get simulation options
    switch class(o)
        case 'string' % .m script was passed
            % Get user parameters
            run(o);
            
            % Get user created model
            model = uq_getModel;
        case 'struct' % Structure was passed
            % Extract fields
            opt_names = fieldnames(o);

            % Loop through all custom fields and set values
            for i=1:length(optnames)
                assignin('caller', opt_names{i}, o.(opt_names{i}));
            end
           
            % Select input
            uq_selectInput(input);
        otherwise
            error("Unrecognized options format!");
    end

    % Set Save Location for Data Outputs
    date = datetime("now");
    date = string(date, 'dd-MMM-yyyy HH:mm:ss');
    date = replace(date, "-", "");
    date = replace(date, " ", "_");
    date = replace(date, ":", "_");
    filename = savdir + date + "_" + fname_out; % Filename where data should be saved
    
    %% Initialize Experiment Simulations
    % Create pool
    myPool = parpool(n_pool);
    
    % Initialize an array to store sim time
    sim_times = zeros(n_s, n_r);
    
    % Initialize an array to store outputs
    exp_out = zeros(n_s, n_out, n_r);
    
    %% Generate Experiment Inputs
    time = datetime("now");
    fprintf("\n%s: Generating Experiment Inputs...\n", time);
    
    % Create function handle for generating inputs
    switch nargin
        case 1 % Use default MCS sampling
            get_inputs = @(N)uq_getSample(N, 'MC');
        case 2 % Use user-specified sampling
            get_inputs = @(N)ed(N);
    end
    
    % Sample inputs
    tic;
    X = get_inputs(n_s);
    t_exp = toc; % Save time to generate the experiments

    % Save inputs
    exp_in = X;
    
    time = datetime("now");
    fprintf("%s: Finished Generating Experiment Inputs.\n\n", time);
    
    %% Evaluate Model on Experiment
    errors = cell(n_r, n_s); % Save all errors which occurred

    % Compute replications
    for i=1:n_r
        time = datetime("now");
        fprintf("%s: Initializing Iterations for Replication %d...\n", time, i);
    
        % Initiate futures for current replication
        for j=n_s:-1:1
            f_rel(j) = parfeval(myPool, @eval_model_par, 1, X(j, :), model.Options);
        end
    
        time = datetime("now");
        fprintf("%s: Finished Initializing Iterations for Replication %d, Evaluating Experiment...\n", time, i);
    
         % Ensure that all parallels are deleted after exitting parallelization
        cancelFutures = onCleanup(@() cancel(f_rel)); 
        
        % Build a waitbar with a cancel button, using appdata to track
        % whether the cancel button has been pressed.
        exp_waitbar = waitbar(0, sprintf('Experiment Evaluation Progress - 0/%d', n_s), 'CreateCancelBtn', ...
                           @(src, event) setappdata(gcbf(), 'Cancelled', true));
        setappdata(exp_waitbar, 'Cancelled', false);

        % Variables for output processing
        err_num = 1; % Track position in errors cell array
        n_finished = 0; % Store number of finished model executions
        run_cancelled = false; % Save if the user has requested the simulation to be cancelled
        finished = false(1, n_s); % Store status of model executions
        
        % Get and save model evaluations
        while n_finished < n_s && ~run_cancelled
            % Get outputs
            try
                [finished_ind, Y_cur] = fetchNext(f_rel);
                
                % Process future if it exists
                if ~isempty(finished_ind)
                    finished(finished_ind) = true; % Update status of completed future

                    exp_out(finished_ind, :, i) = Y_cur; % Save results
                    sim_times(finished_ind, i) = seconds(f_rel(finished_ind).RunningDuration); % Save computation time

                    n_finished = n_finished + 1;
                end

                % Check to see if an attempt to cancel the simulation (via the
                % waitbar) was made
                if getappdata(exp_waitbar, 'Cancelled')
                    fprintf('Experiment cancelled due to user input.\n');
                    run_cancelled = true;
                end
                
                % Update waitbar
                frac_completed = n_finished/n_s;
                waitbar(frac_completed, exp_waitbar, sprintf('Experiment Evaluation Progress - %d/%d', n_finished, n_s));
            catch err
                errors{i, err_num} = err; % Save error
                err_num = err_num + 1; % Update position in array
                n_finished = n_finished + 1; % Update number of finished computations
            end
        end
        
        delete(exp_waitbar); % Close the waitbar

        % Print finishing message
        time = datetime("now");
        fprintf("%s: Finished Evaluation for Replication %d.\n\n", time, i);
    end

    %% Shut down pool
    cancel(f_rel); % Cancel any remaining futures
    delete(gcp('nocreate'));
    
    %% Process Outputs
    if ~run_cancelled
        % Compute mean and standard deviation of inputs
        in_means = zeros(1, n_in);
        in_vars = zeros(1, n_in);
    
        for i=1:n_in
            in_means(i) = mean(X(:, i));
            in_vars(i) = std(X(:, i));
        end
    
        % Compute mean and standard deviation of outputs over all replications
        out_means = zeros(1, n_out);
        out_vars = zeros(1, n_out);
    
        for i=1:n_out
            % Combine all of the values of the i-th output together
            [d1, ~, d2] = size(exp_out(:, i, :));
            out_cur = reshape(exp_out(:, i, :), [d1*d2, 1]);
    
            % Compute moments
            out_means(i) = mean(out_cur);
            out_vars(i) = std(out_cur);
        end
    
        if make_plots
            set_plotting_parameters(1, 1);
            
            % Create default names if not passed
            if ~exist("in_names", 'var') % For inputs
                in_names = strings(1, n_in);
        
                for i=1:n_in
                    in_names(i) = "Input " + num2str(i);
                end
            end
        
            if ~exist("out_names", 'var') % For outputs
                out_names = strings(1, n_out);
        
                for i=1:n_out
                    out_names(i) = "Output " + num2str(i);
                end
            end
        
            % Plot mean and standard deviation of inputs
            N_in = linspace(1, n_in, n_in);
        
            figure('Name', 'Moments of Input Variables');
            hold on;
            scatter(N_in, in_means, 'Marker', 'o');
            ylabel("$\mu$");
            yyaxis right;
            scatter(N_in, in_vars, 'Marker', 'x');
            ylabel("$\sigma$", 'Rotation', 270);
            xlim([0, n_in + 1]);
            title("\textbf{Moments of Input Variables}");
            xlabel("Input Variable");
            xticklabels(in_names);
            grid on;
            hold off;
        
            % Make histograms of inputs
            for i=1:n_in
                figure('Name', in_names(1) + " - Histogram");
                histogram(X(:, i), n_bin);
                title("\textbf{Frequency of " + in_names(1) + "}");
                xlabel(in_names(1));
                ylabel("Frequency")
                grid on;
            end
        
            % Plot mean and standard deviation of outputs
            N_out = linspace(1, n_out, n_out);
        
            figure('Name', 'Moments of Output Variables');
            hold on;
            scatter(N_out, out_means, 'Marker', 'o');
            ylabel("$\mu$");
            yyaxis right;
            scatter(N_out, out_vars, 'Marker', 'x');
            ylabel("$\sigma$", 'Rotation', 270);
            xlim([0, n_out + 1]);
            title("\textbf{Moments of Output Variables}");
            xlabel("Output Variable");
            xticklabels(out_names);
            grid on;
            hold off;
        
            % Make histograms of output values
            for i=1:n_out
                % Combine all of the values of the i-th output together
                [d1, ~, d2] = size(exp_out(:, i, :));
                out_cur = reshape(exp_out(:, i, :), [d1*d2, 1]);
        
                % Make plots
                figure('Name', out_names(1) + " - Histogram");
                histogram(out_cur, n_bin);
                title("\textbf{Frequency of " + out_names(1) + "}");
                xlabel(out_names(1));
                ylabel("Frequency")
                grid on;
            end
        end
        
        % Compute total sim_time
        tot_time = sum(sim_times, 'All');
    
        %% Save Data
        exp_out = squeeze(exp_out); % Remove any 1 dimensional dimensions
    
        save(filename, "exp_in", "exp_out", "sim_times", "tot_time", "in_means", "in_vars", "out_means", "out_vars", "errors");
    
        %% Compile outputs
        exp.in = exp_in;
        exp.out = exp_out;
        exp.t = tot_time;
        exp.t_exp = t_exp;
        exp.errors = errors;
    end
end