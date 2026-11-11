function output = findMaxima_CAVPTV(ip, tolerance, strict, threshold, lightbackground, outputType, excludeOnEdges)
    % findMaxima_CAVPTV Replicates the logic of ImageJ's MaximumFinder in MATLAB.
    %   output = findMaxima_CAVPTV(ip, tolerance, strict, threshold, lightbackground, outputType, excludeOnEdges)
    %
    %   Input arguments:
    %   - ip: Input image (2D array).
    %   - tolerance: Minimum height difference between a maximum/minimum and its surroundings.
    %   - strict: Boolean indicating whether to use strict mode.
    %   - threshold: Minimum value for maxima or maximum value for minima to be considered (use -Inf for no threshold on maxima and Inf for no threshold on minima).
    %   - lightbackground: Boolean indicating whether the background is light (true) or dark (false).
    %   - outputType: Specifies the output format:
    %       'SINGLE_POINTS' - Mask with single-point maxima/minima.
    %       'IN_TOLERANCE'  - Mask including all pixels within tolerance of maxima/minima.
    %       'SEGMENTED'     - Watershed-segmented image.
    %       'POINT_SELECTION' - Coordinates of maxima/minima.
    %       'LIST'          - List of maxima/minima coordinates.
    %       'COUNT'         - Number of maxima/minima.
    %   - excludeOnEdges: Boolean indicating whether to exclude maxima/minima at image edges.
    %
    %   Output:
    %   - output: Depends on outputType.
    
    % Ensure the image is in double precision
    ip = double(ip);
    
    % Get image dimensions
    [height, width] = size(ip);
    
    % Initialize variables and constants
    MAXIMUM = uint8(1);
    LISTED = uint8(2);
    PROCESSED = uint8(4);
    MAX_AREA = uint8(8);
    EQUAL = uint8(16);
    MAX_POINT = uint8(32);
    ELIMINATED = uint8(64);
    outputTypeMasks = [MAX_POINT, MAX_AREA, MAX_AREA];
    DIR_X_OFFSET = [0, 1, 1, 1, 0, -1, -1, -1];
    DIR_Y_OFFSET = [-1, -1, 0, 1, 1, 1, 0, -1];
    dirOffset = DIR_Y_OFFSET * width + DIR_X_OFFSET;
    
    % Initialize type image
    types = zeros(height, width, 'uint8');
    
    % Define operation mode based on lightbackground
    findMax = ~lightbackground; % true for finding maxima, false for minima
    
    % Find global min and max
    globalMin = min(ip(:));
    globalMax = max(ip(:));
    
    % Adjust threshold
    if findMax
        if threshold ~= -Inf
            threshold = threshold - (globalMax - globalMin) * 1e-6;
        end
    else
        if threshold ~= Inf
            threshold = threshold + (globalMax - globalMin) * 1e-6;
        end
    end
    
    % Exclude edge maxima/minima if necessary
    excludeEdgesNow = excludeOnEdges && ~strcmpi(outputType, 'SEGMENTED');
    
    % Step 1: Find all local maxima or minima
    maximaPossible = findMax && (globalMax > globalMin);
    minimaPossible = ~findMax && (globalMin < globalMax);
    
    if findMax && strict && (globalMax - globalMin <= tolerance)
        maximaPossible = false;
    elseif ~findMax && strict && (globalMin - globalMax >= tolerance)
        minimaPossible = false;
    end
    
    maxPoints = [];
    
    if (findMax && maximaPossible) || (~findMax && minimaPossible)
        for y = 1:height
            for x = 1:width
                v = ip(y, x);
                if findMax
                    if v == globalMin
                        continue;
                    end
                else
                    if v == globalMax
                        continue;
                    end
                end
                if excludeEdgesNow && (x == 1 || x == width || y == 1 || y == height)
                    continue;
                end
                if findMax
                    if threshold ~= -Inf && v < threshold
                        continue;
                    end
                else
                    if threshold ~= Inf && v > threshold
                        continue;
                    end
                end
                isMax = true;
                for d = 1:8
                    nx = x + DIR_X_OFFSET(d);
                    ny = y + DIR_Y_OFFSET(d);
                    if nx >= 1 && nx <= width && ny >= 1 && ny <= height
                        neighborValue = ip(ny, nx);
                        if findMax
                            if neighborValue > v
                                isMax = false;
                                break;
                            end
                        else
                            if neighborValue < v
                                isMax = false;
                                break;
                            end
                        end
                    end
                end
                if isMax
                    types(y, x) = bitor(types(y, x), MAXIMUM);
                    maxPoints = [maxPoints; y, x, v];
                end
            end
        end
    end
    
    % Step 2: Sort maxima/minima by value
    if ~isempty(maxPoints)
        if findMax
            [~, sortIdx] = sort(maxPoints(:, 3), 'descend');
        else
            [~, sortIdx] = sort(maxPoints(:, 3), 'ascend');
        end
        maxPoints = maxPoints(sortIdx, :);
    end
    
    % Step 3: Analyze maxima/minima
    pList = zeros(height * width, 2); % Preallocate
    xyCoordinates = [];
    
    % Convert outputType to index
    outputTypeIndex = 0;
    switch upper(outputType)
        case 'SINGLE_POINTS'
            outputTypeIndex = 1;
        case 'IN_TOLERANCE'
            outputTypeIndex = 2;
        case 'SEGMENTED'
            outputTypeIndex = 3;
        case 'POINT_SELECTION'
            outputTypeIndex = -1; % Special handling
        case 'LIST'
            outputTypeIndex = -2; % Special handling
        case 'COUNT'
            outputTypeIndex = -3; % Special handling
        otherwise
            error('Invalid outputType specified.');
    end
    
    % Process each maximum/minimum
    for iMax = 1:size(maxPoints, 1)
        y0 = maxPoints(iMax, 1);
        x0 = maxPoints(iMax, 2);
        v0 = maxPoints(iMax, 3);
        if bitand(types(y0, x0), PROCESSED)
            continue;
        end
        pListLen = 1;
        pList(1, :) = [y0, x0];
        types(y0, x0) = bitor(types(y0, x0), bitor(EQUAL, LISTED));
        listI = 1;
        isEdgeMaximum = (x0 == 1 || x0 == width || y0 == 1 || y0 == height);
        maxPossible = true;
        xEqual = x0;
        yEqual = y0;
        nEqual = 1;
        while listI <= pListLen
            y = pList(listI, 1);
            x = pList(listI, 2);
            for d = 1:8
                nx = x + DIR_X_OFFSET(d);
                ny = y + DIR_Y_OFFSET(d);
                if nx >= 1 && nx <= width && ny >= 1 && ny <= height
                    if ~bitand(types(ny, nx), LISTED)
                        if bitand(types(ny, nx), PROCESSED)
                            maxPossible = false;
                            break;
                        end
                        v2 = ip(ny, nx);
                        if findMax
                            if v2 > v0 + 1e-6 % Allow small numerical errors
                                maxPossible = false;
                                break;
                            elseif v2 >= v0 - tolerance - 1e-6
                                pListLen = pListLen + 1;
                                pList(pListLen, :) = [ny, nx];
                                types(ny, nx) = bitor(types(ny, nx), LISTED);
                                if (nx == 1 || nx == width || ny == 1 || ny == height) && (strict || v2 >= v0)
                                    isEdgeMaximum = true;
                                    if excludeOnEdges
                                        maxPossible = false;
                                        break;
                                    end
                                end
                                if abs(v2 - v0) < 1e-6
                                    types(ny, nx) = bitor(types(ny, nx), EQUAL);
                                    xEqual = xEqual + nx;
                                    yEqual = yEqual + ny;
                                    nEqual = nEqual + 1;
                                end
                            end
                        else
                            if v2 < v0 - 1e-6 % Allow small numerical errors
                                maxPossible = false;
                                break;
                            elseif v2 <= v0 + tolerance + 1e-6
                                pListLen = pListLen + 1;
                                pList(pListLen, :) = [ny, nx];
                                types(ny, nx) = bitor(types(ny, nx), LISTED);
                                if (nx == 1 || nx == width || ny == 1 || ny == height) && (strict || v2 <= v0)
                                    isEdgeMaximum = true;
                                    if excludeOnEdges
                                        maxPossible = false;
                                        break;
                                    end
                                end
                                if abs(v2 - v0) < 1e-6
                                    types(ny, nx) = bitor(types(ny, nx), EQUAL);
                                    xEqual = xEqual + nx;
                                    yEqual = yEqual + ny;
                                    nEqual = nEqual + 1;
                                end
                            end
                        end
                    end
                end
            end
            if ~maxPossible
                break;
            end
            listI = listI + 1;
        end
        resetMask = bitcmp(bitor(LISTED, EQUAL), 'uint8');
        xEqual = xEqual / nEqual;
        yEqual = yEqual / nEqual;
        minDist2 = Inf;
        nearestI = 1;
        for listJ = 1:pListLen
            y = pList(listJ, 1);
            x = pList(listJ, 2);
            types(y, x) = bitand(types(y, x), resetMask);
            types(y, x) = bitor(types(y, x), PROCESSED);
            if maxPossible
                types(y, x) = bitor(types(y, x), MAX_AREA);
                if bitand(types(y, x), EQUAL)
                    dist2 = (xEqual - x)^2 + (yEqual - y)^2;
                    if dist2 < minDist2
                        minDist2 = dist2;
                        nearestI = listJ;
                    end
                end
            end
        end
        if maxPossible
            y = pList(nearestI, 1);
            x = pList(nearestI, 2);
            types(y, x) = bitor(types(y, x), MAX_POINT);
            if ~excludeOnEdges || ~isEdgeMaximum
                xyCoordinates = [xyCoordinates; x, y];
            end
        end
    end
    
    % Prepare output
    if outputTypeIndex > 0
        % Create output mask
        mask = bitand(types, outputTypeMasks(outputTypeIndex)) ~= 0;
        output = mask;
    elseif outputTypeIndex == -1 % POINT_SELECTION
        output = xyCoordinates;
    elseif outputTypeIndex == -2 % LIST
        output = array2table(xyCoordinates, 'VariableNames', {'X', 'Y'});
    elseif outputTypeIndex == -3 % COUNT
        output = size(xyCoordinates, 1);
    elseif strcmpi(outputType, 'SEGMENTED')
        % Implement watershed segmentation based on Java code
        output = watershedSegmentation(ip, types, globalMin, globalMax, threshold, excludeOnEdges, findMax);
    end
