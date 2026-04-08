%{
--------------------------------------------------------------------------
FUNCTION NAME: figures_compare_filtered_signals

DESCRIPTION: 
    Generates a publication-quality figure comparing filtered signals from
    baseline (Control) and treatment (e.g. DOI) recordings side-by-side.
    Displays selected channels stacked vertically for the full recording.
    All datasets are listed; user sets controlDataset, treatmentDataset,
    channelIndices, and labelNames in the script.

INPUTS:
    None - Set variables in the script: controlDataset, treatmentDataset,
    channelIndices, labelNames, outputPath

OUTPUTS:
    Figure saved as high-resolution PNG file
-------------------------------------------------------------------------
%}
function figures_compare_filtered_signals()

% ========== USER-SET VARIABLES (edit these) ==========
controlDataset = 'IdoControl-231101-150512_#3';   % Baseline dataset name
treatmentDataset = 'IdoKetanserin-231101-140237_#3';     % Treatment dataset name (e.g. DOI)
channelIndices = [35,37,23,24,25,36,30,31,45,33];  % Channels to display
labelNames = {'Baseline', 'DOI'};  % Labels for left and right columns
outputPath = '/Users/bkutler4/Desktop/hai_lab/pipeline/figures';

% All datasets (for reference; change controlDataset/treatmentDataset above)
% Control 1 (230914):
%   'IdoControl-230914-130200_#1','IdoControl-230914-131548_#2','IdoControl-230914-132855_#3','IdoControl-230914-154022_#4','IdoControl-230914-155318_#5','IdoControl-230914-160601_#6'
% DOI (230914):
%   'IdoDOI-230914-142502_#1','IdoDOI-230914-143740_#2','IdoDOI-230914-144945_#3','IdoDOI-230914-161838_#4','IdoDOI-230914-163140_#5','IdoDOI-230914-164512_#6'
% Control 2 (231101):
%   'IdoControl-231101-144046_#1','IdoControl-231101-145330_#2','IdoControl-231101-150512_#3'
% Ketanserin (231101):
%   'IdoKetanserin-231101-133725_#1','IdoKetanserin-231101-134946_#2','IdoKetanserin-231101-140237_#3'
% =====================================================

% Input validation
if isempty(channelIndices)
    error('channelIndices must not be empty');
end
if length(labelNames) ~= 2
    error('labelNames must contain exactly 2 strings: {leftLabel, rightLabel}');
end

% Create output directory if it doesn't exist
if ~exist(outputPath, 'dir')
    mkdir(outputPath);
end

% Define paths
SDKPATH = '/Users/bkutler4/Desktop/hai_lab/TDTMatlabSDK';
addpath(genpath(SDKPATH));
BASEPATH = '/Users/bkutler4/Desktop/hai_lab/data';

% Processing parameters (matching process_data.m)
STORE = 'Wav1';
BP_FILTER = [300 2500];
max_harmonic = 780;
notch_base = 60;
Q = 35;

% Determine if inputs are workspace variable names or dataset folder names
controlPath = getDatasetPath(controlDataset, BASEPATH);
treatmentPath = getDatasetPath(treatmentDataset, BASEPATH);

% Validate dataset paths
if ~exist(controlPath, 'dir')
    error('Control dataset not found: %s\nIf using workspace variable, make sure processed data exists.', controlPath);
end
if ~exist(treatmentPath, 'dir')
    error('Treatment dataset not found: %s\nIf using workspace variable, make sure processed data exists.', treatmentPath);
end

fprintf('Loading and filtering data for %d channels...\n', length(channelIndices));

% Initialize storage for filtered signals
controlSignals = cell(length(channelIndices), 1);
treatmentSignals = cell(length(channelIndices), 1);
fs_control = [];
fs_treatment = [];
time_control = [];
time_treatment = [];

