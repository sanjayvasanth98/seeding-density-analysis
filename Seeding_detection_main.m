clear all; close all;clc;

%% Step 1: Read and process the video frames 
% Prompt the user to select a video file interactively
% Define the types of video files to display in the dialog
[file, path] = uigetfile({'*.avi;*.mp4;*.mov', 'Video Files (*.avi, *.mp4, *.mov)'}, ...
                          'Select a Video File');

% Check if the user clicked "Cancel" (file selection was unsuccessful)
if isequal(file, 0)
    disp('User canceled the file selection.');
    aviFile = []; % Assign an empty array to aviFile
else
    % Construct the full file path by combining the selected path and file name
    aviFile = fullfile(path, file);
    fprintf('Selected video file: %s\n', aviFile);
end

prompt = 1; % set this to 1 to see all plots/figs or 0 to avoid displaying plots

% Read the video using VideoReader
vidObj = VideoReader(aviFile);
numFrames = vidObj.NumFrames;

% Preallocate the video frames array for efficiency
videoFrames = zeros(vidObj.Height, vidObj.Width, numFrames, 'uint8');

% Read all frames into a 3D matrix (height, width, frames)
for i = 1:numFrames
    frame = read(vidObj, i);
    grayFrame = im2gray(frame); % Convert to grayscale
    videoFrames(:,:,i) = grayFrame; % Store the grayscale frame
end

% Initialize 'processedFrames' with 'videoFrames'
processedFrames = videoFrames;

% Conditionally display the original video frame if prompt == 1
if prompt == 1
    figure; imshow(processedFrames(:,:,1)); title('Original Grayscale Frame');
end    

% Compute Z-Projection (average intensity) over all frames
avgImage = mean(processedFrames, 3);  % Average intensity projection

% Convert avgImage to uint8 for consistent processing
avgImage = uint8(avgImage);

% Conditionally display the average intensity image if prompt == 1
if prompt == 1
    figure; imshow(avgImage); title('Average Intensity Z-Projection (BG image)');
end

%% Step 2: Flat field correction (Comment out for backlight illumination testing)
% sigmaflatfield = 5;
% 
% %flat field correction
% for i = 1:numFrames
%     imflat=imflatfield(processedFrames(:,:,i),sigmaflatfield);
% end
% figure;imshowpair(videoFrames(:,:,1), imflat, 'montage'); title("orginal and flatfield corrected")

%% Step 3: Background-Subtracted Stack
% Subtract the Z-Projection from each frame with scaling factors k1 and k2

k1 = 1;
k2 = mean(avgImage(:));  % Mean grayscale value of the average image

for i = 1:numFrames
    processedFrames(:,:,i) = (double(processedFrames(:,:,i)) - double(avgImage)) * k1 + k2;
end

% Clip values and convert to uint8 for display
processedFrames = uint8(max(min(processedFrames, 255), 0));

% Conditionally display the background-subtracted frames with a slider if prompt == 1
if prompt == 1
    % --- Slider for Background-Subtracted Frames ---
    % Create a figure with a slider to navigate through the frames
    hFig1 = figure('Name', 'Background-Subtracted Frames');
    hAx1 = axes('Parent', hFig1);
    hImage1 = imshow(processedFrames(:,:,1), 'Parent', hAx1); title('Background-Subtracted Frames');

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

%% Step 4: Median-Subtracted Stack
% Apply a median filter to the background-subtracted stack

% Only proceed if Step 2 is not commented out
if exist('processedFrames', 'var')
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

    % Conditionally display the median-subtracted frames with a slider if prompt == 1
    if prompt == 1
        % --- Slider for Median-Subtracted Frames ---
        hFig2 = figure('Name', 'Median Subtracted Frames');
        hAx2 = axes('Parent', hFig2);
        hImage2 = imshow(processedFrames(:,:,1), 'Parent', hAx2); title('Median Subtracted Frames');

        % Add a slider for frame navigation
        hSlider2 = uicontrol('Style', 'slider', 'Min', 1, 'Max', numFrames, 'Value', 1, ...
            'Units', 'normalized', 'Position', [0.2 0.01 0.6 0.05], ...
            'SliderStep', [1/(numFrames-1), 10/(numFrames-1)]);

        % Add a text label to show the current frame number
        hText2 = uicontrol('Style', 'text', 'String', 'Frame 1', 'Units', 'normalized', ...
            'Position', [0.01 0.01 0.15 0.05]);

        % Update function for the slider
        set(hSlider2, 'Callback', @(src, event) updateFrame(round(get(src, 'Value')), hImage2, processedFrames, hText2));
    end
