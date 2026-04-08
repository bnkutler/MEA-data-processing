%{
--------------------------------------------------------------------------
FUNCTION NAME: figures_process_data

DESCRIPTION: 
    Processes exactly 2 MEA datasets, filters the data, and generates a
    filtered signal comparison figure. Uses the same filtering and processing
    methods as process_data.m. Does not store data in workspace - processes
    and creates figure directly.

INPUTS:
    None - All parameters are set as variables in the script

OUTPUTS:
    Comparison figure saved to outputPath
-------------------------------------------------------------------------
%}
function figures_process_data()

% Clear any existing data to prevent "Too many input arguments" errors
clear controlData treatmentData;

% Configuration variables - modify these as needed
channelIndices = [1,2,3,4,5,6,20,21,22,23];  % Channel indices to display in figure
labelNames = {'Baseline', 'DOI'};  % Labels for left and right columns
outputPath = '/Users/bkutler4/Desktop/hai_lab/pipeline/figures';  % Path to save figure

% Test mode: Set to true to only process channels needed for figure (faster for testing)
% Set to false to process all 64 channels (for spike detection statistics)
TEST_MODE = true;  % Change to false to process all channels

% Define paths and datasets
SDKPATH = '/Users/bkutler4/Desktop/hai_lab/TDTMatlabSDK';
addpath(genpath(SDKPATH));
BASEPATH = '/Users/bkutler4/Desktop/hai_lab/data';

%DATASETS
%==================================================================================================================================================================================================
% Testing with first dataset only
datasets = {'IdoControl-230914-132855_#3','IdoDOI-230914-144945_#3'};
% All datasets (commented out for testing)
% datasets = {'IdoControl-230914-130200_#1','IdoControl-230914-131548_#2','IdoControl-230914-132855_#3','IdoControl-230914-154022_#4','IdoControl-230914-155318_#5','IdoControl-230914-160601_#6',...
%     'IdoDOI-230914-142502_#1','IdoDOI-230914-143740_#2','IdoDOI-230914-144945_#3','IdoDOI-230914-161838_#4','IdoDOI-230914-163140_#5','IdoDOI-230914-164512_#6',...
%     'IdoControl-231101-144046_#1','IdoControl-231101-145330_#2','IdoControl-231101-150512_#3',...
%     'IdoKetanserin-231101-133725_#1','IdoKetanserin-231101-134946_#2','IdoKetanserin-231101-140237_#3'};
%==================================================================================================================================================================================================

% Input validation
if length(datasets) ~= 2
    error('datasets must contain exactly 2 entries (first=control, second=treatment)');
end
if length(labelNames) ~= 2
    error('labelNames must contain exactly 2 strings: {leftLabel, rightLabel}');
end
if ~isa(labelNames, 'cell')
    error('labelNames must be a cell array of strings');
end
% Validate labelNames is a cell array
if ~isa(labelNames, 'cell')
    error('labelNames must be a cell array of strings');
end

% Create output directory
if ~exist(outputPath, 'dir')
    mkdir(outputPath);
end

% Processing parameters (matching process_data.m)
STORE = 'Wav1';
if TEST_MODE
    % Only process channels needed for figure (faster for testing)
    CHANNELS = channelIndices;
    fprintf('TEST MODE: Processing only %d channels needed for figure\n', length(CHANNELS));
else
    % Process all 64 channels (for full spike detection statistics)
    CHANNELS = 1:64;
    fprintf('Processing all 64 channels\n');
end
BP_FILTER = [300 2500];
max_harmonic = 780;
notch_base = 60;
Q = 35;
STD_THRESH = 6.5;
TAU = 5;

% Waitbar
datasets_prog = waitbar(0, 'Processing datasets...');

