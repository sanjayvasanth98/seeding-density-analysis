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
promptFrames = {'Enter number of frames to analyze:'};
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

prompt = 1; % Set this to 1 to see all plots/figs or 0 to avoid displaying plots

%% Step 2: Loop through each selected video file
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
        figure; imshow(avgImage); title('Average Intensity Z-Projection (BG image)');
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
    
    %% Select Masking Area
    % Read an example image
    img = avgImage; % Read Z-projection image
    
    % Create the interactive mask (only once if desired)
    if idx == 1
        mask = CreateMask_CAVPTV(img);
    end
    
    % Display the mask
    if prompt == 1 && idx == 1
        figure;
        imshow(mask);
        title('Selected Mask');
    end
    
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
    
    %% Visualization for the first video (optional)
    if prompt == 1 && idx == 1
        % Processed Frames with Mask and Detected Points
        hFig2 = figure('Name', 'Processed Frames with Detected Points', 'NumberTitle', 'off');
        hAx2 = axes('Parent', hFig2);
        imshow(processedFrames(:,:,1), [], 'Parent', hAx2);
        hold(hAx2, 'on');
        visboundaries(hAx2, mask, 'Color', 'yellow', 'LineWidth', 1);
        hold(hAx2, 'off');
        title(hAx2, sprintf('Frame 1: %d Minima Detected', numMaximaPerFrame(1)));
        hold(hAx2, 'on');
        plot(hAx2, maximaCoordinates{1}(:,1), maximaCoordinates{1}(:,2), 'm+', 'LineWidth', 1, 'MarkerSize', 5);
        hold(hAx2, 'off');
    
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

%% Step 3: Compare the data as plots to get statistical information

% Create a figure for the number of maxima per frame
figure('Name', 'Number of Particles Detected per Frame for Each Video');
hold on;

% Use different colors or markers for each video
colors = lines(length(fileNames)); % Get distinguishable colors

for idx = 1:length(fileNames)
    numMaximaPerFrame = allNumMaximaPerFrame{idx};
    numFrames = length(numMaximaPerFrame);
    plot(1:numFrames, numMaximaPerFrame, '-o', 'Color', colors(idx,:), 'LineWidth', 1.5, ...
        'MarkerSize', 6, 'MarkerFaceColor', colors(idx,:));
end

xlabel('Frame Number', 'FontSize', 14);
ylabel('Number of Particles Detected', 'FontSize', 14);
title('Number of Particles Detected per Frame for Each Video', 'FontSize', 16);
legend(allVideoNames, 'Interpreter', 'none', 'FontSize', 12, 'Location', 'best');
box on;
set(gca, 'FontSize', 12);
hold off;

% Create box plots to compare the distributions
figure('Name', 'Comparison of Particle Detection across Videos');
allNumMaximaArray = [];
group = [];
for idx = 1:length(fileNames)
    allNumMaximaArray = [allNumMaximaArray; allNumMaximaPerFrame{idx}];
    group = [group; idx*ones(size(allNumMaximaPerFrame{idx}))];
end
boxplot(allNumMaximaArray, group, 'Labels', allVideoNames, 'LabelOrientation', 'inline', 'Colors', colors);
xlabel('Video', 'FontSize', 14);
ylabel('Number of Particles Detected per Frame', 'FontSize', 14);
title('Comparison of Particle Detection across Videos', 'FontSize', 16);
set(gca, 'FontSize', 12);
box on;

%% Step 4: Give the users the opportunity to save these plots in high quality

% Ask the user if they want to save the plots
choice = questdlg('Do you want to save these plots?', ...
    'Save Plots', ...
    'Yes','No','Yes');

if strcmp(choice,'Yes')
    % Prompt the user to select a folder
    saveFolder = uigetdir('', 'Select a folder to save the plots');
    if saveFolder == 0
        disp('User canceled folder selection.');
    else
        % Save the plots
        % Get the figures
        figs = findobj('Type', 'figure');
        for i = 1:length(figs)
            fig = figs(i);
            % Create a filename
            filename = sprintf('Plot%d.png', i);
            filepath = fullfile(saveFolder, filename);
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
        plot(hAx, maximaCoordinates{frameIdx}(:,1), maximaCoordinates{frameIdx}(:,2), 'm+', 'LineWidth', 1, 'MarkerSize', 5);
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
