% get_neighbours.m
%
% Returns all components connected to a given node by n or less branches.
%
% Inputs:
%   network: The network to be analyzed, in a MATPOWER case format.
%   start: The starting component, in the format [id; type].
%   n: The number of steps to take
%
% Outputs:
%   neighbours: An array of all components within n branches from the
%               starting component. Formatted as [id; type].

function neighbours = get_neighbours(network, start, n)
    % Process inputs
    id = str2double(start(1));
    
    % Determine initial node
    if isequal(start(2), "branch")
        init_node = network.branch(id, 1); % Assume the starting node to be the from node of the branch
    elseif isequal(start(2), "bus")
        init_node = network.bus(id, 1);
    elseif isequal(start(2), "gen")
        init_node = network.gen(id, 1);
    end

    % Recursively traverse network to find neighbours
    neighbours = apply_recursion(network, init_node, n);
    
    neighbours = unique(neighbours', 'rows')'; 
    return
end

% Recursively traverses the given network, starting at the initial node, to
% find all components within n steps of the initial node.
function neighbours = apply_recursion(network, init_node, n)
    % Add any generation at the current node to the set of neighbours
    gens = find(network.gen(:, 1) == init_node)';
    gens = [gens; repmat("gen", 1, length(gens))];
    
    if n == 0 % Base Case
        neighbours = [gens, [init_node; "bus"]];
        return
    else
        % Find all nodes directly adjacent to the current node
        borders = [network.branch(network.branch(:, 1) == init_node, 2)', network.branch(network.branch(:, 2) == init_node, 1)'];
        borders = [borders; repmat("bus", 1, length(borders))];
        
        % Find all branches connecting to the current node
        branches = [find(network.branch(:, 1) == init_node)', find(network.branch(:, 2) == init_node)'];
        branches = [branches; repmat("branch", 1, length(branches))];
        
        neighbours = [gens, [init_node; "bus"], borders, branches];

        for i=1:length(borders(1, :))
            recur = apply_recursion(network, str2double(borders(1, i)), n - 1);
            neighbours = [neighbours, recur];
        end
    end
end