for i = 1:length(datasets)
    ENDPATH = datasets{i};
    BLOCKPATH = fullfile(BASEPATH, ENDPATH);

    % Initialize processing variables
    datasetSpikes = 0; 
    datasetActiveChannels = 0; 
    recordLengthSecs = 0;
    spikeData = cell(length(CHANNELS), 1);
    spikeTimes = cell(length(CHANNELS), 1);
    spikeCountsPerChannel = zeros(length(CHANNELS), 1);
    filteredSignals = cell(length(CHANNELS), 1);  % Store filtered signal waveforms
    fs = [];  % Store sampling rate
    
    % Waitbar that displays progress on channels processed
    channels_prog = waitbar(0, sprintf('Processing channels for %s...', ENDPATH));
    
    % Convert and filter (same as process_data.m)
    for j = 1:length(CHANNELS)
        ch_idx = CHANNELS(j);
        rawData = TDTbin2mat(BLOCKPATH, 'STORE', STORE, 'CHANNEL', ch_idx);
        fs = rawData.streams.(STORE).fs;
        x = double(rawData.streams.(STORE).data(:));

        % notch 60 Hz harmonics (zero-phase)
        for f0 = notch_base:notch_base:max_harmonic
            if f0 < fs/2
                [B,A] = designNotchPeakIIR( ...
                    Response="notch", ...
                    CenterFrequency=f0/(fs/2), ...
                    QualityFactor=Q);
                x = filtfilt(B, A, x);
            end
        end

        % bandpass 300–2500 Hz (zero-phase)
        [bp_b,bp_a] = butter(4, BP_FILTER/(fs/2), 'bandpass');
        x = filtfilt(bp_b,bp_a,x);

        % Store filtered signal in µV
        if TEST_MODE
            % In test mode, index by position in CHANNELS array (j), not channel number
            filteredSignals{j} = x * 1e6;
        else
            % In full mode, only store channels needed for figure
            if ismember(ch_idx, channelIndices)
                filteredSignals{ch_idx} = x * 1e6;
            end
        end

        % Only run spike detection if NOT in test mode (saves a lot of time)
        if ~TEST_MODE
            dataFiltered = rawData;
            dataFiltered.streams.(STORE).data = x.';

            spikes = TDTthresh(dataFiltered, STORE, 'MODE', 'auto', 'POLARITY', -1, 'STD', 6.5, 'TAU', 5);
            spikeData{ch_idx} = spikes;

            % Update spike counts and active channel counts
            if ~isempty(spikeData{ch_idx})
                spikeCount = length(spikeData{ch_idx}.snips.Snip.ts);
                datasetSpikes = datasetSpikes + spikeCount;
                spikeCountsPerChannel(ch_idx) = spikeCount;
                datasetActiveChannels = datasetActiveChannels + 1;
            end
        end

        % For recording length, ensure it's calculated once per dataset
        if ch_idx == CHANNELS(1)
            nSamples = length(rawData.streams.(STORE).data);
            recordLengthSecs = nSamples / fs;
        end

        % Update waitbar
        waitbar(j / length(CHANNELS), channels_prog, sprintf('Processing Channel %d of %d', ch_idx, length(CHANNELS)));
    end
    
    close(channels_prog);

    % Extract channels needed for figure
    if TEST_MODE
        % In test mode, we only processed the channels we need in the same order as channelIndices
        % So filteredSignals is already in the correct order
        filteredSignalsForFigure = filteredSignals;
    else
        % In full mode, extract only the channels we need from all 64
        filteredSignalsForFigure = cell(length(channelIndices), 1);
        for idx = 1:length(channelIndices)
            ch = channelIndices(idx);
            if ch > length(filteredSignals)
                error('Channel index %d exceeds available channels (max: %d)', ch, length(filteredSignals));
            end
            if isempty(filteredSignals{ch})
                error('Channel %d was not processed. Check that ismember(ch_idx, channelIndices) condition is working.', ch);
            end
            filteredSignalsForFigure{idx} = filteredSignals{ch};
        end
    end
    
    % Validate that we extracted the correct number of channels
    if length(filteredSignalsForFigure) ~= length(channelIndices)
        error('Mismatch: extracted %d channels but expected %d', length(filteredSignalsForFigure), length(channelIndices));
    end
    
    % Store processed data in local structure (only channels needed for figure)
    if i == 1
        % Wrap cell array in {} to prevent MATLAB from creating a struct array
        controlData = struct(...
            'filteredSignals', {filteredSignalsForFigure}, ...
            'fs', fs, ...
            'ENDPATH', ENDPATH);
    else
        % Wrap cell array in {} to prevent MATLAB from creating a struct array
        treatmentData = struct(...
            'filteredSignals', {filteredSignalsForFigure}, ...
            'fs', fs, ...
            'ENDPATH', ENDPATH);
    end
    
    % Clear filteredSignals to free memory before processing next dataset
    clear filteredSignals;
    
    fprintf('Processed dataset %d of %d: %s\n', i, length(datasets), ENDPATH);
    
    % Update waitbar
    waitbar(i / length(datasets), datasets_prog, sprintf('Processing Dataset %d of %d', i, length(datasets)));

