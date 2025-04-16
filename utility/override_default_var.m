% override_default_var.m
%
% Overrides a default variable value with a user specified value. For use
% when the user specifies values in a structure but the variables are used
% directly in the function workspace.
%
% Inputs:
%   n: The variable being overriden. [string or char]
%   v: The variable value. [arbitrary]
%
% Author: Aidan Gerkis
% Date: 16-04-2025
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
function override_default_var(n, v)
    assignin('caller', n, v);
end