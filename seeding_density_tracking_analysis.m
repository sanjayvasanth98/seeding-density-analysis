clear all; close all; clc;

%% Step 1: Allow the user to select multiple video files interactively
[fileNames, path] = uigetfile({'*.avi;*.mp4;*.mov', 'Video Files (*.avi, *.mp4, *.mov)'}, ...
                              'Select Video Files', 'MultiSelect', 'on');

% Check if the user clicked "Cancel" (file selection was unsuccessful)
if isequal(fileNames, 0)
    disp('User canceled the file selection.');
    return; % Exit the script
end

% If only one file is selected, convert it to a cell array for consistency
if ischar(fileNames)
    fileNames = {fileNames};
end

% Ask the user for the number of frames to analyze
promptFrames = {'Enter number of frames to analyze (per video):'};
dlgtitleFrames = 'Number of Frames';
dimsFrames = [1 35];
definputFrames = {'10'};
answerFrames = inputdlg(promptFrames, dlgtitleFrames, dimsFrames, definputFrames);

% Check if the user clicked cancel
if isempty(answerFrames)
    disp('User canceled the input.');
    return;
end

numFramesToAnalyze = str2double(answerFrames{1});

% Initialize cell arrays to store data for each video
allNumMaximaPerFrame = cell(length(fileNames),1);
allNumFrames = zeros(length(fileNames),1);
allVideoNames = cell(length(fileNames),1);
allSeedingDensities = zeros(length(fileNames),1);
allMatchingRates = zeros(length(fileNames),1);
allPositionErrors = cell(length(fileNames),1);
allUncertainties = zeros(length(fileNames),1);
allMasks = cell(length(fileNames),1); % To store masks for each video

% Set prompt to 1 to see all plots/figures or 0 to avoid displaying plots
prompt = 0;

%% Step 2: Loop through each selected video file to create masks
for idx = 1:length(fileNames)
    % For each video
    aviFile = fullfile(path, fileNames{idx});
    fprintf('Preparing video file %s (%d of %d)\n', aviFile, idx, length(fileNames));

    % Read the video using VideoReader to get frame size
    vidObj = VideoReader(aviFile);

    % Read the first frame to use for mask creation
    frame = readFrame(vidObj);
    grayFrame = im2gray(frame); % Convert to grayscale

    % Create the interactive mask for each video
    fprintf('Please create a mask for video %d/%d.\n', idx, length(fileNames));
    mask = CreateMask_CAVPTV(grayFrame);
    allMasks{idx} = mask; % Store the mask

    % Display the mask
    if prompt == 1
        figure;
        imshow(mask);
        title(sprintf('Selected Mask for Video %d', idx));
    end
end