end
close(datasets_prog)

fprintf('All datasets processed. Generating comparison figure...\n');

% Validate that data structures exist
if ~exist('controlData', 'var') || isempty(controlData)
    error('controlData was not created or is empty. Check that first dataset processed successfully.');
end
if ~exist('treatmentData', 'var') || isempty(treatmentData)
    error('treatmentData was not created or is empty. Check that second dataset processed successfully.');
end

% Use scalar indexing to be safe, though structs should now be scalar
controlSignals = controlData(1).filteredSignals;
treatmentSignals = treatmentData(1).filteredSignals;

% Validate that signals exist and are cell arrays
if ~isa(controlSignals, 'cell') || isempty(controlSignals)
    error('controlSignals is not a cell array or is empty');
end
if ~isa(treatmentSignals, 'cell') || isempty(treatmentSignals)
    error('treatmentSignals is not a cell array or is empty');
end

% Get time vectors
fs_control = controlData(1).fs;
fs_treatment = treatmentData(1).fs;
nSamples_control = length(controlSignals{1});
nSamples_treatment = length(treatmentSignals{1});
time_control = (0:nSamples_control-1) / fs_control;
time_treatment = (0:nSamples_treatment-1) / fs_treatment;

% Indices for first 30 s (zoom)
n30_control = min(nSamples_control, round(30 * fs_control));
n30_treatment = min(nSamples_treatment, round(30 * fs_treatment));

nChannels = length(channelIndices);
channelOffset = 250;
designatedHeight = 0.85 * channelOffset;
ZOOM_DURATION = 30;
ZOOM_TIME_SCALE = 5;   % 5 s scale bar for zoom panels
FULL_TIME_SCALE = 30;  % 30 s scale bar for full panels

% Per-channel min/max/range/scale from all 4 segments
minPerCh = zeros(nChannels, 1);
maxPerCh = zeros(nChannels, 1);
rangePerCh = zeros(nChannels, 1);
scalePerCh = zeros(nChannels, 1);

for i = 1:nChannels
    seg1 = controlSignals{i}(1:n30_control);
    seg2 = controlSignals{i};
    seg3 = treatmentSignals{i}(1:n30_treatment);
    seg4 = treatmentSignals{i};
    minPerCh(i) = min([min(seg1), min(seg2), min(seg3), min(seg4)]);
    maxPerCh(i) = max([max(seg1), max(seg2), max(seg3), max(seg4)]);
    rangePerCh(i) = maxPerCh(i) - minPerCh(i);
    if rangePerCh(i) < 1e-6
        rangePerCh(i) = 1;
    end
    scalePerCh(i) = designatedHeight / rangePerCh(i);
end

% Y-positions (increasing order; first channel will be plotted at top via reverse index)
yPositions = (0:nChannels-1)' * channelOffset;
yMargin = 30;

% Create figure with publication-quality settings
fig = figure('Visible', 'off', 'Position', [100, 100, 1600, 1000], 'Color', 'w');
set(fig, 'Units', 'inches');
set(fig, 'PaperUnits', 'inches');
set(fig, 'PaperSize', [16, 10]);
set(fig, 'PaperPosition', [0, 0, 16, 10]);

% Four panels: [Baseline zoom | Baseline full | DOI zoom | DOI full]
% Leave margin left for Voltage label, margin right for vertical scale bars
ax_baseline_zoom  = axes('Position', [0.06, 0.12, 0.18, 0.75]);
ax_baseline_full  = axes('Position', [0.26, 0.12, 0.22, 0.75]);
ax_doi_zoom       = axes('Position', [0.50, 0.12, 0.18, 0.75]);
ax_doi_full       = axes('Position', [0.70, 0.12, 0.22, 0.75]);