end

function output = watershedSegmentation(ip, types, globalMin, globalMax, threshold, excludeOnEdges, findMax)
    % Prepare the image for watershed
    [height, width] = size(ip);
    if findMax
        minValue = globalMin;
        if threshold ~= -Inf
            minValue = threshold;
        end
        offset = minValue - (globalMax - minValue) * (1 / 253 / 2 - 1e-6);
        factor = 253 / (globalMax - minValue);
    else
        maxValue = globalMax;
        if threshold ~= Inf
            maxValue = threshold;
        end
        offset = maxValue + (maxValue - globalMin) * (1 / 253 / 2 - 1e-6);
        factor = 253 / (maxValue - globalMin);
    end
    factor = min(factor, 1);
    pixels = zeros(height, width, 'uint8');
    for y = 1:height
        for x = 1:width
            rawValue = ip(y, x);
            if findMax
                if threshold ~= -Inf && rawValue < threshold
                    pixels(y, x) = 0;
                elseif bitand(types(y, x), 8) % MAX_AREA
                    pixels(y, x) = 255;
                else
                    v = 1 + round((rawValue - offset) * factor);
                    v = min(max(v, 1), 254);
                    pixels(y, x) = v;
                end
            else
                if threshold ~= Inf && rawValue > threshold
                    pixels(y, x) = 0;
                elseif bitand(types(y, x), 8) % MAX_AREA
                    pixels(y, x) = 255;
                else
                    v = 1 + round((maxValue - rawValue) * factor);
                    v = min(max(v, 1), 254);
                    pixels(y, x) = v;
                end
            end
        end
    end
    
    % Perform watershed segmentation
    output = javaWatershed(pixels);
    
    % Post-process the segmentation
    output(output ~= 255) = 0;
    
    % Exclude edge particles if necessary
    if excludeOnEdges
        output = excludeEdgeParticles(output, types);
    end
