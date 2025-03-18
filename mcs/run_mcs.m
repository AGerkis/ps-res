% uq_mcs_parallel.m
%
% Sets up and runs a Monte-Carlo Simulation of a given UQ-Lab model using
% MATLAB's parallel computing capabilities. Analyzes the outputs to
% generate statistical resilience properties of the system. Supports sampling
% of inputs specified as UQ-Lab and the specification of a custom function
% for generating inputs.
%
% Provides support for replications.
%
% Inputs:
%   o: A MATLAB script which configures the options for the resilience MCS.
%      Should specify the number of simulations to run, the number of
%      replications, as well as the UQ-Lab formatted model and UQ-Lab
%      formatted input. [.m script OR Struct]
%      For structures, the fiels should be:
%      - n_mcs: The number of simulations to run. [Integer]
%      - n_r: The number of replications to run. [Integer]
%      - n_pool: The number of parallel pools to us. [Integer]
%      - n_in: The number of MCS inputs. [Integer]
%      - n_out: The number of MCS outputs. [Integer]
%      - model: The model to simulate. [UQ-Model]
%      - input: The model input [UQ-Input]
%      - plotting: A boolean indicating whether plots should be made. [Boolean]
%      - savdir: The directory under which to save the results. [String]
%      - outname: The output filename for the results. [String]
%   gen_exp: A function to generate the inputs to the UQ-Lab model. Should
%            accept one input, N, the number of samples to generate and
%            return an n_mcs x n_in matrix of sample points. [function handle]
%
% Outputs:
%   mcs: A structure containing the results of the MCS. [struct]
%
% Author: Aidan Gerkis
% Date: 11-06-2024

function mcs = uq_mcs_parallel(o, gen_exp)
    evalc('uqlab'); % Quiet output

    %% Initialize Parameters
    % Set defaults
    n_bin = 25;
    n_r = 1;
    make_plots = true;
    
    % Get simulation options
    switch class(o)
        case 'string' % .m script was passed
            % Get user parameters
            run(o);
            
            % Get user created model
            model = uq_getModel;
        case 'struct' % Structure was passed
            % Extract fields
            n_mcs = o.n_mcs;
            n_r = o.n_r;
            n_pool = o.n_pool;
            n_in = o.n_in;
            n_out = o.n_out;
            model = o.model;
            input = o.input;
            make_plots = o.plotting;
            savdir = o.savdir;
            fname_out = o.outname;

            % Select input
            input = uq_createInput(input.Options);
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
    
    %% Initialize Monte Carlo Simulation
    % Create pool
    myPool = parpool(n_pool);
    
    % Initialize an array to store sim time
    sim_times = zeros(n_mcs, n_r);
    
    % Initialize an array to store outputs
    mcs_out = zeros(n_mcs, n_out, n_r);
    
    %% Generate Inputs to Monte Carlo Simulation
    time = datetime("now");
    fprintf("\n%s: Generating MCS Inputs...\n", time);
    
    % Create function handle for generating inputs
    switch nargin
        case 1
            get_inputs = @(N)uq_getSample(N, 'MC');
        case 2
            get_inputs = @(N)gen_exp(N);
    end
    
    % Sample inputs
    tic;
    X = get_inputs(n_mcs);
    t_exp = toc; % Save time to generate the experiments

    % Save inputs
    mcs_in = X;
    
    time = datetime("now");
    fprintf("%s: Finished Generating MCS Inputs.\n\n", time);
    
    %% Perform Monte Carlo Simulation
    errors = cell(n_r, n_mcs); % Save all errors which occurred

    % Compute replications
    for i=1:n_r
        time = datetime("now");
        fprintf("%s: Initializing MCS Iterations for Replication %d...\n", time, i);
    
        % Initiate futures for current replication
        for j=n_mcs:-1:1
            f_rel(j) = parfeval(myPool, @eval_model_par, 1, X(j, :), model.Options);
        end
    
        time = datetime("now");
        fprintf("%s: Finished Initializing MCS Iterations for Replication %d, Running MCS...\n", time, i);
    
         % Ensure that all parallels are deleted after exitting parallelization
        cancelFutures = onCleanup(@() cancel(f_rel)); 
        
        % Build a waitbar with a cancel button, using appdata to track
        % whether the cancel button has been pressed.
        mcs_waitbar = waitbar(0, sprintf('Metamodel Compuation Progress - 0/%d', n_mcs), 'CreateCancelBtn', ...
                           @(src, event) setappdata(gcbf(), 'Cancelled', true));
        setappdata(mcs_waitbar, 'Cancelled', false);

        % Variables for output processing
        err_num = 1; % Track position in errors cell array
        n_finished = 0; % Store number of finished model executions
        run_cancelled = false; % Save if the user has requested the simulation to be cancelled
        finished = false(1, n_mcs); % Store status of model executions
        
        % Get and save MCS outputs
        while n_finished < n_mcs && ~run_cancelled
            % Get outputs
            try
                [finished_ind, Y_cur] = fetchNext(f_rel);
                
                % Process future if it exists
                if ~isempty(finished_ind)
                    finished(finished_ind) = true; % Update status of completed future

                    mcs_out(finished_ind, :, i) = Y_cur; % Save results
                    sim_times(finished_ind, i) = seconds(f_rel(finished_ind).RunningDuration); % Save computation time

                    n_finished = n_finished + 1;
                end

                % Check to see if an attempt to cancel the simulation (via the
                % waitbar) was made
                if getappdata(mcs_waitbar, 'Cancelled')
                    fprintf('MCS cancelled due to user input.\n');
                    run_cancelled = true;
                end
                
                % Update waitbar
                frac_completed = n_finished/n_mcs;
                waitbar(frac_completed, mcs_waitbar, sprintf('MCS Progress - %d/%d', n_finished, n_mcs));
            catch err
                errors{i, err_num} = err; % Save error
                err_num = err_num + 1; % Update position in array
                n_finished = n_finished + 1; % Update number of finished computations
            end
        end
        
        delete(mcs_waitbar); % Close the waitbar

        % Print finishing message
        time = datetime("now");
        fprintf("%s: Finished MCS for Replication %d.\n\n", time, i);
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
            [d1, ~, d2] = size(mcs_out(:, i, :));
            out_cur = reshape(mcs_out(:, i, :), [d1*d2, 1]);
    
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
                [d1, ~, d2] = size(mcs_out(:, i, :));
                out_cur = reshape(mcs_out(:, i, :), [d1*d2, 1]);
        
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
        mcs_out = squeeze(mcs_out); % Remove any 1 dimensional dimensions
    
        save(filename, "mcs_in", "mcs_out", "sim_times", "tot_time", "in_means", "in_vars", "out_means", "out_vars", "errors");
    
        %% Compile outputs
        mcs.in = mcs_in;
        mcs.out = mcs_out;
        mcs.t = tot_time;
        mcs.t_exp = t_exp;
        mcs.errors = errors;
    end
end