function mask = CreateMask_CAVPTV(image)
    %---------------------------------------------------------------------%
    %   CreateMask_CAVPTV Allows user to interactively select an 
    %   area on an image and creates a binary mask.
    %
    %   mask = createInteractiveMask(image)
    %
    %   Input:
    %   - image: Input image (2D grayscale or 3D RGB array).
    %
    %   Output:
    %   - mask: Binary mask with the selected area as white (1) and the rest as black (0).
    %
    %   Usage Example:
    %   img = imread('sample_image.png');
    %   selectedMask = CreateMask_CAVPTV(img);
    %
    %   Instructions:
    %   - Click on the image to select the vertices of the area.
    %   - A thin plus '+' will indicate each selected point.
    %   - Press the Enter key to finish the selection.
    %   - After selection, you can drag points to adjust the area.
    %   - Press the Enter key again to finalize and create the mask.

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 % Validate input
    if nargin < 1
        error('Please provide an image as an input argument.');
    end

    % Convert to grayscale if the image is RGB
    if ndims(image) == 3
        image = rgb2gray(image);
    end

    % Display instructions
    fprintf('Instructions:\n');
    fprintf('1. Click on the image to select the vertices of the area.\n');
    fprintf('2. A thin plus ''+'' will indicate each selected point.\n');
    fprintf('3. Press the Enter key to finish the selection.\n');
    fprintf('4. After selection, you can drag points to adjust the area.\n');
    fprintf('5. Press the Enter key again to finalize and create the mask.\n');

    % Create figure and display image
    hFig = figure('Name', 'Interactive Mask Selection', 'NumberTitle', 'off');
    imshow(image, []);
    title('Select Area: Click to add points, press Enter to finish.');
    hold on; % Allow overlaying plots

    % Initialize variables
    points = [];          % Stores the (x, y) coordinates of selected points

    % Set the key press callback for finishing the selection
    set(hFig, 'KeyPressFcn', @keyPressCallback);

    % Use waitfor to pause execution until the user presses Enter
    userFinished = false;
    while ~userFinished
        % Get user input for polygon selection
        hPoly = drawpolygon('LineWidth', 1, 'Color', 'r', 'MarkerSize', 8, ...
            'InteractionsAllowed', 'all', 'FaceAlpha', 0);
        % Wait for the user to finish drawing
        wait(hPoly);

        % Get the position of the polygon vertices
        points = hPoly.Position;

        % Plot thin plus markers at each vertex
        plot(points(:,1), points(:,2), 'r+', 'MarkerSize', 8, 'LineWidth', 1);

        % Update title and instructions for adjustment
        title('Adjust Points: Drag to adjust, press Enter to finalize.');
        fprintf('Adjust the points if necessary by dragging them.\n');
        fprintf('Press the Enter key to finalize and create the mask.\n');

        % Wait for the user to press Enter to finalize
        uiwait(hFig);
        userFinished = true;
    end

    % Close the figure after selection
    if isvalid(hFig)
        close(hFig);
    end

    % Check if any points were selected
    if isempty(points)
        warning('No points were selected. Returning an empty mask.');
        mask = false(size(image));
        return;
    end

    % Create the binary mask using poly2mask
    % poly2mask expects the x and y coordinates separately
    x = points(:,1);
    y = points(:,2);
    mask = poly2mask(x, y, size(image,1), size(image,2));

    %% Nested Callback Function for Key Press
    function keyPressCallback(~, event)
        % Callback function to handle key presses in the figure

        if strcmp(event.Key, 'return') || strcmp(event.Key, 'enter')
            % User pressed Enter key
            uiresume(hFig);
        end
    end
end