end

%% Step 5: Manual Contrast Adjustment (Comment out for backlight illumination testing)
% fprintf('Adjusting contrast with manual mapping...\n');
% 
% % Define the lower and upper bounds for contrast stretching
% lower_bound = 110;
% upper_bound = 145;
% 
% % Validate bounds
% if lower_bound >= upper_bound
%     error('lower_bound must be less than upper_bound.');
% end
% 
% % Preallocate adjustedFrames for efficiency
% adjustedFrames = zeros(size(processedFrames), 'uint8');
% 
% % Define scaling factor
% scale = 255 / (upper_bound - lower_bound);
% 
% for i = 1:numFrames
%     frame = processedFrames(:,:,i);
% 
%     % Initialize adjusted frame
%     adjustedFrame = zeros(size(frame), 'uint8');
% 
%     % Pixels below lower_bound set to 0
%     adjustedFrame(frame < lower_bound) = 0;
% 
%     % Pixels above upper_bound set to 255
%     adjustedFrame(frame > upper_bound) = 255;
% 
%     % Pixels within [110, 145] are scaled linearly
%     mask = (frame >= lower_bound) & (frame <= upper_bound);
%     adjustedFrame(mask) = uint8((double(frame(mask)) - lower_bound) * scale);
% 
%     % Update the adjustedFrames matrix
%     adjustedFrames(:,:,i) = adjustedFrame;
% end
% 
% % Replace processedFrames with adjustedFrames
% processedFrames = adjustedFrames;
% 
% % Conditionally display the manually adjusted frames with a slider if prompt == 1
% if prompt == 1
%     % --- Slider for Manually Contrast-Adjusted Frames ---
%     hFig4 = figure('Name', 'Manual Contrast-Adjusted Frames');
%     hAx4 = axes('Parent', hFig4);
%     hImage4 = imshow(processedFrames(:,:,1), 'Parent', hAx4); 
%     title('Manual Contrast-Adjusted Frames');
% 
%     % Add a slider for frame navigation
%     hSlider4 = uicontrol('Style', 'slider', 'Min', 1, 'Max', numFrames, 'Value', 1, ...
%         'Units', 'normalized', 'Position', [0.2 0.01 0.6 0.05], ...
%         'SliderStep', [1/(numFrames-1), 10/(numFrames-1)]);
% 
%     % Add a text label to show the current frame number
%     hText4 = uicontrol('Style', 'text', 'String', 'Frame 1', 'Units', 'normalized', ...
%         'Position', [0.01 0.01 0.15 0.05]);
% 
%     % Update function for the slider
%     set(hSlider4, 'Callback', @(src, event) updateFrame(round(get(src, 'Value')), hImage4, processedFrames, hText4));
% end
%% Step 6: Select masking area

% Read an example image
img = avgImage; % Read Z-projection image

% Create the interactive mask
mask = CreateMask_CAVPTV(img);

% Display the mask
figure;
imshow(mask);
title('Selected Mask');

%% Step 7: Particle Detection Using findMaxima Function on single image (Imagej find maxima logic)

