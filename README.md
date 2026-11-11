# Seeding Density Analysis (Cavitation PTV)

MATLAB scripts for detecting tracer particles in high-speed video and quantifying how
seeding density affects particle detection, matching rate and position uncertainty.

## Requirements

| Requirement | Notes |
|---|---|
| MATLAB **R2020b or newer** | Needs `im2gray` (R2020b). Developed/checked with R2025a. |
| Image Processing Toolbox | `medfilt2`, `poly2mask`, `drawpolygon`, `visboundaries`, `imbinarize`, `im2gray`, `imshow` |
| Statistics and Machine Learning Toolbox | `pdist2` (tracking), `boxplot` (comparison plots) |

No other third-party code or Python/Java dependencies. The scripts are interactive
(file/folder dialogs, a polygon-drawing mask tool), so they need a desktop MATLAB session.

## Files

| File | Type | Purpose |
|---|---|---|
| `Seeding_detection_main.m` | script | Single-video pipeline: background subtraction, median subtraction, mask, particle detection on every frame, per-video statistics and plots. |
| `compare_detection_counts.m` | script | Multi-video batch: detected particles per frame for each video, line plot and box plot comparison. |
| `seeding_density_tracking_analysis.m` | script | Multi-video batch: detection plus nearest-neighbour frame-to-frame matching. Computes seeding density (particles/pixel), matching rate, position error and uncertainty; saves `PlotVariables.mat` and plots. |
| `CreateMask_CAVPTV.m` | function | Interactive polygon mask tool. Called by all three scripts. |
| `findMaxima_CAVPTV.m` | function | MATLAB port of ImageJ's *Find Maxima* (`MaximumFinder`). Called by all three scripts. |

## Usage

1. Put all `.m` files in the same folder (or add the folder to the MATLAB path).
2. Run one of the scripts, e.g. `seeding_density_tracking_analysis`.
3. Pick one or more videos (`.avi`, `.mp4`, `.mov`) and the number of frames to analyze.
4. Draw the mask polygon on the averaged frame: click vertices, press Enter, drag to adjust, press Enter again.
5. Choose output folders when prompted.

Key parameters live near the top of each detection section: `tolerance` (prominence
threshold for a particle), `lightbackground` (`true` detects dark particles on a bright
background), and `maxDisplacement` (matching radius in pixels, tracking script only).

## Processing pipeline

1. Average all frames, giving a background image, and subtract it from each frame.
2. Subtract a 10x10 median-filtered copy to flatten low-frequency intensity variation.
3. Mask out the region of no interest.
4. Detect local minima/maxima with `findMaxima_CAVPTV`.
5. Seeding density = mean particles per frame / unmasked pixels.

## Acknowledgements

`findMaxima_CAVPTV.m` reimplements the logic of the ImageJ/Fiji *Find Maxima* function
(`ij.plugin.filter.MaximumFinder`, Michael Schmid et al.).