% Load and filter control data
for i = 1:length(channelIndices)
    ch = channelIndices(i);
    fprintf('Processing control channel %d...\n', ch);
    
    rawData = TDTbin2mat(controlPath, 'STORE', STORE, 'CHANNEL', ch);
    fs = rawData.streams.(STORE).fs;
    x = double(rawData.streams.(STORE).data(:));
    
    % Notch filter 60 Hz harmonics (zero-phase)
    for f0 = notch_base:notch_base:max_harmonic
        if f0 < fs/2
            [B,A] = designNotchPeakIIR( ...
                Response="notch", ...
                CenterFrequency=f0/(fs/2), ...
                QualityFactor=Q);
            x = filtfilt(B, A, x);
        end
    end
    
    % Bandpass 300–2500 Hz (zero-phase)
    [bp_b,bp_a] = butter(4, BP_FILTER/(fs/2), 'bandpass');
    x = filtfilt(bp_b,bp_a,x);
    
    controlSignals{i} = x * 1e6; % Convert to µV
    
    if i == 1
        fs_control = fs;
        nSamples = length(x);
        time_control = (0:nSamples-1) / fs;
    end
end

% Load and filter treatment data
for i = 1:length(channelIndices)
    ch = channelIndices(i);
    fprintf('Processing treatment channel %d...\n', ch);
    
    rawData = TDTbin2mat(treatmentPath, 'STORE', STORE, 'CHANNEL', ch);
    fs = rawData.streams.(STORE).fs;
    x = double(rawData.streams.(STORE).data(:));
    
    % Notch filter 60 Hz harmonics (zero-phase)
    for f0 = notch_base:notch_base:max_harmonic
        if f0 < fs/2
            [B,A] = designNotchPeakIIR( ...
                Response="notch", ...
                CenterFrequency=f0/(fs/2), ...
                QualityFactor=Q);
            x = filtfilt(B, A, x);
        end
    end
    
    % Bandpass 300–2500 Hz (zero-phase)
    [bp_b,bp_a] = butter(4, BP_FILTER/(fs/2), 'bandpass');
    x = filtfilt(bp_b,bp_a,x);
    
    treatmentSignals{i} = x * 1e6; % Convert to µV
    
    if i == 1
        fs_treatment = fs;
        nSamples = length(x);
        time_treatment = (0:nSamples-1) / fs;
    end
end

fprintf('Creating figure...\n');

% Zoom window duration (s) and time scale bar lengths
zoomDuration = 30;
scaleBarZoom = 10;   % horizontal bar length under zoom panels
scaleBarFull = 60;   % horizontal bar length under full panels
% Time scale bar line weights (horizontal bar and end caps)
xScaleBarLineWidth = 4.5;
xScaleBarCapWidth = 3.5;
% Font sizes: voltage scale (right) and time scale (below panels) use same size
scaleBarFontSize = 21;

% Figure width (pixels and paper): room for traces + voltage scale bars/labels in the right margin
figPosWidth = 2400;
figPaperWidth = 22;
% Normalized gap between end of baseline full panel and start of DOI zoom (clearer block separation)
midGapBaselineDOI = 0.035;

% Create figure with publication-quality settings (wider for four panels + scale bars + µV labels)
fig = figure('Visible', 'off', 'Position', [100, 100, figPosWidth, 1000], 'Color', 'w');
set(fig, 'Units', 'inches');
set(fig, 'PaperUnits', 'inches');
set(fig, 'PaperSize', [figPaperWidth, 10]);
set(fig, 'PaperPosition', [0, 0, figPaperWidth, 10]);

% Channel layout: row height (trace vertical span) and spacing
boxHalfHeight = 250;      % Half-height of each trace; larger = bigger appearance per channel
channelGap = -95;         % More negative = rows closer (overlap); tune with boxHalfHeight
channelOffset = 2 * boxHalfHeight + channelGap;  % Center-to-center distance

% Calculate y-positions for each channel (stacked from top to bottom)
nChannels = length(channelIndices);
yPositions = zeros(nChannels, 1);
for i = 1:nChannels
    yPositions(i) = (nChannels - i) * channelOffset;
end

% Bottom of bottom trace box; time scale bar just below it
bottomBoxBottom = min(yPositions) - boxHalfHeight;
scaleBarY = bottomBoxBottom - 15;
xScaleLabelOffset = 12;   % data units below time scale bar for time labels
yLimMin = scaleBarY - xScaleLabelOffset - 22;
yLimMax = max(yPositions) + boxHalfHeight + 25;