%% Step 3: Process each video file
for idx = 1:length(fileNames)
    % For each video
    aviFile = fullfile(path, fileNames{idx});
    fprintf('Processing video file %s (%d of %d)\n', aviFile, idx, length(fileNames));

    % Read the video using VideoReader
    vidObj = VideoReader(aviFile);
    totalNumFrames = floor(vidObj.Duration * vidObj.FrameRate); % Total available frames

    % Determine number of frames to analyze
    numFrames = min(totalNumFrames, numFramesToAnalyze);
    allNumFrames(idx) = numFrames; % Store number of frames analyzed for this video
    allVideoNames{idx} = fileNames{idx};

    % Preallocate the video frames array for efficiency
    videoFrames = zeros(vidObj.Height, vidObj.Width, numFrames, 'uint8');

    % Read the specified number of frames into a 3D matrix (height, width, frames)
    vidObj.CurrentTime = 0; % Reset to the beginning
    for i = 1:numFrames
        frame = readFrame(vidObj);
        grayFrame = im2gray(frame); % Convert to grayscale
        videoFrames(:,:,i) = grayFrame; % Store the grayscale frame
    end

    % Initialize 'processedFrames' with 'videoFrames'
    processedFrames = videoFrames;

    % Conditionally display the original video frame if prompt == 1
    if prompt == 1 && idx == 1
        figure; imshow(processedFrames(:,:,1)); title('Original Grayscale Frame');
    end    

    % Compute Z-Projection (average intensity) over all frames
    avgImage = mean(processedFrames, 3);  % Average intensity projection

    % Convert avgImage to uint8 for consistent processing
    avgImage = uint8(avgImage);

    % Conditionally display the average intensity image if prompt == 1
    if prompt == 1 && idx == 1
        figure; imshow(avgImage); title('Average Intensity Z-Projection (Background Image)');
    end

    %% Background Subtraction
    k1 = 1;
    k2 = mean(avgImage(:));  % Mean grayscale value of the average image

    for i = 1:numFrames
        processedFrames(:,:,i) = (double(processedFrames(:,:,i)) - double(avgImage)) * k1 + k2;
    end

    % Clip values and convert to uint8 for display
    processedFrames = uint8(max(min(processedFrames, 255), 0));

    %% Median Subtraction
    filteredFrames = zeros(size(processedFrames), 'double');
    for i = 1:numFrames
        filteredFrames(:,:,i) = medfilt2(processedFrames(:,:,i), [10 10]);  % Apply a 10x10 median filter
    end

    % Subtract the median-filtered stack from the processed frames
    k1_med = 1;
    k2_med = mean(filteredFrames(:));

    for i = 1:numFrames
        processedFrames(:,:,i) = (double(processedFrames(:,:,i)) - double(filteredFrames(:,:,i))) * k1_med + k2_med;
    end

    % Clip values and convert to uint8 for display
    processedFrames = uint8(max(min(processedFrames, 255), 0));

    %% Conditionally display frames with sliders if prompt == 1
    if prompt == 1 && idx == 1
        % --- Slider for Processed Frames ---
        % Create a figure with a slider to navigate through the frames
        hFig1 = figure('Name', 'Processed Frames');
        hAx1 = axes('Parent', hFig1);
        hImage1 = imshow(processedFrames(:,:,1), 'Parent', hAx1); title('Processed Frames');

        % Add a slider for frame navigation
        hSlider1 = uicontrol('Style', 'slider', 'Min', 1, 'Max', numFrames, 'Value', 1, ...
            'Units', 'normalized', 'Position', [0.2 0.01 0.6 0.05], ...
            'SliderStep', [1/(numFrames-1), 10/(numFrames-1)]);

        % Add a text label to show the current frame number
        hText1 = uicontrol('Style', 'text', 'String', 'Frame 1', 'Units', 'normalized', ...
            'Position', [0.01 0.01 0.15 0.05]);

        % Update function for the slider
        set(hSlider1, 'Callback', @(src, event) updateFrame(round(get(src, 'Value')), hImage1, processedFrames, hText1));
    end

    %% Retrieve the mask for the current video
    mask = allMasks{idx};

    %% Particle Detection Using findMaxima_CAVPTV
    % Parameters for findMaxima_CAVPTV function
    lightbackground = true; % Set to true for light backgrounds (finding minima), false for dark backgrounds (finding maxima)
    tolerance = 15;               % Minimum height difference to consider a maximum/minimum
    strict = false;              % Whether to use strict mode or not
    outputType = 'SINGLE_POINTS'; % Output format: 'SINGLE_POINTS' returns a binary image
    excludeOnEdges = true;         % Whether to exclude maxima/minima at image edges

    % Set threshold based on 'lightbackground'
    if lightbackground
        threshold = Inf;         % For minima detection: maximum allowed value (Inf excludes minima in masked areas)
    else
        threshold = -Inf;        % For maxima detection: minimum allowed value (-Inf excludes maxima in masked areas)
    end

    % Preallocate binary stack for maxima/minima points
    maximaStack = false(size(processedFrames));

    % Initialize arrays to store the number of maxima/minima and their coordinates per frame
    numMaximaPerFrame = zeros(numFrames, 1);
    maximaCoordinates = cell(numFrames, 1);

    % Loop through each frame to detect maxima/minima
    for i = 1:numFrames
        % Get the current frame
        ip = processedFrames(:,:,i);

        % Modify the image to exclude maxima/minima within the mask area
        if lightbackground
            % For minima detection, set mask area pixels to Inf to exclude minima
            ip(mask) = Inf;
        else
            % For maxima detection, set mask area pixels to -Inf to exclude maxima
            ip(mask) = -Inf;
        end

        % Call the findMaxima_CAVPTV function
        maximaBinary = findMaxima_CAVPTV(ip, tolerance, strict, threshold, lightbackground, outputType, excludeOnEdges);

        % Store the binary maxima/minima image
        maximaStack(:,:,i) = maximaBinary;

        % Count the number of maxima/minima in the current frame
        numMaxima = sum(maximaBinary(:));
        numMaximaPerFrame(i) = numMaxima;

        % Get coordinates of maxima/minima
        [yMaxima, xMaxima] = find(maximaBinary);
        maximaCoordinates{i} = [xMaxima, yMaxima];
    end

    % Store the numMaximaPerFrame for this video
    allNumMaximaPerFrame{idx} = numMaximaPerFrame;

    %% Calculate Seeding Density (Particles per Pixel)
    % Seeding density is calculated as the average number of particles detected per frame divided by the number of pixels
    avgNumParticles = mean(numMaximaPerFrame);
    avgParticlesDetected(idx) = avgNumParticles; % Store average particles detected
    numPixels = sum(~mask(:)); % Number of pixels in the unmasked area
    seedingDensity = avgNumParticles / numPixels; % Particles per pixel
    allSeedingDensities(idx) = seedingDensity;

    %% Implement Particle Tracking (Simple Nearest Neighbor Tracking)
    % For particle matching rate and position error calculations
    % Initialize variables
    tracks = cell(numFrames, 1);
    maxDisplacement = 10; % Maximum allowed displacement between frames (adjust as needed)

    % Start tracking from the first frame
    tracks{1} = maximaCoordinates{1};
    totalMatchedParticles = 0;
    totalPossibleMatches = 0;
    positionErrors = [];

    for i = 2:numFrames
        % Get particles from previous and current frames
        prevParticles = maximaCoordinates{i-1};
        currParticles = maximaCoordinates{i};

        if isempty(prevParticles) || isempty(currParticles)
            tracks{i} = currParticles;
            continue;
        end

        % Compute pairwise distances
        D = pdist2(prevParticles, currParticles);

        % Find matches based on minimum distance
        [minDists, idxMatches] = min(D, [], 2);

        % Apply a maximum displacement threshold
        matchedIdx = find(minDists <= maxDisplacement);

        % Count matched particles
        numMatches = length(matchedIdx);
        totalMatchedParticles = totalMatchedParticles + numMatches;
        totalPossibleMatches = totalPossibleMatches + size(prevParticles, 1);

        % Compute position errors (displacement distances)
        positionErrors = [positionErrors; minDists(matchedIdx)];

        % Store current particles for the next iteration
        tracks{i} = currParticles;
    end

    % Calculate particle matching rate
    matchingRate = totalMatchedParticles / totalPossibleMatches;
    allMatchingRates(idx) = matchingRate;

    % Store position errors
    allPositionErrors{idx} = positionErrors;

    % Calculate uncertainties (standard deviation of position errors)
    uncertainty = std(positionErrors);
    allUncertainties(idx) = uncertainty;

    %% Visualization for the first video (optional)
    if prompt == 1 && idx == 1
        % Processed Frames with Detected Points
        hFig2 = figure('Name', 'Processed Frames with Detected Points', 'NumberTitle', 'off');
        hAx2 = axes('Parent', hFig2);
        imshow(processedFrames(:,:,1), [], 'Parent', hAx2);
        hold(hAx2, 'on');
        visboundaries(hAx2, mask, 'Color', 'yellow', 'LineWidth', 1);
        plot(hAx2, maximaCoordinates{1}(:,1), maximaCoordinates{1}(:,2), 'm+', 'LineWidth', 1, 'MarkerSize', 5);
        hold(hAx2, 'off');
        title(hAx2, sprintf('Frame 1: %d Minima Detected', numMaximaPerFrame(1)));

        % Add a slider for frame navigation
        hSlider2 = uicontrol('Style', 'slider', ...
            'Min', 1, 'Max', numFrames, 'Value', 1, ...
            'Units', 'normalized', ...
            'Position', [0.2 0.05 0.6 0.05], ...
            'SliderStep', [1/(numFrames-1), 10/(numFrames-1)], ...
            'Callback', @(src, event) updateFrameWithMask(round(get(src, 'Value')), maximaStack, maximaCoordinates, processedFrames, mask, hAx2, lightbackground));

        % Add a text label to show the current frame number and count
        hText2 = uicontrol('Style', 'text', ...
            'String', sprintf('Frame 1/%d: %d Minima Detected', numFrames, numMaximaPerFrame(1)), ...
            'Units', 'normalized', ...
            'Position', [0.81 0.05 0.18 0.05], ...
            'HorizontalAlignment', 'left');
    end