% Only proceed if 'processedFrames' exists
if exist('processedFrames', 'var')
    % Check if 'mask' exists
    if exist('mask', 'var')
        % Ensure 'mask' is a binary mask of the same size as the image
        if ~isequal(size(mask), size(processedFrames, 1, 2))
            error('The mask size must match the first two dimensions of processedFrames.');
        end
    else
        error('The variable ''mask'' does not exist. Please create a binary mask before proceeding.');
    end
    
    % Define operation mode based on 'lightbackground'
    lightbackground = true; % Set to true for light backgrounds (finding minima), false for dark backgrounds (finding maxima)
    
    % Parameters for findMaxima function
    ip = processedFrames(:,:,1);  % First frame of the processed image
    tolerance = 5;                 % Adjust as needed
    strict = false;                % Use strict mode or not
    
    % Set threshold based on 'lightbackground'
    if lightbackground
        threshold = Inf;           % For minima detection: maximum allowed value (-Inf for no threshold on minima)
    else
        threshold = -Inf;          % For maxima detection: minimum allowed value (-Inf for no threshold on maxima)
    end
    
    outputType = 'SINGLE_POINTS';  % Output format
    excludeOnEdges = true;          % Exclude maxima at image edges
    
    % Modify the image to exclude maxima/minima within the mask area
    if lightbackground
        % For minima detection, set mask area pixels to Inf to exclude minima
        ip(mask) = Inf;
    else
        % For maxima detection, set mask area pixels to -Inf to exclude maxima
        ip(mask) = -Inf;
    end
    
    % Call the findMaxima function
    maximaBinary = findMaxima_CAVPTV(ip, tolerance, strict, threshold, lightbackground, outputType, excludeOnEdges);
    
    % Count the number of maxima
    numMaxima = sum(maximaBinary(:));
    fprintf('Number of maxima in first frame: %d\n', numMaxima);
    
    % Get coordinates of maxima
    [yMaxima, xMaxima] = find(maximaBinary);
    
    % Create figure with three images in one column
    figure('Name', 'Particle Detection using findMaxima on First Frame');
    
    % 1. First frame of the input processed image with mask excluded
    subplot(3,1,1);
    imshow(ip, []);
    title('First Frame of Processed Image (Mask Excluded)');
    
    % 2. First frame overlaid with detected particles
    subplot(3,1,2);
    imshow(ip, []);
    hold on;
    plot(xMaxima, yMaxima, 'm+', 'LineWidth', 1, 'MarkerSize', 5);
    hold off;
    title('First Frame with Detected Particles');
    
    % 3. Binary image with maxima points as single white pixels on black background
    subplot(3,1,3);
    imshow(maximaBinary);
    title('Binary Image of Maxima Points');
end

%% Step 8: Particle Detection on the Entire Stack Using findMaxima_CAVPTV

% Check if 'processedFrames' exists
if exist('processedFrames', 'var')
    % Check if 'mask' exists
    if exist('mask', 'var')
        % Validate that 'mask' is a binary matrix
        if ~islogical(mask)
            mask = imbinarize(mask);
            warning('Mask was not binary. It has been binarized using imbinarize.');
        end
    else
        % If mask is not defined, create an empty mask
        mask = false(size(processedFrames, 1), size(processedFrames, 2));
        warning('Mask does not exist. Proceeding without masking.');
    end
    
    % Ensure 'mask' dimensions match the first two dimensions of 'processedFrames'
    if ~isequal(size(mask), size(processedFrames, 1, 2))
        error('The mask size must match the first two dimensions of processedFrames.');
    end
    
    % Parameters for findMaxima_CAVPTV function
    lightbackground = true; % Set to true for light backgrounds (finding minima), false for dark backgrounds (finding maxima)
    tolerance = 5;               % Minimum height difference to consider a maximum/minimum
    strict = false;              % Whether to use strict mode or not
    outputType = 'SINGLE_POINTS'; % Output format: 'SINGLE_POINTS' returns a binary image
    excludeOnEdges = true;         % Whether to exclude maxima/minima at image edges
    
    % Set threshold based on 'lightbackground'
    if lightbackground
        threshold = Inf;         % For minima detection: maximum allowed value (Inf excludes minima in masked areas)
    else
        threshold = -Inf;        % For maxima detection: minimum allowed value (-Inf excludes maxima in masked areas)
    end
       
    % Determine the number of frames
    numFrames = size(processedFrames, 3);
    
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
        
        % Determine the detection type string for display
        if lightbackground
            detectionTypeStr = 'Minima';
        else
            detectionTypeStr = 'Maxima';
        end
        
        fprintf('Frame %d: Number of %s: %d\n', i, detectionTypeStr, numMaxima);
        
        % Get coordinates of maxima/minima
        [yMaxima, xMaxima] = find(maximaBinary);
        maximaCoordinates{i} = [xMaxima, yMaxima];
    end
    
    % Processed Frames with Mask and Detected Points
    % Create a figure for processed frames
    hFig1 = figure('Name', 'Processed Frames with Detected Points', 'NumberTitle', 'off');
    
    % Create axes within the figure
    hAx1 = axes('Parent', hFig1);
    
    % Display the first frame
    imshow(processedFrames(:,:,1), [], 'Parent', hAx1);
    hold(hAx1, 'on');
    
    % Overlay mask boundaries correctly by passing hAx as the first argument
    visboundaries(hAx1, mask, 'Color', 'yellow', 'LineWidth', 1);
    hold(hAx1, 'off');
    
    % Determine the detection type string
    if lightbackground
        detectionTypeStr = 'Minima';
    else
        detectionTypeStr = 'Maxima';
    end
    
    % Set title for the first frame
    title(hAx1, sprintf('Frame 1: %d %s Detected', numMaximaPerFrame(1), detectionTypeStr));
    
    % Overlay detected maxima/minima on the image
    hold(hAx1, 'on');
    plot(hAx1, maximaCoordinates{1}(:,1), maximaCoordinates{1}(:,2), 'm+', 'LineWidth', 1, 'MarkerSize', 5);
    hold(hAx1, 'off');
    
    % Add a slider for frame navigation in Visualization 1
    hSlider1 = uicontrol('Style', 'slider', ...
        'Min', 1, 'Max', numFrames, 'Value', 1, ...
        'Units', 'normalized', ...
        'Position', [0.2 0.05 0.6 0.05], ...
        'SliderStep', [1/(numFrames-1), 10/(numFrames-1)], ...
        'Callback', @(src, event) updateFrameWithMask(round(get(src, 'Value')), maximaStack, maximaCoordinates, processedFrames, mask, hAx1, lightbackground));
    
    % Add a text label to show the current frame number and count in Visualization 1
    hText1 = uicontrol('Style', 'text', ...
        'String', sprintf('Frame 1/%d: %d %s Detected', numFrames, numMaximaPerFrame(1), detectionTypeStr), ...
        'Units', 'normalized', ...
        'Position', [0.81 0.05 0.18 0.05], ...
        'HorizontalAlignment', 'left');
