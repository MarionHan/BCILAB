function spec = expand_arg(unused,varargin) %#ok<INUSL>
% Internal: expand the output of an arg(...) declaration function into an argument specifier.
% Specifier = expand_arg(ReportType, ...)
%
% The argument declaration functions used in an arg_define declaration produce a compact and
% low-overhead representation that first needs to be expanded into a full specifier struct that
% contains all properties of the argument and can be processed by other functions. This function
% performs the expansion for the atomic arguments, including arg(), arg_nogui(), and arg_norep().
%
%                                Christian Kothe, Swartz Center for Computational Neuroscience, UCSD
%                                2010-09-24

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

    % the result of build_specifier is cached in memory for efficient processing of repeated calls
    spec = hlp_microcache('arg',@build_specifier,varargin{:});
end


% expand the arg(...) declaration line into an argument specifier
function spec = build_specifier(names,default,range,help,varargin)
    % set defaults
    if nargin < 1
        names = {}; end
    if nargin < 2
        default = []; end
    if nargin < 3
        range = []; end
    if nargin < 4
        help = ''; end
    
    % initialize specification struct
    spec = arg_specifier('head',@arg,'names',names,'value',default,'range',range,'help',help,'to_double',[],varargin{:});

    % parse the type
    if isempty(spec.type)
        % if the type is unspecified it is deduced        
        if ~isempty(spec.value)
            % if the value is non-empty, the type is deduced from the value
            spec.type = deduce_type(spec.value);
        elseif isnumeric(spec.range)
            % if the range is numeric, the type is deduced from the range
            spec.type = deduce_type(spec.range);
        elseif iscellstr(spec.range) && iscellstr(spec.value) && isempty(fast_setdiff(spec.value,spec.range))
            % if both the value and the range are cell-string arrays and the value is a subset of
            % the range, the type is 'logical'
            spec.type = 'logical';
        elseif iscell(spec.range) && isscalar(unique(cellfun(@deduce_type,spec.range,'UniformOutput',false)))
            % if the range is a cell array of uniformly-typed values, the type is the unique
            % type of the cell entries
            spec.type = deduce_type(spec.range{1});
        else
            % if no other rule applies, the type is expression
            spec.type = 'expression';
        end
    end    
    
    % parse the shape    
    if isempty(spec.shape)
        % if the shape is unspecified, it is deduced
        if ~isempty(spec.value)
            % if the value is not empty, the shape is deduced from the value
            spec.shape = deduce_shape(spec.value);
        elseif ischar(spec.value) && isempty(spec.value)
            % if the value is an empty char array, the shape is by default 'row'
            spec.shape = 'row';
        elseif ~isempty(spec.range) && isnumeric(spec.range)
            % if a non-empty numeric range is given, the shape is assumed to be a scalar
            spec.shape = 'scalar';
        elseif iscell(spec.range) && isscalar(unique(cellfun(@deduce_shape,spec.range,'UniformOutput',false)))
            % if a cell-array range with uniform shapes is given, the shape is by default the
            % unique shape of the cell entries
            spec.shape = deduce_shape(spec.range{1});
        else
            % if no other rule applies, the shape is matrix
            spec.shape = 'matrix';
        end
    end
    
    % parse the value
    if isequal(spec.value,[]) && iscellstr(spec.range)
        % if the value is [] but the range is a cell-string array (as in a multi-option argument),
        % the value is set to the first option
        spec.value = spec.range{1};
    elseif islogical(spec.value) && isscalar(spec.value) && iscellstr(spec.range)    
        % if the value is true/false, and the range is a cell-string array (as in a set of
        % options), false maps to the empty set and true maps to the full set
        spec.value = quickif(spec.value,spec.range,{});
    elseif isequal(spec.value,[])    
        % if the value is [], it is converted to the declared type
        switch spec.type
            case {'cellstr','cell'}
                spec.value = {};
            case {'char'}
                spec.value = '';
            case {'denserealdouble','densecomplexdouble'}
                spec.value = full(double(spec.value));
            case {'sparserealdouble','sparsecomplexdouble'}
                spec.value = sparse(double(spec.value));
            case {'denserealsingle','densecomplexsingle'}
                spec.value = full(single(spec.value));
            case {'sparserealsingle','sparsecomplexsingle'}
                spec.value = sparse(single(spec.value));
            case {'int8','uint8','int16','uint16','int32','uint32','int64','logical'}
                spec.value = cast(spec.value, spec.type);
        end
    end
    
    % if to_double is still undecided, enable it only if the input type is an integer
    if isempty(spec.to_double)
        spec.to_double = any(strcmp(spec.type,{'int8','uint8','int16','uint16','int32','uint32','int64'})); end
end


% deduce the type of the given value in a manner that is compatible with the PropertyGrid, with the
% addition of the type 'expression', which is to be converted to char() before it goes into the GUI
% and evaluated back into the correct MATLAB type when the GUI is done
function type = deduce_type(value)
    type = class(value);
    switch type
        case {'single','double'}
            if ismatrix(type)
                type = [quickif(issparse(value),'sparse','dense') quickif(isreal(value),'real','complex') type];
            else
                type = 'expression';
            end
        case 'cell'
            type = quickif(iscellstr(value),'cellstr','expression');
        case {'logical','char','int8','uint8','int16','uint16','int32','uint32','int64','uint64'}
            % nothing to do
        otherwise
            type = 'expression';
    end
end


% determine the shape of the given value in a manner that is compatible with the PropertyGrid, with
% the addition of the type 'tensor' (which may be handled by treating the type as an expression)
function shape = deduce_shape(value)
    siz = size(value);
    if isequal(siz,[1,1])
        shape = 'scalar';
    elseif isequal(siz,[0,0])
        shape = 'empty';
    elseif length(siz) > 2
        shape = 'tensor';
    elseif siz(1) == 1
        shape = 'row';
    elseif siz(2) == 1
        shape = 'column';
    else
        shape = 'matrix';
    end
end