end

%% Step 4: Define markers and colors before saving variables
colors = lines(length(fileNames)); % Generate distinguishable colors
markers = {'o','s','^','d','v','>','<','p','h','x','+'}; % Define marker shapes

%% Calculate average position errors (added this section)
avgPositionErrors = zeros(length(allPositionErrors),1);
for idx = 1:length(allPositionErrors)
    if ~isempty(allPositionErrors{idx})
        avgPositionErrors(idx) = mean(allPositionErrors{idx});
    else
        avgPositionErrors(idx) = NaN; % Handle cases with no position errors
    end
end
%% Step 5: Save variables used for plotting into a .mat file
% Give the user the option to enter the path for the save folder
% Comment out the interactive part
saveFolder = uigetdir('', 'Select a folder to save the variables (.mat file)');
if saveFolder == 0
    disp('User canceled folder selection.');
    return;
else
    % Create a filename for the .mat file
    matFileName = fullfile(saveFolder, 'PlotVariables.mat');
    % Save variables
    save(matFileName, 'allNumMaximaPerFrame', 'allNumFrames', 'allVideoNames', 'allSeedingDensities', ...
        'allMatchingRates', 'allPositionErrors', 'allUncertainties', 'avgParticlesDetected', 'colors', 'markers');
    disp(['Variables saved successfully to ', matFileName]);