end

% Binary Image Stack

% Check if 'maximaStack' and 'numMaximaPerFrame' exist
if exist('maximaStack', 'var') && exist('numMaximaPerFrame', 'var')
    % --- Slider for Maxima Binary Stack ---
    % Create a figure with a slider to navigate through the maxima binary frames
    hFig5 = figure('Name', 'Maxima Binary Frames');
    hAx5 = axes('Parent', hFig5);
    hImage5 = imshow(maximaStack(:,:,1)); title('Maxima Binary Frames');

    % Add a slider for frame navigation
    hSlider5 = uicontrol('Style', 'slider', 'Min', 1, 'Max', numFrames, 'Value', 1, ...
        'Units', 'normalized', 'Position', [0.2 0.01 0.6 0.05], ...
        'SliderStep', [1/(numFrames-1), 10/(numFrames-1)]);

    % Add a text label to show the current frame number
    hText5 = uicontrol('Style', 'text', 'String', 'Frame 1', 'Units', 'normalized', ...
        'Position', [0.01 0.01 0.15 0.05]);

    % Update function for the slider (using existing updateFrame function)
    set(hSlider5, 'Callback', @(src, event) updateFrame(round(get(src, 'Value')), hImage5, maximaStack, hText5));
end



%% Section 9: Statistics

% Ensure that 'numMaximaPerFrame' and 'numFrames' variables exist
if exist('numMaximaPerFrame', 'var') && exist('numFrames', 'var')
    % Calculate Mean Number of Particles per Frame
    meanParticles = mean(numMaximaPerFrame);
    
    % Calculate Standard Deviation of Particles per Frame
    stdParticles = std(numMaximaPerFrame);
    
    % Calculate Seeding Density (particles per unit area)
    % Assuming each pixel represents one unit area
    [imgHeight, imgWidth, ~] = size(processedFrames);
    frameArea = imgHeight * imgWidth; % Adjust if pixel size is different
    seedingDensity = meanParticles / frameArea;
    
    % Calculate Coefficient of Variation (Uncertainty Measure)
    coeffVariation = stdParticles / meanParticles;
    
    % Compile Statistics into a Struct for Easy Access
    statistics.meanParticles = meanParticles;
    statistics.stdParticles = stdParticles;
    statistics.seedingDensity = seedingDensity;
    statistics.coeffVariation = coeffVariation;
    
    % Additional Statistics (Optional)
    statistics.minParticles = min(numMaximaPerFrame);
    statistics.maxParticles = max(numMaximaPerFrame);
    
    % Display Statistics in Command Window
    fprintf('\n--- Particle Detection Statistics ---\n');
    fprintf('Mean Number of Particles per Frame: %.2f\n', meanParticles);
    fprintf('Standard Deviation: %.2f\n', stdParticles);
    fprintf('Seeding Density (particles/unit area): %.6f\n', seedingDensity);
    fprintf('Coefficient of Variation (Uncertainty): %.2f%%\n', coeffVariation * 100);
    fprintf('Minimum Number of Particles in a Frame: %d\n', statistics.minParticles);
    fprintf('Maximum Number of Particles in a Frame: %d\n', statistics.maxParticles);
    fprintf('--------------------------------------\n');
