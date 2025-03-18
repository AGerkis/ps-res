% power_system_resiliency_v3.m
% 
% For a weather based resiliency event the cascading failure of the power system is
% computed using the AC-CFM algorithm found in [1]. The failed system is
% then recovered using a basic probabilistic recovery method. Finally the
% FLEP resiliency metrics are computed based on the number of transmission
% lines failed & total amount of load served. 
%
% In this script contingencies are generated from system failure curves
% over a span of time, modelling a long weather event. At each timestep a
% set of failed components is generated, and AC-CFM is run on the resulting
% network. The algorithm is based on the work done in [2].
%
% The simulation is run with the specified parameters and the resulting
% resiliency indicators and metrics are output.
%
% Supports both deterministic and random load and generation models, where
% the random models are specified as a MATLAB probability distribution (pd)
% object.
%
% Author: Aidan Gerkis
%
% Date: 10-06-2024
%
% Inputs:
%   ac_cfm_settings: A structure containing the settings for the AC-CFM
%                    implementation.
%   network: The network which is being modelled, in the MATPOWER case
%            format.
%   recovery_params: A structure containing the number of work crews
%                    available and the sample data of recovery times, for 
%                    each component.
%   resilience_event: A structure containing parameters related to the
%                     resilience event, namely the state variable at each 
%                     time instant, the event length, and the time step.
%   analysis_params: An array containing parameters for use in the
%                    calculation of resiliency metrics.
%   generation: Parameters to use for generation. [struct] (OPTIONAL)
%                 .ID: The ID of the generator. [integer]
%                 .Type: 'Deterministic' OR 'Random', indicates the
%                        generation model type. [char]
%                 .Value: If 'Deterministic' - a single value OR a 1 x n_step
%                         double indicating the generation at each time step. [double]
%                         If 'Random' - a MATLAB probability distribution
%                         object. [pd]
%   load: Parameters to use for load. [struct] (OPTIONAL)
%                 .ID: The ID of the bus. [integer]
%                 .Type: 'Deterministic' OR 'Random', indicates the load
%                        model type. [char]
%                 .Value: If 'Deterministic' - a single value OR a 1 x n_step
%                         double indicating the load at each time step. [double]
%                         If 'Random' - a MATLAB probability distribution
%                         object. [pd]
%
% Outputs:
%   resilience_indicators: A structure containing all resiliency indicators
%                          evaluated by the resiliency model.
%   resilience_metrics: A structure containing all resilience metrics
%                       evaluated by the resilience model.
%   sim_info: A structure containing information about the simulation being
%             run. Mainly used for performance analysis.
%
% References:
%   [1]: Noebels, M., Preece, R., Panteli, M. "AC Cascading Failure Model 
%        for Resilience Analysis in Power Networks." IEEE Systems Journal (2020).
%
%   [2]: Panteli, M., et al. (2017). ”Metrics and Quantification of Operational and Infrastructure
%        Resilience in Power Systems." IEEE Transactions on Power Systems 32(6): 4732-4742