% Helper: scaled y for channel i (reverse so channel 1 at top)
y_center = @(i) yPositions(nChannels - i + 1);
scaled_signal = @(sig, i) y_center(i) - designatedHeight/2 + scalePerCh(i) * (sig - minPerCh(i));

% ---- Baseline zoom (first 30 s) ----
axes(ax_baseline_zoom);
hold on;
for i = 1:nChannels
    t_zoom = time_control(1:n30_control);
    s_zoom = controlSignals{i}(1:n30_control);
    plot(t_zoom, scaled_signal(s_zoom, i), 'Color', [0, 0, 0], 'LineWidth', 0.5);
end
xlim([0, ZOOM_DURATION]);
ylim([-yMargin, max(yPositions) + designatedHeight/2 + yMargin]);
set(gca, 'YTick', yPositions, 'YTickLabel', {});
xlabel('Time (s)', 'FontSize', 11, 'FontName', 'Arial');
ylabel('Voltage (µV)', 'FontSize', 11, 'FontName', 'Arial');
set(gca, 'FontSize', 10, 'FontName', 'Arial', 'TickDir', 'out');
box off; grid off;

% 5 s scale bar (zoom)
scaleBarY_zoom = 25;
plot([2, 2 + ZOOM_TIME_SCALE], [scaleBarY_zoom, scaleBarY_zoom], 'k-', 'LineWidth', 2);
plot([2, 2], [scaleBarY_zoom-3, scaleBarY_zoom+3], 'k-', 'LineWidth', 1.5);
plot([2+ZOOM_TIME_SCALE, 2+ZOOM_TIME_SCALE], [scaleBarY_zoom-3, scaleBarY_zoom+3], 'k-', 'LineWidth', 1.5);
text(2 + ZOOM_TIME_SCALE/2, scaleBarY_zoom - 12, '5 s', 'FontSize', 10, 'FontName', 'Arial', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% ---- Baseline full (10 min) ----
axes(ax_baseline_full);
hold on;
for i = 1:nChannels
    dsf = max(1, floor(length(controlSignals{i}) / 50000));
    t_full = time_control(1:dsf:end);
    s_full = controlSignals{i}(1:dsf:end);
    plot(t_full, scaled_signal(s_full, i), 'Color', [0, 0, 0], 'LineWidth', 0.5);
end
xlim([0, max(time_control)]);
ylim([-yMargin, max(yPositions) + designatedHeight/2 + yMargin]);
set(gca, 'YTick', yPositions, 'YTickLabel', {});
xlabel('Time (s)', 'FontSize', 11, 'FontName', 'Arial');
set(gca, 'YLabel', []);
set(gca, 'FontSize', 10, 'FontName', 'Arial', 'TickDir', 'out');
box off; grid off;

% 30 s scale bar (full)
scaleBarY_full = 25;
plot([30, 30 + FULL_TIME_SCALE], [scaleBarY_full, scaleBarY_full], 'k-', 'LineWidth', 2);
plot([30, 30], [scaleBarY_full-3, scaleBarY_full+3], 'k-', 'LineWidth', 1.5);
plot([30+FULL_TIME_SCALE, 30+FULL_TIME_SCALE], [scaleBarY_full-3, scaleBarY_full+3], 'k-', 'LineWidth', 1.5);
text(30 + FULL_TIME_SCALE/2, scaleBarY_full - 12, '30 s', 'FontSize', 10, 'FontName', 'Arial', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% Baseline title
text(max(time_control)/2, max(yPositions) + designatedHeight/2 + 20, labelNames{1}, 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Arial', 'HorizontalAlignment', 'center');

% ---- DOI zoom (first 30 s) ----
axes(ax_doi_zoom);
hold on;
for i = 1:nChannels
    t_zoom = time_treatment(1:n30_treatment);
    s_zoom = treatmentSignals{i}(1:n30_treatment);
    plot(t_zoom, scaled_signal(s_zoom, i), 'Color', [0, 0, 0], 'LineWidth', 0.5);
end
xlim([0, ZOOM_DURATION]);
ylim([-yMargin, max(yPositions) + designatedHeight/2 + yMargin]);
set(gca, 'YTick', yPositions, 'YTickLabel', {});
xlabel('Time (s)', 'FontSize', 11, 'FontName', 'Arial');
set(gca, 'YLabel', []);
set(gca, 'FontSize', 10, 'FontName', 'Arial', 'TickDir', 'out');
box off; grid off;

% 5 s scale bar (zoom)
plot([2, 2 + ZOOM_TIME_SCALE], [scaleBarY_zoom, scaleBarY_zoom], 'k-', 'LineWidth', 2);
plot([2, 2], [scaleBarY_zoom-3, scaleBarY_zoom+3], 'k-', 'LineWidth', 1.5);
plot([2+ZOOM_TIME_SCALE, 2+ZOOM_TIME_SCALE], [scaleBarY_zoom-3, scaleBarY_zoom+3], 'k-', 'LineWidth', 1.5);
text(2 + ZOOM_TIME_SCALE/2, scaleBarY_zoom - 12, '5 s', 'FontSize', 10, 'FontName', 'Arial', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% ---- DOI full (10 min) ----
axes(ax_doi_full);
hold on;
for i = 1:nChannels
    dsf = max(1, floor(length(treatmentSignals{i}) / 50000));
    t_full = time_treatment(1:dsf:end);
    s_full = treatmentSignals{i}(1:dsf:end);
    plot(t_full, scaled_signal(s_full, i), 'Color', [0, 0, 0], 'LineWidth', 0.5);
end
xlim([0, max(time_treatment)]);
ylim([-yMargin, max(yPositions) + designatedHeight/2 + yMargin]);
set(gca, 'YTick', yPositions, 'YTickLabel', {});
xlabel('Time (s)', 'FontSize', 11, 'FontName', 'Arial');
set(gca, 'YLabel', []);
set(gca, 'FontSize', 10, 'FontName', 'Arial', 'TickDir', 'out');
box off; grid off;

% 30 s scale bar (full)
plot([30, 30 + FULL_TIME_SCALE], [scaleBarY_full, scaleBarY_full], 'k-', 'LineWidth', 2);
plot([30, 30], [scaleBarY_full-3, scaleBarY_full+3], 'k-', 'LineWidth', 1.5);
plot([30+FULL_TIME_SCALE, 30+FULL_TIME_SCALE], [scaleBarY_full-3, scaleBarY_full+3], 'k-', 'LineWidth', 1.5);
text(30 + FULL_TIME_SCALE/2, scaleBarY_full - 12, '30 s', 'FontSize', 10, 'FontName', 'Arial', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% DOI title
text(max(time_treatment)/2, max(yPositions) + designatedHeight/2 + 20, labelNames{2}, 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Arial', 'HorizontalAlignment', 'center');

% ---- Per-channel vertical scale bars (far right of figure) ----
axes(ax_doi_full);
xRight = max(time_treatment);
scaleBarXRight = xRight + 30;  % Just right of full trace, in time units
for i = 1:nChannels
    yc = y_center(i);
    plot([scaleBarXRight, scaleBarXRight], [yc - designatedHeight/2, yc + designatedHeight/2], 'k-', 'LineWidth', 1.5);
    % Round to nice value for label
    r = rangePerCh(i);
    if r >= 100
        lbl = sprintf('%.0f µV', r);
    elseif r >= 10
        lbl = sprintf('%.0f µV', round(r/5)*5);
    else
        lbl = sprintf('%.1f µV', r);
    end
    text(scaleBarXRight + 15, yc, lbl, 'FontSize', 8, 'FontName', 'Arial', 'VerticalAlignment', 'middle');
end
% Extend xlim so vertical scale bars and labels are visible
xlim(ax_doi_full, [0, scaleBarXRight + 80]);

% Save figure
    filename = sprintf('filtered_signals_comparison_%s_vs_%s.png', ...
        strrep(datasets{1}, '-', '_'), strrep(datasets{2}, '-', '_'));
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
    
    fprintf('Comparison figure saved to: %s\n', fullPath);

end