% Index for first 30 s (or full if recording shorter)
maxTimeControl = max(time_control);
maxTimeTreatment = max(time_treatment);
idxControlZoom = time_control <= min(zoomDuration, maxTimeControl);
idxTreatmentZoom = time_treatment <= min(zoomDuration, maxTimeTreatment);

% Per-channel largest absolute value A_i (over the four signals) for symmetric box scaling
maxAbs = zeros(nChannels, 1);
for i = 1:nChannels
    s1 = controlSignals{i}(idxControlZoom);
    s2 = controlSignals{i};
    s3 = treatmentSignals{i}(idxTreatmentZoom);
    s4 = treatmentSignals{i};
    A_i = max([max(abs(s1)), max(abs(s2)), max(abs(s3)), max(abs(s4))]);
    if A_i < 1, A_i = 20; end
    maxAbs(i) = A_i;
end

% ----- Panel 1: Baseline zoom (first 30 s) -----
ax_baseline_zoom = axes('Position', [0.12, 0.06, 0.095, 0.88]);
hold on;
for i = 1:nChannels
    signal = controlSignals{i};
    time_zoom = time_control(idxControlZoom);
    signal_zoom = signal(idxControlZoom);
    downsample_factor = max(1, floor(length(signal_zoom) / 15000));
    time_plot = time_zoom(1:downsample_factor:end);
    signal_plot = signal_zoom(1:downsample_factor:end);
    A_i = maxAbs(i);
    if A_i > 0
        y_plot = yPositions(i) + (signal_plot / A_i) * boxHalfHeight;
    else
        y_plot = yPositions(i) + 0 * signal_plot;
    end
    plot(time_plot, y_plot, 'Color', [0, 0, 0], 'LineWidth', 0.65);