function [resilience_indicators, resilience_metrics, sim_info] = power_system_resiliency_v3(ac_cfm_settings, network, recovery_params, resilience_event, analysis_params, generation, load)
    rng('shuffle', 'twister'); % Ensure different results on each successive iteration
    define_constants; % Define MATPOWER constants

    %% Intialize Simulation Parameters
    % Extract parameters from inputs
    % Recovery parameters
    num_workers = recovery_params.n_workers;
    
    % Event Parameters
    env_state = resilience_event.state;
    t_event_end = resilience_event.length;
    
    % Analysis Parameters
    q = analysis_params.q;
    
    % Parse generation and load inputs
    if ~isempty(generation)
        gen_fields = fieldnames(generation);
    else
        gen_fields = [];
    end

    if ~isempty(load)
        load_fields = fieldnames(load);
    else
        load_fields = [];
    end
    
    % Extract network parameters
    n_bus = size(network.bus, 1);
    n_branch = size(network.branch, 1);
    n_gen = size(network.gen, 1);

    %% Model Resiliency Event
    % Initialize Arrays for Storing Resiliency Indicators
    if_rel = struct("tl_dc", [], "load_dc", [], "gen_dc", []);
    op_rel = struct("load_served", [], "gen_online", []);
    
    resilience_indicators = struct("if_rel", if_rel, "op_rel", op_rel);
    
    % Simulation Parameters
    contingency_set = struct('branches', [], 'busses', [], 'gens', []); % Store complete set of contingencies
    failed_system = network; % Initialize failed_system
    n_step = length(env_state);

    % Generate random generation & load parameters
    % Create arrays of default values, corresponding to entries currently
    % in the network case structure
    pd = repmat(network.bus(:, PD), [1, n_step]); % Active load
    qd = repmat(network.bus(:, QD), [1, n_step]); % Reactive load

    pg = repmat(network.gen(:, PG), [1, n_step]); % Active generation
    qg = repmat(network.gen(:, QG), [1, n_step]); % Reactive generation
    
    % Apply custom load parameters
    for i=1:length(load_fields)
        index = load.(load_fields{i}).ID; % Get current bus ID
        
        % Process deterministic and random loads & update default values
        switch load.(load_fields{i}).Type
            case 'Deterministic'
                rf_p = n_step/length(load.(load_fields{i}).PD); % Replication factor for active load
                rf_q = n_step/length(load.(load_fields{i}).QD); % Replication factor for reactive load
                
                % Replication factors must be either 1 or n_step, check this
                if ~((rf_p == 1 || rf_p == n_step) && (rf_q == 1 || rf_q == n_step))
                    error("Incorrect dimensions of deterministic load for bus " + num2str(index) + ".");
                end

                pd(index, :) = repmat(load.(load_fields{i}).PD, [1, rf_p]);
                qd(index, :) = repmat(load.(load_fields{i}).QD, [1, rf_q]);
            case 'Random'
                % Generate samples of the given PDF
                pd(index, :) = random(load.(load_fields{i}).PD, [1, n_step]);
                qd(index, :) = random(load.(load_fields{i}).QD, [1, n_step]);
        end
    end

    % Apply custom generation parameters
    for i=1:length(gen_fields)
        index = generation.(gen_fields{i}).ID; % Get current generator ID
        
        % Process deterministic and random generation & update default values
        switch generation.(gen_fields{i}).Type
            case 'Deterministic'
                rf_p = n_step/length(generation.(gen_fields{i}).PG); % Replication factor for active load
                rf_q = n_step/length(generation.(gen_fields{i}).QG); % Replication factor for reactive load
                
                % Replication factors must be either 1 or n_step, check this
                if ~((rf_p == 1 || rf_p == n_step) && (rf_q == 1 || rf_q == n_step))
                    error("Incorrect dimensions of deterministic generation for generator " + num2str(index) + ".");
                end

                pg(index, :) = repmat(generation.(gen_fields{i}).PG, [1, rf_p]);
                qg(index, :) = repmat(generation.(gen_fields{i}).QG, [1, rf_q]);
            case 'Random'
                % Generate samples of the given PDF
                pg(index, :) = random(generation.(gen_fields{i}).PG, [1, n_step]);
                qg(index, :) = random(generation.(gen_fields{i}).QG, [1, n_step]);
        end
    end
    
    % Generate contingencies
    contingencies = generate_contingency(network, resilience_event.failure_curves, resilience_event.state, resilience_event.active);
    
    % Generate recovery times for components
    if strcmp(recovery_params.Mode, 'Input') % Recovery time is passed as an input
        rec_time = struct("branches", recovery_params.branch_recovery_times, "busses", recovery_params.bus_recovery_times, "gens", recovery_params.gen_recovery_times);
    else % Recovery time is determined internally
        rec_time = struct("branches", random_sample(recovery_params.branch_recovery_samples, n_branch), "busses", random_sample(recovery_params.bus_recovery_samples, n_bus), "gens", random_sample(recovery_params.gen_recovery_samples, n_gen));
    end

    % Model resilience event
    for i=1:n_step % Loop for each time step in [0, t_event_end]
        % Determine contingencies occurring at time t(n_step)
        failed_set = struct('branches', [], 'busses', [], 'gens', []);
        failed_set.branches = find(contingencies.branches == i);
        failed_set.busses = find(contingencies.busses == i);
        failed_set.gens = find(contingencies.gens == i);
        
        failed_system.failed_branches(failed_set.branches) = 1;
        failed_system.failed_busses(failed_set.busses) = 1;
        failed_system.failed_gens(failed_set.gens) = 1;
        
        % Assign power demand and generation
        failed_system.bus(:, [PD, QD]) = [pd(:, i), qd(:, i)];
        failed_system.gen(:, [PG, QG]) = [pg(:, i), qg(:, i)];

        % Run AC-CFM to Compute Cascading Failure
        failed_system = accfm(failed_system, failed_set, ac_cfm_settings);

        % Update system status with components disconnected by AC-CFM
        for j=1:length(failed_system.branch(:,1))
            failed_system.failed_branches(j) = failed_system.failed_branches(j) | ~failed_system.branch(j,11);
        end
    
        for j=1:length(failed_system.bus(:,1))
            failed_system.failed_busses(j) = failed_system.failed_busses(j) | (failed_system.bus(j,2) == 4);
        end
    
        for j=1:length(failed_system.gen(:,1))
            failed_system.failed_gens(j) = failed_system.failed_gens(j) | ~failed_system.gen(j,8);
        end
        
        % Extract resiliency indicators at current timestep
        % Note: Assumes that all cascading failures occur simultaneously with
        % the initial contingency
        % Infrastructure Indicators
        resilience_indicators.if_rel.tl_dc.cf(i) = sum(failed_system.failed_branches); % # of Transmission Lines Tripped [unitless]
        resilience_indicators.if_rel.load_dc.cf(i) = sum(failed_system.failed_busses); % # of Loads Tripped [unitless]
        resilience_indicators.if_rel.gen_dc.cf(i) = sum(failed_system.failed_gens); % # of Generators Tripped [unitless]
        % Operational Indicators
        resilience_indicators.op_rel.load_served.cf(i) = sum(failed_system.bus(:,3)); % Real power served [MW]
        resilience_indicators.op_rel.gen_online.cf(i) = sum((failed_system.gen(:,9))'.*(1-failed_system.failed_gens)); % Percentage of total generation not tripped [MW]
    
        % Update global contingency set
        contingency_set.branches = [contingency_set.branches, failed_set.branches];
        contingency_set.busses = [contingency_set.busses, failed_set.busses];
        contingency_set.gens = [contingency_set.gens, failed_set.gens];
    end

    %% Process AC-CFM Output
    % Store the final demand and generation after CF at each bus and generator
    failed_system.demand_final = zeros(2, length(failed_system.bus(:,1))); % Final network loading
    failed_system.gen_final = zeros(2, length(failed_system.gen(:,1))); % Final network generation
    
    for i=1:length(failed_system.demand_final) % Extract final demand
        failed_system.demand_final(:,i) = [failed_system.bus(i,3); failed_system.bus(i,4)];
    end
    
    for i=1:length(failed_system.gen_final) % Extract final generation
        failed_system.gen_final(:,i) = [failed_system.gen(i,2); failed_system.gen(i,3)];
    end
    
    % Compute delta between initial demand/generation and final demand/generation
    failed_system.demand_delta = failed_system.demand_init - failed_system.demand_final;
    failed_system.gen_delta = failed_system.gen_init - failed_system.gen_final;
    
    % Compile list of all damaged elements (i.e. failed due to extreme
    % weather event)
    n_dmg = [length(contingency_set.branches), length(contingency_set.busses), length(contingency_set.gens)];

    damaged_comp = [contingency_set.branches, contingency_set.busses, contingency_set.gens;
                    repmat("branch", 1, n_dmg(1)), repmat("bus", 1, n_dmg(2)), repmat("gen", 1, n_dmg(3))];

    % Compile list of all disconnected elements (disconnected by protection
    % mechanisms during cascading failure
    disconnected_branch = strings(2, sum(failed_system.failed_branches) - n_dmg(1));
    disconnected_bus = strings(2, sum(failed_system.failed_busses) - n_dmg(2));
    disconnected_gen = strings(2, sum(failed_system.failed_gens) - n_dmg(3));
    
    % Initialize failed element arrays with contingency sets
    k = 1; % Index tracking array
    for j=1:length(failed_system.failed_branches) % Check all branches for failure
        if failed_system.failed_branches(j) == 1 && ~ismember(j, str2double(damaged_comp(1,1:n_dmg(1)))) % If branch failed add its ID to the list of failed branches
            disconnected_branch(:, k) = [failed_system.branch_id(j); "branch"];
            k = k +1;
        end
    end
    
    k = 1; % Index tracking array
    for j=1:length(failed_system.failed_busses) % Check all busses for failure
        if failed_system.failed_busses(j) == 1 && ~ismember(j, str2double(damaged_comp(1,(n_dmg(1) + 1):(n_dmg(1) + n_dmg(2))))) % If bus failed add its ID to the list of failed bus
            disconnected_bus(:, k) = [failed_system.bus_id(j); "bus"];
            k = k +1;    
        end
    end
    
    k = 1; % Index tracking array
    for j=1:length(failed_system.failed_gens) % Check all generators for failure
        if failed_system.failed_gens(j) == 1 && ~ismember(j, str2double(damaged_comp(1,(n_dmg(2) + 1):(n_dmg(2) + n_dmg(3))))) % If generator failed add its ID to the list of failed generators
            disconnected_gen(:, k) = [failed_system.gen_id(j); "gen"];
            k = k + 1;
        end
    end
    
    disconnected_comp = [disconnected_branch, disconnected_bus, disconnected_gen]; % Concatenate results into single array
    n_dc = [length(disconnected_branch(1,:)), length(disconnected_bus(1,:)), length(disconnected_gen(1,:))]; % Store number of each type of failed component for indexing purposes
    
    %% Compute Length of Outage (before recovery begins)
    t_outage = 1; % Outage time, before restoration begins [hours]
    
    %% Compute Recovery
    try % Catch that damn outstanding bug
        recovered_system = ps_recovery(failed_system, damaged_comp, n_dmg, disconnected_comp, n_dc, rec_time, num_workers, ac_cfm_settings.mpopt);
    catch err
        err_name = string(datetime('now')) + " - Error State";
        save(err_name, "err", "failed_system", "damaged_comp", "n_dmg", "disconnected_comp", "n_dc", "rec_time", "num_workers", "ac_cfm_settings.mpopt");
    end

    %% Compile Data
    ri = resilience_indicators; % Define short hand
    
    % Initialize time array [hours]
    ri.t.init = 0; % Start Time
    ri.t.cf = linspace(0, t_event_end, n_step) + 10; % Time during cascading failure
    ri.t.recovery_0 = ri.t.cf(length(ri.t.cf)) + t_outage; % Set time for start of recovery
    ri.t.recovery = ri.t.recovery_0 + recovered_system.recovery_time(1:recovered_system.iterations); % Time during which recovery occurred
    ri.t.end = ri.t.recovery(length(ri.t.recovery)) + 20; % Time for plotting after recovery ends
    
    ri.t.tot = [ri.t.init, ri.t.cf, ri.t.recovery_0, ri.t.recovery, ri.t.end]; % Compile all times
    
    % Compile infrastructure data
    % Transmission Lines Outaged
    ri.if_rel.n_tl_dc = n_dc(1);
    ri.if_rel.n_tl_dmg = n_dmg(1);
    ri.if_rel.tl_dc.init = 0; % Start with all lines functioning
    ri.if_rel.tl_dc.outage = ri.if_rel.tl_dc.cf(length(ri.if_rel.tl_dc.cf)); % No change in # of tripped lines while outage is maintained
    ri.if_rel.tl_dc.recovery_0 = ri.if_rel.tl_dc.outage; % No change in # of tripped lines at start of recovery
    ri.if_rel.tl_dc.recovery = recovered_system.if_rel.tl_outaged_count(1:recovered_system.iterations); % # of tripped lines while recovery process is ongoing
    ri.if_rel.tl_dc.end = ri.if_rel.tl_dc.recovery(length(ri.if_rel.tl_dc.recovery)); % Value at end of simulation
    
    ri.if_rel.tl_dc.tot = [ri.if_rel.tl_dc.init, ri.if_rel.tl_dc.cf, ri.if_rel.tl_dc.outage, ri.if_rel.tl_dc.recovery, ri.if_rel.tl_dc.end]; % Compile all arrays
    
    outage_data = [ri.if_rel.tl_dc.cf(); ri.t.cf]; % Extract only time steps where status is degraded during cascading failure
    [~, indices] = unique(outage_data(1, :), "stable");
    outage_data = outage_data(:, indices);
    ri.if_rel.tl_dc.t_ee = outage_data(2, end); % End of cascading failure event (from perspective of this resiliency indicator)
    
    restore_data = [ri.if_rel.tl_dc.recovery; ri.t.recovery]; % Extract only time steps where status is improved during recovery
    [~, indices] = unique(restore_data(1, :), "stable");
    restore_data = restore_data(:, indices);

    if length(restore_data(1, :)) >= 2
        ri.if_rel.tl_dc.t_r = restore_data(2, 2); % Start of recovery for this resiliency indicator
        ri.if_rel.tl_dc.t_re = duration_metric(q, [ri.if_rel.tl_dc.recovery; ri.t.recovery]); %+ ri.t.recovery_0; % End of recovery
    else
        ri.if_rel.tl_dc.t_r =ri.t.recovery(1);
        ri.if_rel.tl_dc.t_re =ri.t.recovery(end);
    end

    % Generators Outaged
    ri.if_rel.n_gen_dc = n_dc(3);
    ri.if_rel.n_gen_dmg = n_dmg(3);
    ri.if_rel.gen_dc.init = 0; % Start with all lines functioning
    ri.if_rel.gen_dc.outage = ri.if_rel.gen_dc.cf(length(ri.if_rel.gen_dc.cf)); % No change in # of generators while outage is maintained
    ri.if_rel.gen_dc.recovery_0 = ri.if_rel.gen_dc.outage; % No change in # of generators at start of recovery
    ri.if_rel.gen_dc.recovery = recovered_system.if_rel.gen_outaged_count(1:recovered_system.iterations); % # of generators while recovery process is ongoing
    ri.if_rel.gen_dc.end = ri.if_rel.gen_dc.recovery(length(ri.if_rel.gen_dc.recovery)); % Value at end of simulation
    
    ri.if_rel.gen_dc.tot = [ri.if_rel.gen_dc.init, ri.if_rel.gen_dc.cf, ri.if_rel.gen_dc.outage, ri.if_rel.gen_dc.recovery, ri.if_rel.gen_dc.end]; % Compile all arrays
    
    outage_data = [ri.if_rel.gen_dc.cf(); ri.t.cf]; % Extract only time steps where status is degraded during cascading failure
    [~, indices] = unique(outage_data(1, :), "stable");
    outage_data = outage_data(:, indices);
    ri.if_rel.gen_dc.t_ee = outage_data(2, end); % End of cascading failure event (from perspective of this resiliency indicator)
    
    restore_data = [ri.if_rel.gen_dc.recovery; ri.t.recovery]; % Extract only time steps where status is improved during recovery
    [~, indices] = unique(restore_data(1, :), "stable");
    restore_data = restore_data(:, indices);
    
    if length(restore_data(1, :)) >= 2
        ri.if_rel.gen_dc.t_r = restore_data(2, 2); % Start of recovery for this resiliency indicator
        ri.if_rel.gen_dc.t_re = duration_metric(q, [ri.if_rel.gen_dc.recovery; ri.t.recovery]); % + ri.t.recovery_0; % End of recovery
    else
        ri.if_rel.gen_dc.t_r =ri.t.recovery(1);
        ri.if_rel.gen_dc.t_re =ri.t.recovery(end);
    end
    
    % Loads Disconnected
    ri.if_rel.n_load_dc = n_dc(2);
    ri.if_rel.n_load_dmg = n_dmg(2);
    ri.if_rel.load_dc.init = 0; % Start with all lines functioning
    ri.if_rel.load_dc.outage = ri.if_rel.load_dc.cf(length(ri.if_rel.load_dc.cf)); % No change in # of tripped lines while outage is maintained
    ri.if_rel.load_dc.recovery_0 = ri.if_rel.load_dc.outage; % No change in # of tripped lines at start of recovery
    ri.if_rel.load_dc.recovery = recovered_system.if_rel.loads_disconnected_count(1:recovered_system.iterations); % # of tripped lines while recovery process is ongoing
    ri.if_rel.load_dc.end = ri.if_rel.load_dc.recovery(length(ri.if_rel.load_dc.recovery)); % Value at end of simulation
    
    ri.if_rel.load_dc.tot = [ri.if_rel.load_dc.init, ri.if_rel.load_dc.cf, ri.if_rel.load_dc.outage, ri.if_rel.load_dc.recovery, ri.if_rel.load_dc.end]; % Compile all arrays
    
    outage_data = [ri.if_rel.load_dc.cf(); ri.t.cf]; % Extract only time steps where status is degraded during cascading failure
    [~, indices] = unique(outage_data(1, :), "stable");
    outage_data = outage_data(:, indices);
    ri.if_rel.load_dc.t_ee = outage_data(2, end); % End of cascading failure event (from perspective of this resiliency indicator)
    
    restore_data = [ri.if_rel.load_dc.recovery; ri.t.recovery]; % Extract only time steps where status is improved during recovery
    [~, indices] = unique(restore_data(1, :), "stable");
    restore_data = restore_data(:, indices);

    if length(restore_data(1, :)) >= 2
        ri.if_rel.load_dc.t_r = restore_data(2, 2); % Start of recovery for this resiliency indicator
        ri.if_rel.load_dc.t_re = duration_metric(q, [ri.if_rel.load_dc.recovery; ri.t.recovery]); % + ri.t.recovery_0; % End of recovery
    else
        ri.if_rel.load_dc.t_r =ri.t.recovery(1);
        ri.if_rel.load_dc.t_re =ri.t.recovery(end);
    end
    
    % Compile operational data
    % Total load served
    ri.op_rel.load_served.init = sum(network.demand_init(1,:)); % Initial load of system
    ri.op_rel.load_served.outage = ri.op_rel.load_served.cf(length(ri.op_rel.load_served.cf)); % Load doesn't change during outage
    ri.op_rel.load_served.recovery_0 = ri.op_rel.load_served.outage; % Load doesn't change at initation of recovery
    ri.op_rel.load_served.recovery = recovered_system.op_rel.total_p_load(1:recovered_system.iterations); % Amount of load restored while recovery process is ongoing
    ri.op_rel.load_served.end = ri.op_rel.load_served.recovery(length(ri.op_rel.load_served.recovery)); % Value at end of simulation
    
    ri.op_rel.load_served.tot = [ri.op_rel.load_served.init, ri.op_rel.load_served.cf, ri.op_rel.load_served.outage, ri.op_rel.load_served.recovery, ri.op_rel.load_served.end]; % Compile all arrays
    
    outage_data = [ri.op_rel.load_served.cf(); ri.t.cf]; % Extract only time steps where status is degraded during cascading failure
    [~, indices] = unique(outage_data(1, :), "stable");
    outage_data = outage_data(:, indices);
    ri.op_rel.load_served.t_ee = outage_data(2, end); % End of cascading failure event (from perspective of this resiliency indicator)
    
    restore_data = [ri.op_rel.load_served.recovery; ri.t.recovery]; % Extract only time steps where status is improved during recovery
    [~, indices] = unique(restore_data(1, :), "stable");
    restore_data = restore_data(:, indices);

    if length(restore_data(1, :)) >= 2
        ri.op_rel.load_served.t_r = restore_data(2, 2); % Start of recovery for this resiliency indicator
        ri.op_rel.load_served.t_re = duration_metric(q, [ri.op_rel.load_served.recovery; ri.t.recovery]); % + ri.t.recovery_0; % End of recovery
    else
        ri.op_rel.load_served.t_r =ri.t.recovery(1);
        ri.op_rel.load_served.t_re =ri.t.recovery(end);
    end

    % Percent of Total Generation Capacity Online
    ri.op_rel.gen_online.init = sum(network.gen(:,9)); % Initial total online generation of the system, assuming all generators are online
    ri.op_rel.gen_online.outage = ri.op_rel.gen_online.cf(length(ri.op_rel.gen_online.cf)); % Generation doesn't change during outage
    ri.op_rel.gen_online.recovery_0 = ri.op_rel.gen_online.outage; % Generation doesn't change at initation of recovery
    ri.op_rel.gen_online.recovery = recovered_system.op_rel.p_cap(1:recovered_system.iterations); % Amount of generation restored while recovery process is ongoing
    ri.op_rel.gen_online.end = ri.op_rel.gen_online.recovery(length(ri.op_rel.gen_online.recovery)); % Value at end of simulation
    
    ri.op_rel.gen_online.tot = 100*[ri.op_rel.gen_online.init, ri.op_rel.gen_online.cf, ri.op_rel.gen_online.outage, ri.op_rel.gen_online.recovery, ri.op_rel.gen_online.end]./ri.op_rel.gen_online.init; % Compile all arrays
    
    outage_data = [ri.op_rel.gen_online.cf(); ri.t.cf]; % Extract only time steps where status is degraded during cascading failure
    [~, indices] = unique(outage_data(1, :), "stable");
    outage_data = outage_data(:, indices);
    ri.op_rel.gen_online.t_ee = outage_data(2, end); % End of cascading failure event (from perspective of this resiliency indicator)
    
    restore_data = [ri.op_rel.gen_online.recovery; ri.t.recovery]; % Extract only time steps where status is improved during recovery
    [~, indices] = unique(restore_data(1, :), "stable");
    restore_data = restore_data(:, indices);
    
    if length(restore_data(1, :)) >= 2
        ri.op_rel.gen_online.t_r = restore_data(2, 2); % Start of recovery for this resiliency indicator
        ri.op_rel.gen_online.t_re = duration_metric(q, [ri.op_rel.gen_online.recovery; ri.t.recovery]); % + ri.t.recovery_0; % End of recovery
    else
        ri.op_rel.gen_online.t_r =ri.t.recovery(1);
        ri.op_rel.gen_online.t_re =ri.t.recovery(end);
    end
    
    %% Compute FLEP Resiliency Metrics
    % Initialize data storage
    resiliency_metrics = struct("op_rel", [], "if_rel", []);
    resiliency_metrics.if_rel = struct("tl_dc", [], "load_dc", [], "gen_dc", []);
    resiliency_metrics.op_rel = struct("load_served", [], "gen_online", []);
    rm = resiliency_metrics; % Define short hand
    
    rm.t.t_event = ri.t.cf(length(ri.t.cf)) - ri.t.cf(1); % Time from start of disturbance to end of cascade [hours]
    rm.t.t_restore = ri.t.recovery(length(ri.t.recovery)) - ri.t.recovery_0; % Length of recovery process [hours]
    
    % Transmission Lines Outaged
    rm.if_rel.tl_dc.L = -ri.if_rel.tl_dc.outage + ri.if_rel.tl_dc.init; % Total amount of degradation [# of Transmission Lines]
    rm.if_rel.tl_dc.F = -rm.if_rel.tl_dc.L/(ri.if_rel.tl_dc.t_ee - ri.t.cf(1)); % Rate of change of degradation [# of Transmission Lines/hr]
    rm.if_rel.tl_dc.E = ri.if_rel.tl_dc.t_r - ri.if_rel.tl_dc.t_ee; % Length of disturbed state [hours]
    rm.if_rel.tl_dc.P = rm.if_rel.tl_dc.L/(ri.if_rel.tl_dc.t_re - ri.if_rel.tl_dc.t_r); % Rate of change of recovery [# of Transmission Lines/hr]
    rm.if_rel.tl_dc.Area_lin = abs(rm.if_rel.tl_dc.L*(ri.if_rel.tl_dc.t_ee - ri.t.cf(1))/2 + rm.if_rel.tl_dc.L*rm.if_rel.tl_dc.E + rm.if_rel.tl_dc.L*(ri.if_rel.tl_dc.t_re - ri.if_rel.tl_dc.t_r)/2); % Total effect of outage [# of Transmission Lines * hours]
    
    if ri.if_rel.tl_dc.t_ee == ri.t.cf(1) % Check for & handle division by 0
        rm.if_rel.tl_dc.F = 0;
    end

    if ri.if_rel.tl_dc.t_re == ri.if_rel.tl_dc.t_r
        rm.if_rel.tl_dc.P = 0;
    end

    % Load Disconnected
    rm.if_rel.load_dc.L = -ri.if_rel.load_dc.outage + ri.if_rel.load_dc.init; % Total amount of loads connected [# of Loads]
    rm.if_rel.load_dc.F = -rm.if_rel.load_dc.L/(ri.if_rel.load_dc.t_ee - ri.t.cf(1)); % Rate of change of degradation [# of Loads/hr]
    rm.if_rel.load_dc.E = ri.if_rel.load_dc.t_r - ri.if_rel.load_dc.t_ee; % Length of disturbed state [hours]
    rm.if_rel.load_dc.P = rm.if_rel.load_dc.L/(ri.if_rel.load_dc.t_re - ri.if_rel.load_dc.t_r); % Rate of change of recovery [# of Loads/hr]
    rm.if_rel.load_dc.Area_lin = abs(rm.if_rel.load_dc.L*(ri.if_rel.load_dc.t_ee - ri.t.cf(1))/2 + rm.if_rel.load_dc.L*rm.if_rel.load_dc.E + rm.if_rel.load_dc.L*(ri.if_rel.load_dc.t_re - ri.if_rel.load_dc.t_r)/2); % Total effect of outage [# of Loads * hours]
    
    if ri.if_rel.load_dc.t_ee == ri.t.cf(1) % Check for & handle division by 0
        rm.if_rel.load_dc.F = 0;
    end

    if ri.if_rel.load_dc.t_re == ri.if_rel.load_dc.t_r
        rm.if_rel.load_dc.P = 0;
    end

    % Generators Outaged
    rm.if_rel.gen_dc.L = -ri.if_rel.gen_dc.outage + ri.if_rel.gen_dc.init; % Total amount of generators connected [# of Generators]
    rm.if_rel.gen_dc.F = -rm.if_rel.gen_dc.L/(ri.if_rel.gen_dc.t_ee - ri.t.cf(1)); % Rate of change of degradation [# of Generators/hr]
    rm.if_rel.gen_dc.E = ri.if_rel.gen_dc.t_r - ri.if_rel.gen_dc.t_ee; % Length of disturbed state [hours]
    rm.if_rel.gen_dc.P = rm.if_rel.gen_dc.L/(ri.if_rel.gen_dc.t_re - ri.if_rel.gen_dc.t_r); % Rate of change of recovery [# of Generators/hr]
    rm.if_rel.gen_dc.Area_lin = abs(rm.if_rel.gen_dc.L*(ri.if_rel.gen_dc.t_ee - ri.t.cf(1))/2 + rm.if_rel.gen_dc.L*rm.if_rel.gen_dc.E + rm.if_rel.gen_dc.L*(ri.if_rel.gen_dc.t_re - ri.if_rel.gen_dc.t_r)/2); % Total effect of outage [# of Generators * hours]
    
    if ri.if_rel.gen_dc.t_ee == ri.t.cf(1) % Check for & handle division by 0
        rm.if_rel.gen_dc.F = 0;
    end

    if ri.if_rel.gen_dc.t_re == ri.if_rel.gen_dc.t_r
        rm.if_rel.gen_dc.P = 0;
    end

    % Load Served
    rm.op_rel.load_served.L = -ri.op_rel.load_served.outage + ri.op_rel.load_served.init; % Total amount of degradation [MW]
    rm.op_rel.load_served.F = -rm.op_rel.load_served.L/(ri.op_rel.load_served.t_ee - ri.t.cf(1)); % Rate of change of degradation [MW/hr]
    rm.op_rel.load_served.E = ri.op_rel.load_served.t_r - ri.op_rel.load_served.t_ee; % Length of disturbed state [hours]
    rm.op_rel.load_served.P = rm.op_rel.load_served.L/(ri.op_rel.load_served.t_re - ri.op_rel.load_served.t_r); % Rate of change of recovery [MW/hr]
    rm.op_rel.load_served.Area_lin = abs(rm.op_rel.load_served.L*(ri.op_rel.load_served.t_ee - ri.t.cf(1))/2 + rm.op_rel.load_served.L*rm.op_rel.load_served.E + rm.op_rel.load_served.L*(ri.op_rel.load_served.t_re - ri.op_rel.load_served.t_r)/2); % Total effect of outage [MW * hours]
    
    if ri.op_rel.load_served.t_ee == ri.t.cf(1) % Check for & handle division by 0
        rm.op_rel.load_served.F = 0;
    end

    if ri.op_rel.load_served.t_re == ri.op_rel.load_served.t_r
        rm.op_rel.load_served.P = 0;
    end

    % Percentage of Generation Online
    rm.op_rel.gen_online.L = -ri.op_rel.gen_online.outage + ri.op_rel.gen_online.init; % Total amount of degradation [%]
    rm.op_rel.gen_online.F = -rm.op_rel.gen_online.L/(ri.op_rel.gen_online.t_ee - ri.t.cf(1)); % Rate of change of degradation [%/hr]
    rm.op_rel.gen_online.E = ri.op_rel.gen_online.t_r - ri.op_rel.gen_online.t_ee; % Length of disturbed state [hours]
    rm.op_rel.gen_online.P = rm.op_rel.gen_online.L/(ri.op_rel.gen_online.t_re - ri.op_rel.gen_online.t_r); % Rate of change of recovery [%/hr]
    rm.op_rel.gen_online.Area_lin = abs(rm.op_rel.gen_online.L*(ri.op_rel.gen_online.t_ee - ri.t.cf(1))/2 + rm.op_rel.gen_online.L*rm.op_rel.gen_online.E + rm.op_rel.gen_online.L*(ri.op_rel.gen_online.t_re - ri.op_rel.gen_online.t_r)/2); % Total effect of outage [% * hours]
    
    if ri.op_rel.gen_online.t_ee == ri.t.cf(1) % Check for & handle division by 0
        rm.op_rel.gen_online.F = 0;
    end

    if ri.op_rel.gen_online.t_re == ri.op_rel.gen_online.t_r
        rm.op_rel.gen_online.P = 0;
    end

    %% Compile Simulation Information
    si = struct("n_contingencies", sum(n_dmg), "n_cascades", sum(n_dc));

    % Assign output structures
    resilience_indicators = ri;
    resilience_metrics = rm;
    sim_info = si;
end