end

% Check if the folder exists
if ~isfolder(saveFolder)
    disp('The specified folder does not exist.');
    return;
else
    % Create a filename for the .mat file
    matFileName = fullfile(saveFolder, 'PlotVariables.mat');
    % Save variables
    save(matFileName, 'allNumMaximaPerFrame', 'allNumFrames', 'allVideoNames', 'allSeedingDensities', ...
    'allMatchingRates', 'allPositionErrors', 'allUncertainties', 'avgParticlesDetected', 'colors', 'markers', 'avgPositionErrors');
    disp(['Variables saved successfully to ', matFileName]);
end

%% Step 6: Load variables from .mat file and generate plots
% Load the variables
load(matFileName);

% Define markers and colors for different datasets (if not already defined)
if ~exist('colors', 'var')
    colors = lines(length(allVideoNames)); % Generate distinguishable colors
end
if ~exist('markers', 'var')
    markers = {'o','s','^','d','v','>','<','p','h','x','+'}; % Define marker shapes
end

% Plot 1: Number of maxima per frame (line plot)
figure('Name', 'Number of Particles Detected per Frame for Each Video');
hold on;

for idx = 1:length(fileNames)
    numMaximaPerFrame = allNumMaximaPerFrame{idx};
    numFrames = length(numMaximaPerFrame);
    % Line plot
    plot(1:numFrames, numMaximaPerFrame, '-', 'Color', colors(idx,:), 'LineWidth', 1);
    % Marker plot
    plot(1:numFrames, numMaximaPerFrame, markers{mod(idx-1,length(markers))+1}, ...
        'MarkerEdgeColor','k' , 'MarkerFaceColor', colors(idx,:), ...
        'LineWidth', 0.5, 'MarkerSize', 6);
end