else
    warning('Variables ''numMaximaPerFrame'' and/or ''numFrames'' do not exist.');
end

% Ensure that 'numMaximaPerFrame' and 'statistics' variables exist
if exist('numMaximaPerFrame', 'var') && exist('statistics', 'var')
    
    % ----------------------------
    % 1. Histogram of Particle Counts
    % ----------------------------
    figure('Name', 'Histogram of Particle Counts', 'NumberTitle', 'off');
    histogram(numMaximaPerFrame, 'BinWidth', 1, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k');
    xlabel('Number of Particles per Frame', 'FontSize', 12);
    ylabel('Frequency', 'FontSize', 12);
    title('Distribution of Detected Particles Across Frames', 'FontSize', 10);
    grid off;
    
    % ----------------------------
    % 2. Time Series of Particle Counts
    % ----------------------------
    figure('Name', 'Time Series of Particle Counts', 'NumberTitle', 'off');
    plot(1:numFrames, numMaximaPerFrame, '-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'Color', [0.8 0.2 0.2]);
    xlabel('Frame Number', 'FontSize', 12);
    ylabel('Number of Particles', 'FontSize', 12);
    title('Temporal Variation of Detected Particles', 'FontSize', 10);
    grid off;
    
    % ----------------------------
    % 3. Seeding Density Over Frames
    % ----------------------------
    figure('Name', 'Seeding Density Over Frames', 'NumberTitle', 'off');
    seedingDensityPerFrame = numMaximaPerFrame / (imgHeight * imgWidth);
    plot(1:numFrames, seedingDensityPerFrame, '-s', 'LineWidth', 1.5, 'MarkerSize', 4, 'Color', [0.2 0.8 0.2]);
    xlabel('Frame Number', 'FontSize', 12);
    ylabel('Seeding Density (particles/unit area)', 'FontSize', 12);
    title('Seeding Density Across Frames', 'FontSize', 10);
    grid off;
    
    % ----------------------------
    % 4. Histogram of Seeding Density
    % ----------------------------
    figure('Name', 'Histogram of Seeding Density', 'NumberTitle', 'off');
    histogram(seedingDensityPerFrame, 30, 'FaceColor', [0.5 0.2 0.8], 'EdgeColor', 'k');
    xlabel('Seeding Density (particles/unit area)', 'FontSize', 12);
    ylabel('Frequency', 'FontSize', 12);
    title('Distribution of Seeding Density Across Frames', 'FontSize', 10);
    grid off;
       
else
    warning('Variables ''numMaximaPerFrame'' and/or ''statistics'' do not exist.');
end

%% Section 10: Interactive Data Saving

% Check if 'statistics' and 'meanParticles' variables exist
if exist('statistics', 'var') && isfield(statistics, 'meanParticles')
    
    % Prompt user to select a folder for saving the data
    promptMessage = 'Select the folder where you want to save the statistics data.';
    titleBarCaption = 'Select Folder to save the results';
    defaultFolder = pwd; % Current directory as default
    saveFolder = uigetdir(defaultFolder, titleBarCaption);
    
    % Check if user canceled the folder selection
    if saveFolder == 0
        disp('Folder selection canceled. Data not saved.');
    else
        % Define the filename with timestamp to avoid overwriting
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        filename = fullfile(saveFolder, ['ParticleDetectionStatistics_' timestamp '.mat']);
        
        % Save the statistics struct
        save(filename, 'statistics', 'numMaximaPerFrame', 'maximaCoordinates', 'maximaStack');
        
        fprintf('Data successfully saved to:\n%s\n', filename);
    end
else
    warning('Variables ''statistics'' and/or ''meanParticles'' do not exist. Data not saved.');
end

%% Step 11: Save Maxima Binary Frames as Grayscale AVI File
% 
% % Prompt the user to specify the save directory
% save_dir = uigetdir('', 'Select Save Directory to Save the Video');
% 
% % Check if the user canceled the dialog
% if save_dir == 0
%     disp('User canceled the save directory selection.');
% else
%     % Specify the output video filename
%     outputVideoFile = fullfile(save_dir, 'single maxima points test.avi');
% 
%     % Create a VideoWriter object with grayscale format
%     outputVideo = VideoWriter(outputVideoFile, 'Grayscale AVI');
% 
%     % Set the frame rate (optional, can set it to match the input video)
%     outputVideo.FrameRate = vidObj.FrameRate;
% 
%     % Open the VideoWriter object
%     open(outputVideo);
% 
%     % Write each frame to the video file
%     for i = 1:numFrames
%         % Get the current binary frame from maximaStack
%         frame = maximaStack(:,:,i);
% 
%         % Convert logical frame to uint8 format (0 or 255)
%         frame_uint8 = uint8(frame) * 255;
% 
%         % Write the frame to the video
%         writeVideo(outputVideo, frame_uint8);
%     end
% 
%     % Close the VideoWriter object
%     close(outputVideo);
% 
%     disp(['Maxima binary frames video saved to ', outputVideoFile]);
% end
% 
% 
%     % Nested Helper Functions
%     function createSliderFigure(titleStr, frames, numFrames)
%         % Helper function to create a figure with a slider for frame navigation
%         hFig = figure('Name', titleStr);
%         hAx = axes('Parent', hFig);
%         hImage = imshow(frames(:,:,1), 'Parent', hAx, []); 
%         title(titleStr);
% 
%         % Add a slider for frame navigation
%         hSlider = uicontrol('Style', 'slider', 'Min', 1, 'Max', numFrames, 'Value', 1, ...
%             'Units', 'normalized', 'Position', [0.2 0.01 0.6 0.05], ...
%             'SliderStep', [1/(numFrames-1), 10/(numFrames-1)]);
% 
%         % Add a text label to show the current frame number
%         hText = uicontrol('Style', 'text', 'String', 'Frame 1', 'Units', 'normalized', ...
%             'Position', [0.01 0.01 0.15 0.05]);
% 
%         % Update function for the slider
%         set(hSlider, 'Callback', @(src, event) updateFrame(round(get(src, 'Value')), hImage, frames, hText));
%     end
% 
%     function updateFrame(frameNumber, hImage, processedFrames, hText)
%     % Update the image and text based on the slider value
%     set(hImage, 'CData', processedFrames(:,:,frameNumber));
%     set(hText, 'String', sprintf('Frame %d', frameNumber));
%     end
%%

%Helper Functions

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

function updateBinaryFrame(frameIdx, maximaStack, numMaximaPerFrame, hAx, lightbackground)
    % updateBinaryFrame Updates the displayed binary maxima/minima image
    %
    % Parameters:
    % - frameIdx: Index of the current frame to display
    % - maximaStack: Binary stack of detected maxima/minima
    % - numMaximaPerFrame: Array containing the number of maxima/minima per frame
    % - hAx: Handle to the axes where image is displayed
    % - lightbackground: Boolean indicating detection mode

    % Validate frame index
    if frameIdx < 1 || frameIdx > size(maximaStack, 3)
        warning('Frame index out of bounds.');
        return;
    end

    % Clear existing image
    cla(hAx);

    % Display the binary maxima/minima image
    imshow(maximaStack(:,:,frameIdx), 'Parent', hAx);

    % Determine the detection type string
    if lightbackground
        detectionTypeStr = 'Minima';
    else
        detectionTypeStr = 'Maxima';
    end

    % Set title for the current frame
    numMaxima = sum(maximaStack(:,:,frameIdx), 'all');
    title(hAx, sprintf('Frame %d: %d %s Detected', frameIdx, numMaxima, detectionTypeStr));

    % Update the text label
    hFig = ancestor(hAx, 'figure');
    children = get(hFig, 'Children');
    hText = findobj(children, 'Style', 'text');
    if ~isempty(hText)
        set(hText, 'String', sprintf('Frame %d/%d: %d %s Detected', frameIdx, size(maximaStack,3), numMaxima, detectionTypeStr));
    end
end

function updateFrame(frameNumber, hImage, processedFrames, hText)
% Update the image and text based on the slider value
set(hImage, 'CData', processedFrames(:,:,frameNumber));
set(hText, 'String', sprintf('Frame %d', frameNumber));
end