end

function output = javaWatershed(pixels)
    % Simulate the Java watershed algorithm
    [height, width] = size(pixels);
    % Create histogram
    histogram = histcounts(pixels(:), 0:256);
    % Prepare coordinates array
    arraySize = numel(pixels) - histogram(1) - histogram(256);
    coordinates = zeros(arraySize, 1, 'uint32');
    highestValue = find(histogram(2:end-1), 1, 'last');
    levelStart = zeros(256, 1);
    offset = 0;
    for v = 1:254
        levelStart(v) = offset + 1;
        offset = offset + histogram(v + 1);
    end
    levelOffset = zeros(254, 1);
    % Fill coordinates array
    idx = 1;
    for y = 1:height
        for x = 1:width
            v = pixels(y, x);
            if v > 0 && v < 255
                level = v;
                pos = levelStart(level) + levelOffset(level);
                coordinates(pos) = uint32((y - 1) * width + x);
                levelOffset(level) = levelOffset(level) + 1;
                idx = idx + 1;
            end
        end
    end
    % Create fate table
    fateTable = makeFateTable();
    % Process each level
    for level = highestValue:-1:1
        remaining = levelOffset(level);
        if remaining == 0
            continue;
        end
        idle = 0;
        while remaining > 0 && idle < 8
            sumN = 0;
            for pass = 0:7
                [pixels, nChanged, coordinates, remaining] = processLevel(pass, pixels, fateTable, level, coordinates, remaining, width, height);
                sumN = sumN + nChanged;
                if nChanged > 0
                    idle = 0;
                else
                    idle = idle + 1;
                end
            end
        end
    end
    output = pixels;