xlabel('Frame Number', 'FontSize', 12, 'FontName', 'Times New Roman');
ylabel('Number of Particles Detected', 'FontSize', 12, 'FontName', 'Times New Roman');
title('Number of Particles Detected per Frame for Each Video', 'FontSize', 12, 'FontName', 'Times New Roman');
legend(allVideoNames, 'Interpreter', 'none', 'FontSize', 10, 'FontName', 'Times New Roman', 'Location', 'best');
box on;
set(gca, 'FontSize', 10, 'FontName', 'Times New Roman', 'LineWidth', 1);
hold off;
%%
% Plot 2: Refined Box Plot Comparison with Adjusted Y-Axis
figure('Name', 'Comparison of Particle Detection across Videos');
hold on;

% Concatenate data for the box plot
allNumMaximaArray = [];
group = [];
for idx = 1:length(fileNames)
    allNumMaximaArray = [allNumMaximaArray; allNumMaximaPerFrame{idx}];
    group = [group; idx * ones(size(allNumMaximaPerFrame{idx}))];
end

% Custom box plot with unique colors for each group
boxplot(allNumMaximaArray, group, 'Labels', allVideoNames, ...
    'BoxStyle', 'outline', 'Widths', 0.5, ...
    'Symbol', 'o', 'OutlierSize', 6, 'Colors', colors);

% Adjust properties of the box plot for better visuals
h = findobj(gca, 'Tag', 'Box');
for j = 1:length(h)
    patch(get(h(j), 'XData'), get(h(j), 'YData'), colors(j,:), ...
        'FaceAlpha', 0.6, 'EdgeColor', 'k', 'LineWidth', 1.2); % Colorful boxes
end

% Adjust the outlier markers to have black edges
hOutliers = findobj(gca, 'Tag', 'Outliers');
set(hOutliers, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'none', 'LineWidth', 0.8);

% Refined Y-axis adjustment
yMin = min(allNumMaximaArray) - 0.05 * range(allNumMaximaArray); % Smaller padding
yMax = max(allNumMaximaArray) + 0.05 * range(allNumMaximaArray); % Smaller padding
ylim([yMin, yMax]);

% Special case: Highlight the first box plot
highlightBox = findobj(gca, 'Tag', 'Box', '-and', '-depth', 1);
if ~isempty(highlightBox)
    set(highlightBox(1), 'EdgeColor', [0 0 1], 'LineWidth', 1); % Add distinct edge for the first box
end

% Add axis labels and title
xlabel('Video', 'FontSize', 12, 'FontName', 'Times New Roman');
ylabel('Number of Particles Detected per Frame', 'FontSize', 12, 'FontName', 'Times New Roman');
title('Comparison of Particle Detection across Videos', 'FontSize', 12, 'FontName', 'Times New Roman');

% Refine axes appearance
set(gca, 'FontSize', 10, 'FontName', 'Times New Roman', 'LineWidth', 0.7, ...
    'XMinorTick', 'on', 'YMinorTick', 'on', 'Box', 'on');
hold off;

%%
% Plot 3: Particle matching rate vs seeding density (scatter plot)
figure('Name', 'Particle Matching Rate vs Seeding Density');
hold on;

legendEntries = {}; % Initialize legend entries
for idx = 1:length(fileNames)
    scatter(allSeedingDensities(idx), allMatchingRates(idx), 60, ...
        'Marker', markers{mod(idx-1,length(markers))+1}, ...
        'MarkerEdgeColor', 'k', 'MarkerFaceColor', colors(idx,:), 'LineWidth', 1);
    % Add the video name to legend entries
    legendEntries{end+1} = allVideoNames{idx};
end

xlabel('Seeding Density (particles per pixel)', 'FontSize', 12, 'FontName', 'Times New Roman');
ylabel('Particle Matching Rate', 'FontSize', 12, 'FontName', 'Times New Roman');
title('Particle Matching Rate vs Seeding Density', 'FontSize', 12, 'FontName', 'Times New Roman');
legend(legendEntries, 'Interpreter', 'none', 'FontSize', 10, 'FontName', 'Times New Roman', 'Location', 'northeast');
box on;
set(gca, 'FontSize', 10, 'FontName', 'Times New Roman', 'LineWidth', 1, 'XMinorTick', 'on', 'YMinorTick', 'on');
hold off;