end
xlim([0, min(zoomDuration, maxTimeControl)]);
ylim([yLimMin, yLimMax]);
ylabel('Voltage (µV)', 'FontSize', 11, 'FontName', 'Arial');
set(gca, 'XTick', [], 'XTickLabel', [], 'YTick', [], 'YTickLabel', []);
set(gca, 'FontSize', 10, 'FontName', 'Arial', 'TickDir', 'out', 'XColor', 'none', 'YColor', 'none');
box off; grid off;
% Time scale bar under zoom (aligned to trace start at x=0)
plot([0, scaleBarZoom], [scaleBarY, scaleBarY], 'k-', 'LineWidth', xScaleBarLineWidth);
plot([0, 0], [scaleBarY - 6, scaleBarY + 6], 'k-', 'LineWidth', xScaleBarCapWidth);
plot([scaleBarZoom, scaleBarZoom], [scaleBarY - 6, scaleBarY + 6], 'k-', 'LineWidth', xScaleBarCapWidth);
text(scaleBarZoom/2, scaleBarY - xScaleLabelOffset, '10 s', 'FontSize', scaleBarFontSize, 'FontName', 'Arial', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');

% ----- Panel 2: Baseline full -----
ax_baseline_full = axes('Position', [0.225, 0.06, 0.29, 0.88]);
hold on;
for i = 1:nChannels
    signal = controlSignals{i};
    downsample_factor = max(1, floor(length(signal) / 50000));
    time_plot = time_control(1:downsample_factor:end);
    signal_plot = signal(1:downsample_factor:end);
    A_i = maxAbs(i);
    if A_i > 0
        y_plot = yPositions(i) + (signal_plot / A_i) * boxHalfHeight;
    else
        y_plot = yPositions(i) + 0 * signal_plot;
    end
    plot(time_plot, y_plot, 'Color', [0, 0, 0], 'LineWidth', 0.65);
end
xlim([0, maxTimeControl]);
ylim([yLimMin, yLimMax]);
set(gca, 'XTick', [], 'XTickLabel', [], 'YTick', [], 'YTickLabel', []);
set(gca, 'FontSize', 10, 'FontName', 'Arial', 'TickDir', 'out', 'XColor', 'none', 'YColor', 'none');
box off; grid off;
% Time scale bar on full trace (aligned to trace start at x=0)
plot([0, scaleBarFull], [scaleBarY, scaleBarY], 'k-', 'LineWidth', xScaleBarLineWidth);
plot([0, 0], [scaleBarY - 6, scaleBarY + 6], 'k-', 'LineWidth', xScaleBarCapWidth);
plot([scaleBarFull, scaleBarFull], [scaleBarY - 6, scaleBarY + 6], 'k-', 'LineWidth', xScaleBarCapWidth);
text(scaleBarFull/2, scaleBarY - xScaleLabelOffset, '60 s', 'FontSize', scaleBarFontSize, 'FontName', 'Arial', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');

% ----- Panel 3: Treatment (DOI) zoom -----
% Leave midGapBaselineDOI space after baseline full so Baseline vs DOI blocks are visually distinct
ax_treatment_zoom = axes('Position', [0.225 + 0.29 + midGapBaselineDOI, 0.06, 0.095, 0.88]);
hold on;
for i = 1:nChannels
    signal = treatmentSignals{i};
    time_zoom = time_treatment(idxTreatmentZoom);
    signal_zoom = signal(idxTreatmentZoom);
    downsample_factor = max(1, floor(length(signal_zoom) / 15000));
    time_plot = time_zoom(1:downsample_factor:end);
    signal_plot = signal_zoom(1:downsample_factor:end);
    A_i = maxAbs(i);
    if A_i > 0
        y_plot = yPositions(i) + (signal_plot / A_i) * boxHalfHeight;
    else
        y_plot = yPositions(i) + 0 * signal_plot;
    end
    plot(time_plot, y_plot, 'Color', [0, 0, 0], 'LineWidth', 0.65);
end
xlim([0, min(zoomDuration, maxTimeTreatment)]);
ylim([yLimMin, yLimMax]);
set(gca, 'XTick', [], 'XTickLabel', [], 'YTick', [], 'YTickLabel', []);
set(gca, 'FontSize', 10, 'FontName', 'Arial', 'TickDir', 'out', 'XColor', 'none', 'YColor', 'none');
box off; grid off;
plot([0, scaleBarZoom], [scaleBarY, scaleBarY], 'k-', 'LineWidth', xScaleBarLineWidth);
plot([0, 0], [scaleBarY - 6, scaleBarY + 6], 'k-', 'LineWidth', xScaleBarCapWidth);
plot([scaleBarZoom, scaleBarZoom], [scaleBarY - 6, scaleBarY + 6], 'k-', 'LineWidth', xScaleBarCapWidth);
text(scaleBarZoom/2, scaleBarY - xScaleLabelOffset, '10 s', 'FontSize', scaleBarFontSize, 'FontName', 'Arial', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');

% ----- Panel 4: Treatment (DOI) full -----
ax_treatment_full = axes('Position', [0.225 + 0.29 + midGapBaselineDOI + 0.095 + 0.015, 0.06, 0.27, 0.88]);
hold on;
for i = 1:nChannels
    signal = treatmentSignals{i};
    downsample_factor = max(1, floor(length(signal) / 50000));
    time_plot = time_treatment(1:downsample_factor:end);
    signal_plot = signal(1:downsample_factor:end);
    A_i = maxAbs(i);
    if A_i > 0
        y_plot = yPositions(i) + (signal_plot / A_i) * boxHalfHeight;
    else
        y_plot = yPositions(i) + 0 * signal_plot;
    end
    plot(time_plot, y_plot, 'Color', [0, 0, 0], 'LineWidth', 0.65);
end
xlim([0, maxTimeTreatment]);
ylim([yLimMin, yLimMax]);
set(gca, 'XTick', [], 'XTickLabel', [], 'YTick', [], 'YTickLabel', []);
set(gca, 'FontSize', 10, 'FontName', 'Arial', 'TickDir', 'out', 'XColor', 'none', 'YColor', 'none');
box off; grid off;
plot([0, scaleBarFull], [scaleBarY, scaleBarY], 'k-', 'LineWidth', xScaleBarLineWidth);
plot([0, 0], [scaleBarY - 6, scaleBarY + 6], 'k-', 'LineWidth', xScaleBarCapWidth);
plot([scaleBarFull, scaleBarFull], [scaleBarY - 6, scaleBarY + 6], 'k-', 'LineWidth', xScaleBarCapWidth);
text(scaleBarFull/2, scaleBarY - xScaleLabelOffset, '60 s', 'FontSize', scaleBarFontSize, 'FontName', 'Arial', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');

% Enforce zoom panels to show only first 30 s on horizontal axis
set(ax_baseline_zoom, 'XLim', [0, min(30, maxTimeControl)]);
set(ax_treatment_zoom, 'XLim', [0, min(30, maxTimeTreatment)]);

% ----- Per-channel voltage scale bars (right margin, past traces): full box height = 2*A_i µV -----
axPos = get(ax_baseline_zoom, 'Position');
axRight = get(ax_treatment_full, 'Position');
rightEdgeTraces = axRight(1) + axRight(3);   % normalized: right edge of rightmost axes
marginBar = 0.012;                           % gap between trace area and vertical scale bar
barCenterX = rightEdgeTraces + marginBar;    % vertical line sits in figure margin, not over data
barHalfLen = 0.006;
voltLabelNormHeight = 0.032;
textGapFromBar = 0.004;
voltLabelNormWidth = min(0.055, 0.998 - (barCenterX + textGapFromBar));
for i = 1:nChannels
    ampRound = round(2 * maxAbs(i) / 20) * 20;
    if ampRound < 20, ampRound = 20; end
    yn = axPos(2) + axPos(4) * (yPositions(i) - yLimMin) / (yLimMax - yLimMin);
    annotation(fig, 'line', [barCenterX, barCenterX], [yn - barHalfLen, yn + barHalfLen], 'Color', 'k', 'LineWidth', 2);
    annotation(fig, 'textbox', [barCenterX + textGapFromBar, yn - voltLabelNormHeight/2, voltLabelNormWidth, voltLabelNormHeight], ...
        'String', sprintf('%d µV', ampRound), ...
        'FontSize', scaleBarFontSize, 'FontName', 'Arial', 'FontWeight', 'bold', 'EdgeColor', 'none', ...
        'VerticalAlignment', 'middle', 'Interpreter', 'none', 'FitBoxToText', 'on');
end

% Save figure
filename = sprintf('filtered_signals_comparison_%s_vs_%s.png', ...
    strrep(controlDataset, '-', '_'), strrep(treatmentDataset, '-', '_'));
fullPath = fullfile(outputPath, filename);

% Export at high resolution (300 DPI)
try
    % Use exportgraphics if available (MATLAB R2020a+)
    exportgraphics(fig, fullPath, 'Resolution', 300);
catch
    % Fallback for older MATLAB versions
    set(fig, 'PaperPositionMode', 'auto');
    print(fig, fullPath, '-dpng', '-r300');
end
close(fig);

fprintf('Figure saved to: %s\n', fullPath);

end

% Helper function to get dataset path from either workspace variable or folder name
function datasetPath = getDatasetPath(input, basePath)
    % Check if input looks like a workspace variable name (starts with 'processedData_')
    if contains(input, 'processedData_')
        % Extract dataset name from workspace variable
        varName = input;
        
        % Check if variable exists in workspace
        if ~evalin('base', sprintf('exist(''%s'', ''var'')', varName))
            error('Workspace variable not found: %s\nRun figures_process_data.m first.', varName);
        end
        
        % Get the processed data structure
        processedData = evalin('base', varName);
        
        % Extract BLOCKPATH from the structure
        if isfield(processedData, 'BLOCKPATH')
            datasetPath = processedData.BLOCKPATH;
        elseif isfield(processedData, 'ENDPATH')
            % Reconstruct path from ENDPATH
            datasetPath = fullfile(basePath, processedData.ENDPATH);
        else
            error('Processed data structure missing BLOCKPATH or ENDPATH field');
        end
    else
        % Treat as dataset folder name
        datasetPath = fullfile(basePath, input);
    end
end