end

function [pixels, nChanged, coordinates, remaining] = processLevel(pass, pixels, fateTable, level, coordinates, remaining, width, height)
    % Process a level in the watershed algorithm
    nChanged = 0;
    newCoordinates = zeros(size(coordinates));
    newRemaining = 0;
    for i = 1:remaining
        pos = coordinates(i);
        x = mod(pos - 1, width) + 1;
        y = floor((pos - 1) / width) + 1;
        index = 0;
        if y > 1 && pixels(y - 1, x) == 255
            index = bitor(index, 1);
        end
        if x < width && y > 1 && pixels(y - 1, x + 1) == 255
            index = bitor(index, 2);
        end
        if x < width && pixels(y, x + 1) == 255
            index = bitor(index, 4);
        end
        if x < width && y < height && pixels(y + 1, x + 1) == 255
            index = bitor(index, 8);
        end
        if y < height && pixels(y + 1, x) == 255
            index = bitor(index, 16);
        end
        if x > 1 && y < height && pixels(y + 1, x - 1) == 255
            index = bitor(index, 32);
        end
        if x > 1 && pixels(y, x - 1) == 255
            index = bitor(index, 64);
        end
        if x > 1 && y > 1 && pixels(y - 1, x - 1) == 255
            index = bitor(index, 128);
        end
        mask = bitshift(1, pass);
        if bitand(fateTable(index + 1), mask)
            pixels(y, x) = 255;
            nChanged = nChanged + 1;
        else
            newRemaining = newRemaining + 1;
            newCoordinates(newRemaining) = pos;
        end
    end
    coordinates(1:newRemaining) = newCoordinates(1:newRemaining);
    remaining = newRemaining;
end

function fateTable = makeFateTable()
    % Create the fate table for the watershed algorithm
    fateTable = zeros(256, 1, 'uint8');
    for item = 0:255
        isSet = bitget(item, 1:8);
        transitions = sum(xor(isSet, circshift(isSet, -1)));
        if transitions >= 4
            fateTable(item + 1) = 0;
        else
            for i = 1:8
                if isSet(mod(i + 3, 8) + 1)
                    fateTable(item + 1) = bitor(fateTable(item + 1), bitshift(1, i - 1));
                end
            end
        end
    end
end

function output = excludeEdgeParticles(pixels, types)
    % Exclude particles corresponding to edge maxima/minima
    [height, width] = size(pixels);
    % Create mask for edge maxima/minima
    edgeMask = false(height, width);
    edgeMask(1, :) = bitand(types(1, :), 8) ~= 0;
    edgeMask(end, :) = bitand(types(end, :), 8) ~= 0;
    edgeMask(:, 1) = edgeMask(:, 1) | (bitand(types(:, 1), 8) ~= 0);
    edgeMask(:, end) = edgeMask(:, end) | (bitand(types(:, end), 8) ~= 0);
    % Remove edge particles
    output = pixels;
    for y = 1:height
        for x = 1:width
            if edgeMask(y, x) && pixels(y, x) == 255
                % Use flood fill to remove the particle
                output = floodFill(output, x, y, 255, 0);
            end
        end
    end
end

function pixels = floodFill(pixels, x, y, targetValue, replacementValue)
    % Simple flood fill algorithm
    [height, width] = size(pixels);
    if x < 1 || x > width || y < 1 || y > height
        return;
    end
    if pixels(y, x) ~= targetValue
        return;
    end
    pixels(y, x) = replacementValue;
    pixels = floodFill(pixels, x + 1, y, targetValue, replacementValue);
    pixels = floodFill(pixels, x - 1, y, targetValue, replacementValue);
    pixels = floodFill(pixels, x, y + 1, targetValue, replacementValue);
    pixels = floodFill(pixels, x, y - 1, targetValue, replacementValue);
end