% Plot 4: Average particles detected vs seeding density (scatter plot)
figure('Name', 'Particle Detection Rate vs Seeding Density');
hold on;

legendEntries = {}; % Initialize legend entries
for idx = 1:length(fileNames)
    scatter(allSeedingDensities(idx), avgParticlesDetected(idx), 60, ...
        'Marker', markers{mod(idx-1,length(markers))+1}, ...
        'MarkerEdgeColor', 'k', 'MarkerFaceColor', colors(idx,:), 'LineWidth', 1);
    % Add the video name to legend entries
    legendEntries{end+1} = allVideoNames{idx};
end

xlabel('Seeding Density (particles per pixel)', 'FontSize', 12, 'FontName', 'Times New Roman');
ylabel('Average Particles Detected per Frame', 'FontSize', 12, 'FontName', 'Times New Roman');
title('Particle Detection Rate vs Seeding Density', 'FontSize', 12, 'FontName', 'Times New Roman');
legend(legendEntries, 'Interpreter', 'none', 'FontSize', 10, 'FontName', 'Times New Roman', 'Location', 'northeast');
box on;
set(gca, 'FontSize', 10, 'FontName', 'Times New Roman', 'LineWidth', 1, 'XMinorTick', 'on', 'YMinorTick', 'on');
hold off;


% Plot 5: Average position error vs seeding density (scatter plot)
figure('Name', 'Particle Position Error vs Seeding Density');
hold on;

legendEntries = {}; % Initialize legend entries
for idx = 1:length(allVideoNames)
    scatter(allSeedingDensities(idx), avgPositionErrors(idx), 60, ...
        'Marker', markers{mod(idx-1,length(markers))+1}, ...
        'MarkerEdgeColor', 'k', 'MarkerFaceColor', colors(idx,:), 'LineWidth', 1);
    % Add the video name to legend entries
    legendEntries{end+1} = allVideoNames{idx};
end

xlabel('Seeding Density (particles per pixel)', 'FontSize', 12, 'FontName', 'Times New Roman');
ylabel('Average Position Error (pixels)', 'FontSize', 12, 'FontName', 'Times New Roman');
title('Particle Position Error vs Seeding Density', 'FontSize', 12, 'FontName', 'Times New Roman');
legend(legendEntries, 'Interpreter', 'none', 'FontSize', 10, 'FontName', 'Times New Roman', 'Location', 'northeast');
box on;
set(gca, 'FontSize', 10, 'FontName', 'Times New Roman', 'LineWidth', 1, 'XMinorTick', 'on', 'YMinorTick', 'on');
hold off;

% Plot 6: Uncertainties vs seeding density (scatter plot)
figure('Name', 'Uncertainties vs Seeding Density');
hold on;

legendEntries = {}; % Initialize legend entries
for idx = 1:length(fileNames)
    scatter(allSeedingDensities(idx), allUncertainties(idx), 60, ...
        'Marker', markers{mod(idx-1,length(markers))+1}, ...
        'MarkerEdgeColor', 'k', 'MarkerFaceColor', colors(idx,:), 'LineWidth', 1);
    % Add the video name to legend entries
    legendEntries{end+1} = allVideoNames{idx};
end

xlabel('Seeding Density (particles per pixel)', 'FontSize', 12, 'FontName', 'Times New Roman');
ylabel('Uncertainty (pixels)', 'FontSize', 12, 'FontName', 'Times New Roman');
title('Uncertainties vs Seeding Density', 'FontSize', 12, 'FontName', 'Times New Roman');
legend(legendEntries, 'Interpreter', 'none', 'FontSize', 10, 'FontName', 'Times New Roman', 'Location', 'northeast');
box on;
set(gca, 'FontSize', 10, 'FontName', 'Times New Roman', 'LineWidth', 1, 'XMinorTick', 'on', 'YMinorTick', 'on');
hold off;

