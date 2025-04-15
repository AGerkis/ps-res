% output_enumeration.m
%
% Creates the arrays defining the output enumeration used in the PSres
% model.
%
% Author: Aidan Gerkis
% Date: 10-04-2025
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

%% Define Enumerations
i_one = ["op_rel", "if_rel"]; % Enumerate indicator categories
i_two = ["load_served", "tl_dc"]; % Enumerate indicator types
m = ["F", "L", "E", "P", "Area_lin"]; % Enumerate metrics