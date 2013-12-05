function spec = arg_specifier(varargin)
% Internal: create a base specifier struct for an argument.
% Specifier = arg_specifier(Overrides...)
%
% This function returns a struct that holds all properties of a single argument specification for
% use in arg_define. The specification struct is a container for argument properties that are
% inspected and processed by arg_define and some other arg_* functions (e.g., GUI generators).
%
% In:
%   Overrides... : name-value pairs of fields that should be overridden. Note that no new fields may
%                  be introduced.
%
% Out:
%   A specifier that is recognized by arg_define.
%
% See also:
%   arg_define
%
%                                Christian Kothe, Swartz Center for Computational Neuroscience, UCSD
%                                2010-09-25

% Copyright (C) Christian Kothe, SCCN, 2010, christian@sccn.ucsd.edu
%
% This program is free software; you can redistribute it and/or modify it under the terms of the GNU
% General Public License as published by the Free Software Foundation; either version 2 of the
% License, or (at your option) any later version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
% even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
% General Public License for more details.
%
% You should have received a copy of the GNU General Public License along with this program; if not,
% write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307
% USA

% initialize the struct
spec = struct(...
    ... % core properties
    'head',{@arg_specifier},...     % the expression type that generated this specifier (@arg, @arg_sub, ...)
    'names',{{}}, ...               % cell array of argument names; first is the variable name inside the function, second (if present) is the human-readable name (reported to the GUI), followed by aliases
    'first_name',{''}, ...          % the first name of the argument (used to name the function variables)
    'value',{[]}, ...               % the assigned value of the argument; can be any data structure
    'assigner',{[]},...             % function to be invoked in order to assign a new value the specifier (INTERNAL)
    ... % properties for (possibly dependent) child arguments (INTERNAL)
    'children',{{}}, ...            % cell array of child arguments (returned to the function in a struct, and made available to the GUI in a subgroup)
    'mapper',@(x)x, ...             % mapping function: maps a value into the index space of alternatives (possibly via range) (INTERNAL)
    'alternatives',{{}}, ...        % cell array of alternative children structures; only used for arg_subtoggle, arg_subswitch (INTERNAL)
    'merge',{true},...              % whether the value (a cell array of arguments) should completely replace the default, or be merged with it, such that sub-arguments are only selectively overridden (INTERNAL)
    ... % type-related properties
    'range',{[]}, ...               % the allowed range of the argument (for type checking in GUI and elsewhere); can be [], [lo hi], {'option1','option2','option3',...}
    'type',{[]}, ...                % the type of the argument: string, only touches the type-checking system & GUI
    'shape',{[]}, ...               % the shape of the argument: empty, scalar, row, column, matrix, tensor
    ... % user interface properties
    'help',{''}, ...                % the help text / description for the argument
    'cat',{''}, ...                 % the human-readable category of the argument
    ... % misc attributes
    'displayable',{true},...        % whether the argument may be displayed by GUIs (true/false)
    'deprecated',{false},...        % whether the argument has been deprecated (true/false)
    'experimental',{false},...      % whether the argument is marked as experimental or "prototype-stage" (true/false)
    'guru',{false},...              % whether the argument is marked as guru-level (true/false)
    'empty_overwrites',{true},...   % whether an empty value does replace the default (or any previous) value (true/false)
    'to_double',{false}, ...        % convert numeric values to double before returning them to the function (true/false)
    'skippable',{false}...          % whether the argument is supposed to be skipped under some circumstances in positional argument lists (true/false) (INTERNAL)
    );

% selectively override fields
for k=1:2:length(varargin)
    if isfield(spec,varargin{k})
        spec.(varargin{k}) = varargin{k+1};
    else
        error('BCILAB:arg_specifier:no_new_fields','It is not allowed to introduce fields in an argument declaration that are not declared in arg_specifier: %s',varargin{k});
    end
end

% perform sanity checks
if ~isempty(varargin)
    if ~iscell(spec.names)
        spec.names = {spec.names}; end
    if isempty(spec.names) || ~iscellstr(spec.names)
        error('The argument must have a name or cell array of names.'); end
    spec.first_name = spec.names{1};
    if ~isempty(spec.help)
        spec.help = parse_help(spec.help,spec.first_name);
    elseif spec.displayable
        fprintf('Please specify a description for argument %s, or specify it via arg_nogui() instead.\n',spec.first_name);
    end
end