%% Step 7: Give the users the opportunity to save these plots in high quality

% Ask the user if they want to save the plots
choice = questdlg('Do you want to save these plots?', ...
    'Save Plots', ...
    'Yes','No','Yes');
% choice = 'yes';
if strcmp(choice,'Yes')
%     Give the user the option to enter the path for the save folder
%     Comment out the interactive part
    saveFolderPlots = uigetdir('', 'Select a folder to save the plots');
    if saveFolderPlots == 0
        disp('User canceled folder selection.');
    else
        % Save the plots
        % Get the figures
        figs = findobj('Type', 'figure');
        for i = 1:length(figs)
            fig = figs(i);
            % Create a filename
            filename = sprintf('Plot%d.png', i);
            filepath = fullfile(saveFolderPlots, filename);
            % Save the figure in high quality
            exportgraphics(fig, filepath, 'Resolution', 300);
        end
        disp('Plots saved successfully.');
    end

    % Ask the user to enter the path for the save folder
    % Check if the folder exists
    if ~isfolder(saveFolderPlots)
        disp('The specified folder does not exist.');
    else
        % Save the plots
        % Get the figures
        figs = findobj('Type', 'figure');
        for i = 1:length(figs)
            fig = figs(i);
            % Create a filename
            filename = sprintf('Plot%d.png', i);
            filepath = fullfile(saveFolderPlots, filename);
            % Save the figure in high quality
            exportgraphics(fig, filepath, 'Resolution', 300);
        end
        disp('Plots saved successfully.');
    end
end

%% Helper Functions

function updateFrame(frameNumber, hImage, processedFrames, hText)
    % Update the image and text based on the slider value
    set(hImage, 'CData', processedFrames(:,:,frameNumber));
    set(hText, 'String', sprintf('Frame %d', frameNumber));
end

function updateFrameWithMask(frameIdx, maximaStack, maximaCoordinates, processedFrames, mask, hAx, lightbackground) 
    % updateFrameWithMask Updates the displayed frame and overlays detected points
    %
    % Parameters:
    % - frameIdx: Index of the current frame to display
    % - maximaStack: Binary stack of detected maxima/minima
    % - maximaCoordinates: Cell array of coordinates for maxima/minima per frame
    % - processedFrames: Original processed frames
    % - mask: Binary mask to overlay
    % - hAx: Handle to the axes where image is displayed
    % - lightbackground: Boolean indicating detection mode

    % Validate frame index
    if frameIdx < 1 || frameIdx > size(processedFrames, 3)
        warning('Frame index out of bounds.');
        return;
    end

    % Clear existing overlays
    cla(hAx);

    % Display the current frame
    imshow(processedFrames(:,:,frameIdx), [], 'Parent', hAx);
    hold(hAx, 'on');

    % Overlay mask boundaries correctly by passing hAx as the first argument
    visboundaries(hAx, mask, 'Color', 'yellow', 'LineWidth', 1);

    % Overlay detected maxima/minima on the image if any
    if ~isempty(maximaCoordinates{frameIdx})
        plot(hAx, maximaCoordinates{frameIdx}(:,1), maximaCoordinates{frameIdx}(:,2), 'm+', 'LineWidth', 1.5, 'MarkerSize', 8);
    end

    hold(hAx, 'off');

    % Determine the detection type string
    if lightbackground
        detectionTypeStr = 'Minima';
    else
        detectionTypeStr = 'Maxima';
    end

    % Update the title with frame information
    numMaxima = sum(maximaStack(:,:,frameIdx), 'all');
    title(hAx, sprintf('Frame %d: %d %s Detected', frameIdx, numMaxima, detectionTypeStr));

    % Update the text label
    hFig = ancestor(hAx, 'figure');
    children = get(hFig, 'Children');
    hText = findobj(children, 'Style', 'text');
    if ~isempty(hText)
        set(hText, 'String', sprintf('Frame %d/%d: %d %s Detected', frameIdx, size(processedFrames,3), numMaxima, detectionTypeStr));
    end
end
