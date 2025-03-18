% Power_System_Recovery_v1.m
%
% Takes a failed network as an input and computes the recovery based on random
% samples of recovery time. Treats damaged components and disconnected
% components separately, not assigning a repair time to components 
% disconnected due to a cascading failure. Does not consider prioritization 
% of components. The result is returned in a modified version of the MATPOWER 
% case format.
%
% Author: Aidan Gerkis
%
% Date: 18-12-2023
%
% Inputs:
%   network: The AC-CFM output, with the modified formatting used for this project.
%   damaged: The set of damaged components, represented by their IDs. Organized 
%            as [branches, busses, gens].
%   n_dmg: The number of damaged components of each type, input as an array
%          with the same organization as damaged.
%   disconnected: The set of disconnected components, represented by their IDs. 
%                 Organized as [branches, busses, gens].
%   n_dc: The number of disconnected components of each type, input as an array
%         with the same organization as disconnected.
%   samples: A structure containing recovery times for each component.
%   T_workers: Number of crews able to perform recovery operations on each
%              component. Assumes that a number of crews are assigned to
%              each component type. In the format [# of workers for branch
%              repair, # of workers for node repair, # of workers for
%              generator repair].
%   pf_settings: The desired settings for the power flow computation, in the 
%                MATPOWER mopt format. (optional)
%
% Outputs:
%   recovery_results: A structure containing the results of the recovery
%   phase.
function recovery_results = Power_System_Recovery_v1(network, damaged, n_dmg, disconnected, n_dc, rec_time, T_workers, pf_settings)
    % Define MATPOWER constants
    define_constants;

    % Simulation Parameters
    max_itr = 20; % Maximum iterations of OPF allowed
    max_recovery_itr = 1000; % Maximum # of iterations of the recovery algorithm
    load_restored = 0; % A flag that stops iterations of AC OPF when the load has been fully restored
    
    % Custom Values for MATPOWER Network Structures
    settings.custom.bus{1} = {'bus_id', 'bus_tripped', 'bus_uvls', 'bus_ufls'};
    settings.custom.gen{1} = {'gen_id', 'gen_tripped'};
    settings.custom.branch{1} = {'branch_id', 'branch_tripped'};

    % Load default settings if no settings were provided    
    if ~exist('pf_settings', 'var') || ~isstruct(pf_settings)
        pf_settings = get_default_settings();
    end

    % Parameters
    T_workers_branch = T_workers(1); % # of workers assigned to repairing transmission lines
    T_workers_bus = T_workers(2); % # of workers assigned to repairing nodes
    T_workers_gen = T_workers(3); % # of workers assigned to repairing generators
    tot_workers = sum(T_workers); % Total # of repair crews
    
    n_branch_dmg = n_dmg(1); % # of failed branches
    n_bus_dmg = n_dmg(2); % # of failed busses
    n_gen_dmg = n_dmg(3); % # of failed generators
    
    n_branch_dc = n_dc(1); % # of disconnected branches
    n_bus_dc = n_dc(2); % # of disconnected busses
    n_gen_dc = n_dc(3); % # of disconnected generators
    
    t_thres = 600; % The threshold time after which all disconnected components should be reconnected. [Hours]

    % Initialize seed for random variable generation
    rng('shuffle', 'twister'); % Use Mersenne Twister PRNG, initialized with shuffle to prevent repetivity on MATLAB reset

    % Variables for computing recovery
    active = strings(3, tot_workers); % An array storing the IDs, types and recovery times of the failed components actively being worked on, as well as the 
    t_prev = 0; % Initialize time
    t = zeros(1, max_recovery_itr); % Array of time
    
    % Initialize variables storing output parameters
    % Infrastructure Resiliency Indicators - # Of Components Outaged
    network.if_rel.tl_outaged_count = zeros(1, max_recovery_itr + 1); % Store number of outaged transmission lines [unitless]
    network.if_rel.tl_outaged_count(1) = sum(damaged(2,:) == "branch") + sum(disconnected(2,:) == "branch"); % Initialize number of outaged transmission lines
    network.if_rel.gen_outaged_count = zeros(1, max_recovery_itr + 1); % Store number of outaged generators [unitless]
    network.if_rel.gen_outaged_count(1) = sum(damaged(2,:) == "gen") + sum(disconnected(2,:) == "gen"); % Initialize number of outaged generators
    network.if_rel.loads_disconnected_count = zeros(1, max_recovery_itr + 1); % Store number of outaged loads [unitless]
    network.if_rel.loads_disconnected_count(1) = sum(damaged(2,:) == "bus") + sum(disconnected(2,:) == "bus"); % Initialize number of outaged loads
    % Operational Resiliency Indicators
    % Load Related Variables
    network.op_rel.load_p_served = zeros(length(network.bus(:,1)), max_recovery_itr + 1); % Store amount of load served at each bus [W]
    network.op_rel.load_p_served(:,1) = network.bus(:,3); % Initialize amount of active power
    network.op_rel.load_q_served = zeros(length(network.bus(:,1)), max_recovery_itr + 1); % Store amount of reactive power served at each bus [VA]
    network.op_rel.load_q_served(:,1) = network.bus(:,4); % Initialize amount of reactive power
    network.op_rel.total_p_load = zeros(1, max_recovery_itr + 1); % Store total load served in the network [W]
    network.op_rel.total_p_load(:,1) = sum(network.op_rel.load_p_served(:,1)); % Initialize total load served
    network.op_rel.total_q_load = zeros(1, max_recovery_itr + 1); % Store total reactive power served in the network [VA]
    network.op_rel.total_q_load(:,1) = sum(network.op_rel.load_q_served(:,1)); % Initialize total reactive power served
    % Generation Related Variables
    network.op_rel.p_gen = zeros(length(network.gen(:,1)), max_recovery_itr + 1); % Store amount of active power generation at each generator [W]
    network.op_rel.p_gen(:,1) = network.gen(:,3); % Initialize amount of active power generation
    network.op_rel.q_gen = zeros(length(network.gen(:,1)), max_recovery_itr + 1); % Store amount of reactive power generation at each generator [VA]
    network.op_rel.q_gen(:,1) = network.gen(:,4); % Initialize amount of reactive power
    network.op_rel.total_p_gen = zeros(1, max_recovery_itr + 1); % Store total active power generation in the network [W]
    network.op_rel.total_p_gen(:,1) = sum(network.op_rel.p_gen(:,1)); % Initialize total load served
    network.op_rel.total_q_gen = zeros(1, max_recovery_itr + 1); % Store total reactive power generation in the network [VA]
    network.op_rel.total_q_gen(:,1) = sum(network.op_rel.q_gen(:,1)); % Initialize total reactive power served
    network.op_rel.p_cap = zeros(1, max_recovery_itr + 1); % Store total amount of generation online
    network.op_rel.p_cap(1) = sum((network.gen(:,9)').*(1 - network.failed_gens)); % Initial generation online right after disturbance

    % Sample recovery time for each component
    if n_branch_dmg > 0
        t_r_br = abs(rec_time.branches(str2double(damaged(1, :))));
    else
        t_r_br = [];
    end

    if n_bus_dmg > 0
        t_r_bus = abs(rec_time.busses(str2double(damaged(1, :))));
    else
        t_r_bus = [];
    end

    if n_gen_dmg > 0
        t_r_gen = abs(rec_time.gens(str2double(damaged(1, :))));
    else
        t_r_gen = [];
    end

    t_r = [t_r_br, t_r_bus, t_r_gen];
    damaged = [damaged; t_r]; % Add recovery time to array of damaged components

    % Sort array so that the quickest repairs are done first
    if n_branch_dmg + n_bus_dmg + n_gen_dmg > 0
        [~, order] = sort(str2double(damaged(3, :)));
        damaged = damaged(:, order);
    end

    % Initialize recovery process <- No priority, simply reconnects components in order with their ID # and type.
    for i=1:tot_workers
        if i <= T_workers_branch && i <= n_branch_dmg % Add branch to active set
            active(:, i) = damaged(:, i);
        elseif i - T_workers_branch <= T_workers_bus && i - T_workers_branch <= n_bus_dmg && n_bus_dmg > 0% Add bus to active set
            active(:, i) = damaged(:, n_branch_dmg + i - T_workers_branch);
        elseif i - T_workers_branch - T_workers_bus <= T_workers_gen && i - T_workers_branch - T_workers_bus <= n_gen_dmg && n_gen_dmg > 0% Add generator to active set
            active(:, i) = damaged(:, n_branch_dmg + n_bus_dmg + i - T_workers_branch - T_workers_bus);
        end
    end
    
    recovery_itr = 1; % Initialize recovery iteration counter
    
    % Loop recovery process until all nodes have been recovered
    while (~isempty(damaged) || ~isempty(disconnected)) && recovery_itr < max_recovery_itr
        t_cur = min(min(str2double(active(3,:))) + t_prev, t_thres); % Current time is the minimum of the recovery times of active components and the threshold time
        
        if t_cur ~= t_thres % Find index of component being repaired
            indices = find(str2double(active(3,:))==min(str2double(active(3,:)))); % Find components which are being recovered at this time step, indexed within active array
        else
            indices = find(str2double(active(3,:)) == t_thres);
        end

        if ~isempty(indices) % Create array of components that have been repaired
            fixed_comp = strings(2, length(indices));
        else
            fixed_comp = strings(2,0);
        end
        
        all_neighbours = [];

        for i=1:length(indices) % Complete the recovery of the components being fixed
            index_cur = indices(i) - (i-1); % Index, adjusted to account for removal of components
            
            % Retrieve component data
            fixed_comp(1,i) = str2double(active(1, index_cur)); % Retrieve ID of component currently being fixed
            fixed_comp(2,i) = active(2, index_cur); % Retrieve type of component currently being fixed

            % Add component back to network & update recovery indicators
            [network, n_branch_dmg, n_bus_dmg, n_gen_dmg] = restore_component(network, fixed_comp(:, i), n_branch_dmg, n_bus_dmg, n_gen_dmg);
            
            % Reconnect Neighbouring Disconnected Components
            if ~isempty(disconnected)
                neighbours = get_neighbours(network, fixed_comp(1:2, i), 2); % Arbitrarily consider a distance of 2 for reconnection
    
                % Remove components that aren't failed
                for j=1:length(neighbours(1,:))
                    if ~any(ismember(neighbours(:, j)', fixed_comp', 'rows')) && ~ismember(neighbours(:, j)', damaged(1:2, :)', 'rows') % Only proceed if component was not already repaired in this loop and component was not damaged
                        [network, n_branch_dc, n_bus_dc, n_gen_dc] = restore_component(network, neighbours(:, j), n_branch_dc, n_bus_dc, n_gen_dc);
    
                        % Remove element from array of disconnected elements
                        [~, index] = ismember(neighbours(:, j)', disconnected', 'rows');
    
                        if index ~= 0
                            disconnected(:, index) = [];
                        end
                    end
                end
            end
            % Update list of all disconnected components
            all_neighbours = unique(all_neighbours', 'rows')';
            
            % Remove component from array of failed components
            active(:, active(1,:) == fixed_comp(1,i) & active(2,:) == fixed_comp(2,i)) = [];
            damaged(:, damaged(1,:) == fixed_comp(1,i) & damaged(2,:) == fixed_comp(2,i)) = [];
        end
        
        if (isempty(damaged) || t_cur == t_thres) && ~isempty(disconnected) % If all components have been repaired but some need to still be reconnected OR if a significant amount of time has passed since restoration began
            % Initialize Arrays
            if isempty(damaged)
                fixed_comp = []; % Need to initialize this array to prevent an error when compiling all components
            end

            all_neighbours = [];

            for i=1:length(disconnected(1, :))
                [network, n_branch_dc, n_bus_dc, n_gen_dc] = restore_component(network, disconnected(:, i), n_branch_dc, n_bus_dc, n_gen_dc);
                
                all_neighbours = [all_neighbours, disconnected(:, i)];
            end

            % Remove all elements from array of disconnected elements
            disconnected(:, :) = [];
        end

        % Compile array of all fixed and reconnected components
        fixed_comp = [fixed_comp, all_neighbours];

        % Find islands present in new network
        islands_set = find_islands(network);
        islands_r = []; % Stores indices of islands containing components recovered in the current timestep
        
        for i=1:length(indices) % Determine which islands contain components which have been recovered in the current timestep
            for j=1:length(islands_set)
                island = extract_islands(network, islands_set, j, settings.custom); % Extracts the jth island from the network

                if isequal(fixed_comp(2,i), "branch") % Check if failed component is in island
                    if ismember(str2double(fixed_comp(1,i)), island.branch_id)
                        islands_r = [islands_r, j]; % Mark island as containing a recovered component
                    end
                elseif isequal(fixed_comp(2,i), "bus")
                    if ismember(str2double(fixed_comp(1,i)), island.bus_id)
                        islands_r = [islands_r, j]; % Mark island as containing a recovered component
                    end
                elseif isequal(fixed_comp(2,i), "gen")
                    if ismember(str2double(fixed_comp(1,i)), island.gen_id)
                        islands_r = [islands_r, j]; % Mark island as containing a recovered component
                    end
                end
            end
        end
        
        islands_r = unique(islands_r); % Remove repeated values from the list, so OPF only runs once on each island
        
        % Run OPF on each island containing recovered components
        for i=1:length(islands_r)
            island_cur = extract_islands(network, islands_set, i, settings.custom); % Extract current island

            % Ensure there is only one reference bus in the island
            ref_busses = get_slack_gen(island_cur);

            if length(ref_busses) > 1 % If more than one reference bus exists set all busses to PQ busses and then assign a new reference bus
                for j=1:length(ref_busses) % Reset all busses to PQ
                    island_cur.bus(ref_busses(j), BUS_TYPE) = 1;
                end

                island_cur = add_reference_bus(island_cur); % Assign a new reference bus                
            elseif isempty(ref_busses) % Add a reference bus if one does not exist
                island_cur = add_reference_bus(island_cur); % Assign a new reference bus 
            end

            island_init = island_cur; % Save current island values

            test_island = island_cur;
        
            % Test to see if system can support initial demand
            for j=1:length(test_island.bus(:,1)) % For each bus in the island
                test_island.bus(j, 3) = network.demand_init(1, test_island.bus(j,1)); % Set active power demand
                test_island.bus(j, 4) = network.demand_init(2, test_island.bus(j,1)); % Set reactive power demand
            end
            
            if ~load_restored && sum(test_island.gen(:, 8)) ~= 0 % If load has not been restored in a previous step AND the island contains an active generator find the maximum load that it can support
                [test_island, success] = runopf(test_island, pf_settings);
            
                if success % If system can support load
                    island_cur = test_island;
                    load_restored = 1;
                else % Incrementally increase load until a load which can be supported is found
                    success = 1; % Initialize variable flagging non-convergence of OPF
                    itr = 0;
    
                    while (success && itr <= max_itr) % Loop OPF until convergence
                        island_prev = island_cur;
        
                        % Adjust loading if system is constrained or did not converge
                        for j=1:length(island_cur.bus(:,1)) % Increases loading by a ratio depending on the delta of loading between initial and failed network
                            island_cur.bus(j, 3) = island_cur.bus(j, 3) + (network.demand_init(1, island_cur.bus(j,1)) - island_init.bus(j,3))/max_itr;
                            island_cur.bus(j, 4) = island_cur.bus(j, 4) + (network.demand_init(2, island_cur.bus(j,1)) - island_init.bus(j,4))/max_itr;
                        end
        
                        % Run OPF
                        [island_cur, success] = runopf(island_cur, pf_settings);
        
                        itr = itr + 1;
                    end
    
                    if itr >= max_itr % If iteration count has exceeded then assume all load is restored
                        % Do nothing
                    else % Otherwise
                        island_cur = island_prev;
                    end
                end
            else % If load has been restored in a previous recovery step
                island_cur = test_island;
            end

            % Assign updated island variables to corresponding branches/busses/gens in the network
            % Dynamically trims output array depending on size (MATPOWER returns extra variables when running OPF that cause issues with this assignment)
            for j=1:length(island_cur.branch_id) % Assign updated pf variables to each changed bus
                network.branch(island_cur.branch_id(j), :) = island_cur.branch(j, 1:length(network.branch(1, :)));
            end

            for j=1:length(island_cur.bus_id) % Assign updated pf variables to each changed branch
                network.bus(island_cur.bus_id(j), :) = island_cur.bus(j, 1:1:length(network.bus(1, :)));
            end

            for j=1:length(island_cur.gen_id) % Assign updated pf variables to each changed generator
                network.gen(island_cur.gen_id(j), :) = island_cur.gen(j, 1:1:length(network.gen(1, :)));
            end
        end

        % Extract Data of Interest from Power System
        % Infrastructure Resiliency Indicators
        network.if_rel.tl_outaged_count(recovery_itr + 1) = sum(network.failed_branches); %network.if_rel.tl_outaged_count(1) - sum(network.failed_branches); % Update number of outaged transmission lines
        network.if_rel.gen_outaged_count(recovery_itr + 1) = sum(network.failed_gens); %network.if_rel.gen_outaged_count(1) - sum(network.failed_gens); % Update number of outaged generators
        network.if_rel.loads_disconnected_count(recovery_itr + 1) = sum(network.failed_busses); % network.if_rel.loads_disconnected_count(1) - sum(network.failed_busses); % Update number of outaged loads
        % Operational Resiliency Indicators
        % Load Related Variables
        network.op_rel.load_p_served(:,recovery_itr + 1) = network.bus(:,3); % Update amount of active power
        network.op_rel.load_q_served(:,recovery_itr + 1) = network.bus(:,4); % Update amount of reactive power
        network.op_rel.total_p_load(:,recovery_itr + 1) = sum(network.op_rel.load_p_served(:,recovery_itr + 1)); % Update total load served
        network.op_rel.total_q_load(:,recovery_itr + 1) = sum(network.op_rel.load_q_served(:,recovery_itr + 1)); % Update total reactive power served
        % Generation Related Variables
        network.op_rel.p_gen(:,recovery_itr + 1) = network.gen(:,2); % Update amount of active power generation
        network.op_rel.q_gen(:,recovery_itr + 1) = network.gen(:,3); % Update amount of reactive power
        network.op_rel.total_p_gen(:,recovery_itr + 1) = sum(network.op_rel.p_gen(:,recovery_itr + 1)); % Update total load served
        network.op_rel.total_q_gen(:,recovery_itr + 1) = sum(network.op_rel.q_gen(:,recovery_itr + 1)); % Update total reactive power served
        network.op_rel.p_cap(recovery_itr + 1) = sum((network.gen(:,9)').*(1 - network.failed_gens)); % Update amount of total generation online
        
        % Adjust time remaining for recovery of remaining components
        if ~isempty(active)
            active(3,:) = str2double(active(3,:)) - (t_cur - t_prev);
        end

        % Assign new components for work
        for i=1:(length(indices))
            % Components are placed in the last indices of the array to
            % ensure components are not overwritten
            
            % Add component to active set if their is a crew with the
            % required specialization available, and if there are
            % components of that type remaining to be repaired
            n_branch_active = sum(ismember(active(2,:), "branch"));
            n_bus_active = sum(ismember(active(2,:), "bus"));
            n_gen_active = sum(ismember(active(2,:), "gen"));

            if (n_branch_active ~= T_workers_branch) && (sum(ismember(damaged(2,:), "branch")) > n_branch_active)
                active(:, length(active(1,:)) + 1) = damaged(:, n_branch_active + 1);
            elseif (n_bus_active ~= T_workers_bus) && (sum(ismember(damaged(2,:), "bus")) > n_bus_active)
                active(:, length(active(1,:)) + 1) = damaged(:, n_branch_dmg + n_bus_active + 1);
            elseif (n_gen_active ~= T_workers_gen) && (sum(ismember(damaged(2,:), "gen")) > n_gen_active)
                active(:, length(active(1,:)) + 1) = damaged(:, n_branch_dmg + n_bus_dmg + n_gen_active + 1);
            end
        end

        % Adjust time and update iteration counter
        recovery_itr = recovery_itr + 1;
        t(recovery_itr) = t_cur;
        t_prev = t_cur;

        if t_cur == 600
            t_thres = 100000; % Need to increase threshold time to ensure this condition is not entered again
        end
    end

    % Assign outputs
    network.recovery_time = t;
    network.iterations = recovery_itr;

    recovery_results = network;
end