%{
--------------------------------------------------------------------------
FUNCTION NAME: figures_spike_percent_change

DESCRIPTION: 
    Generates a figure displaying percent change of total spike count per
    channel between baseline and DOI, and baseline and Ketanserin. Each dot
    represents a channel; blue for DOI, red for Ketanserin. Channels with 0
    spikes in either baseline or treatment are excluded. Uses the same data
    ingestion, filtering, and TDTthresh spike detection as the rest of the
    pipeline.

INPUTS:
    None - All parameters are set as variables in the script

OUTPUTS:
    Figure saved to pipeline/figures/
    Requires preprocessed cache from figures_preprocess_and_save.m (one cache per dataset name).
-------------------------------------------------------------------------
%}
function figures_spike_percent_change()

% Define paths
SDKPATH = '/Users/bkutler4/Desktop/hai_lab/TDTMatlabSDK';
addpath(genpath(SDKPATH));
BASEPATH = '/Users/bkutler4/Desktop/hai_lab/data';
outputPath = '/Users/bkutler4/Desktop/hai_lab/pipeline/figures';
CACHEPATH = fullfile('/Users/bkutler4/Desktop/hai_lab/pipeline', 'figures', 'cache');

% Create output directory if it doesn't exist
if ~exist(outputPath, 'dir')
    mkdir(outputPath);
end

% Processing parameters (matching figures_compare_filtered_signals.m and process_data.m)
STORE = 'Wav1';
CHANNELS = 1:64;
BP_FILTER = [300 2500];
max_harmonic = 780;
notch_base = 60;
Q = 35;

%==================================================================================================================================================================================================
% ALL DATASETS (commented out - copy names into the four lists below)
%==================================================================================================================================================================================================
% Control 1 (for DOI baseline):
% 'IdoControl-230914-130200_#1','IdoControl-230914-131548_#2','IdoControl-230914-132855_#3','IdoControl-230914-154022_#4','IdoControl-230914-155318_#5','IdoControl-230914-160601_#6'
% DOI:
% 'IdoDOI-230914-142502_#1','IdoDOI-230914-143740_#2','IdoDOI-230914-144945_#3','IdoDOI-230914-161838_#4','IdoDOI-230914-163140_#5','IdoDOI-230914-164512_#6'
% Control 2 (for Ketanserin baseline):
% 'IdoControl-231101-144046_#1','IdoControl-231101-145330_#2','IdoControl-231101-150512_#3'
% Ketanserin:
% 'IdoKetanserin-231101-133725_#1','IdoKetanserin-231101-134946_#2','IdoKetanserin-231101-140237_#3'
%==================================================================================================================================================================================================

% FOUR USER-EDITABLE LISTS - Add dataset names from the commented list above
% Each list: baseline and treatment must be paired by index (1st with 1st, 2nd with 2nd, etc.)
doiBaselineList = {'IdoControl-230914-130200_#1','IdoControl-230914-131548_#2','IdoControl-230914-132855_#3','IdoControl-230914-154022_#4','IdoControl-230914-155318_#5','IdoControl-230914-160601_#6'};
doiList = {'IdoDOI-230914-142502_#1','IdoDOI-230914-143740_#2','IdoDOI-230914-144945_#3','IdoDOI-230914-161838_#4','IdoDOI-230914-163140_#5','IdoDOI-230914-164512_#6'};
ketanserinBaselineList = {'IdoControl-231101-144046_#1','IdoControl-231101-145330_#2','IdoControl-231101-150512_#3'};
ketanserinList = {'IdoKetanserin-231101-133725_#1','IdoKetanserin-231101-134946_#2','IdoKetanserin-231101-140237_#3'};

% Validate that at least one condition has data
if isempty(doiBaselineList) && isempty(ketanserinBaselineList)
    error('At least one of doiBaselineList or ketanserinBaselineList must be non-empty.');
end
if ~isempty(doiBaselineList) && (length(doiBaselineList) ~= length(doiList))
    error('doiBaselineList and doiList must have the same length.');
end
if ~isempty(ketanserinBaselineList) && (length(ketanserinBaselineList) ~= length(ketanserinList))
    error('ketanserinBaselineList and ketanserinList must have the same length.');
end

% Collect percent changes for each condition (load from cache; run figures_preprocess_and_save.m first)
pctChangeDOI = [];
pctChangeKetanserin = [];

% Process DOI condition from cache (load one cache per dataset name)
if ~isempty(doiBaselineList)
    fprintf('Loading DOI condition from cache (%d pair(s))...\n', length(doiBaselineList));
    for pairIdx = 1:length(doiBaselineList)
        baselineName = doiBaselineList{pairIdx};
        treatmentName = doiList{pairIdx};
        cachePathB = fullfile(CACHEPATH, figures_cache_filename(baselineName));
        cachePathT = fullfile(CACHEPATH, figures_cache_filename(treatmentName));
        if ~exist(cachePathB, 'file')
            error('No cache found for dataset ''%s''.\nRun figures_preprocess_and_save.m with this dataset in the datasets list first.', baselineName);
        end
        if ~exist(cachePathT, 'file')
            error('No cache found for dataset ''%s''.\nRun figures_preprocess_and_save.m with this dataset in the datasets list first.', treatmentName);
        end
        loadedB = load(cachePathB);
        loadedT = load(cachePathT);
        countsBaseline = loadedB.counts(:);
        countsTreatment = loadedT.counts(:);
        channelsUsedB = loadedB.channelsUsed(:)';
        channelsUsedT = loadedT.channelsUsed(:)';
        [~, idxB] = ismember(CHANNELS, channelsUsedB);
        [~, idxT] = ismember(CHANNELS, channelsUsedT);
        validIdx = (idxB > 0) & (idxT > 0);
        if any(validIdx)
            countsBaseline = countsBaseline(idxB(validIdx));
            countsTreatment = countsTreatment(idxT(validIdx));
            for k = 1:length(countsBaseline)
                nBaseline = countsBaseline(k);
                nTreatment = countsTreatment(k);
                if nBaseline > 0 && nTreatment > 0
                    pct = 100 * (nTreatment - nBaseline) / nBaseline;
                    pctChangeDOI = [pctChangeDOI; pct]; %#ok<AGROW>
                end
            end
        end
    end
end

% Process Ketanserin condition from cache (load one cache per dataset name)
if ~isempty(ketanserinBaselineList)
    fprintf('Loading Ketanserin condition from cache (%d pair(s))...\n', length(ketanserinBaselineList));
    for pairIdx = 1:length(ketanserinBaselineList)
        baselineName = ketanserinBaselineList{pairIdx};
        treatmentName = ketanserinList{pairIdx};
        cachePathB = fullfile(CACHEPATH, figures_cache_filename(baselineName));
        cachePathT = fullfile(CACHEPATH, figures_cache_filename(treatmentName));
        if ~exist(cachePathB, 'file')
            error('No cache found for dataset ''%s''.\nRun figures_preprocess_and_save.m with this dataset in the datasets list first.', baselineName);
        end
        if ~exist(cachePathT, 'file')
            error('No cache found for dataset ''%s''.\nRun figures_preprocess_and_save.m with this dataset in the datasets list first.', treatmentName);
        end
        loadedB = load(cachePathB);
        loadedT = load(cachePathT);
        countsBaseline = loadedB.counts(:);
        countsTreatment = loadedT.counts(:);
        channelsUsedB = loadedB.channelsUsed(:)';
        channelsUsedT = loadedT.channelsUsed(:)';
        [~, idxB] = ismember(CHANNELS, channelsUsedB);
        [~, idxT] = ismember(CHANNELS, channelsUsedT);
        validIdx = (idxB > 0) & (idxT > 0);
        if any(validIdx)
            countsBaseline = countsBaseline(idxB(validIdx));
            countsTreatment = countsTreatment(idxT(validIdx));
            for k = 1:length(countsBaseline)
                nBaseline = countsBaseline(k);
                nTreatment = countsTreatment(k);
                if nBaseline > 0 && nTreatment > 0
                    pct = 100 * (nTreatment - nBaseline) / nBaseline;
                    pctChangeKetanserin = [pctChangeKetanserin; pct]; %#ok<AGROW>
                end
            end
        end
    end
end

% Check we have data to plot
if isempty(pctChangeDOI) && isempty(pctChangeKetanserin)
    error('No valid channel pairs (all channels had 0 spikes in baseline or treatment).');
end

% Outlier filter: exclude |pct change| > 2000% from figure (keep in raw data)
OUTLIER_THRESHOLD = 2000;
pctChangeDOI_plot = pctChangeDOI(abs(pctChangeDOI) <= OUTLIER_THRESHOLD);
pctChangeKetanserin_plot = pctChangeKetanserin(abs(pctChangeKetanserin) <= OUTLIER_THRESHOLD);

if isempty(pctChangeDOI_plot) && isempty(pctChangeKetanserin_plot)
    error('All points exceeded the outlier threshold (|pct change| > %g%%).', OUTLIER_THRESHOLD);
end

% Create figure
fprintf('Creating figure...\n');
fig = figure('Visible', 'off', 'Position', [100, 100, 600, 600], 'Color', 'w');
set(fig, 'Units', 'inches');
set(fig, 'PaperUnits', 'inches');
set(fig, 'PaperSize', [6, 6]);
set(fig, 'PaperPosition', [0, 0, 6, 6]);

hold on;

% 0% reference line (draw first so it sits behind the scatter points)
yline(0, 'k-', 'LineWidth', 1.5);

% Jitter amount for x (fixed seed for reproducibility)
rng(42);
jitterRange = 0.15;

% Plot DOI dots (blue) at x = 1
if ~isempty(pctChangeDOI_plot)
    nDOI = length(pctChangeDOI_plot);
    xDOI = 1 + (rand(nDOI, 1) * 2 - 1) * jitterRange;
    scatter(xDOI, pctChangeDOI_plot, 36, [0, 0.45, 0.74], 'filled', 'MarkerFaceAlpha', 0.7);
end

% Plot Ketanserin dots (red) at x = 2
if ~isempty(pctChangeKetanserin_plot)
    nKet = length(pctChangeKetanserin_plot);
    xKet = 2 + (rand(nKet, 1) * 2 - 1) * jitterRange;
    scatter(xKet, pctChangeKetanserin_plot, 36, [0.85, 0.33, 0.10], 'filled', 'MarkerFaceAlpha', 0.7);
end

% Fixed y-limits
ylim([-300, 600]);

% X-axis: one or two groups depending on which conditions have data
if ~isempty(pctChangeDOI_plot) && ~isempty(pctChangeKetanserin_plot)
    xlim([0.5, 2.5]);
    xticks([1, 2]);
    xticklabels({'DOI', 'Ketanserin'});
elseif ~isempty(pctChangeDOI_plot)
    xlim([0.5, 1.5]);
    xticks(1);
    xticklabels({'DOI'});
else
    xlim([1.5, 2.5]);
    xticks(2);
    xticklabels({'Ketanserin'});
end

ylabel('Percent Change in Spike Count (%)', 'FontSize', 11, 'FontName', 'Arial');
xlabel('Condition', 'FontSize', 11, 'FontName', 'Arial');
set(gca, 'FontSize', 10, 'FontName', 'Arial', 'TickDir', 'out');
box off;

% Save figure
filename = 'spike_percent_change.png';
fullPath = fullfile(outputPath, filename);
try
    exportgraphics(fig, fullPath, 'Resolution', 300);
catch
    set(fig, 'PaperPositionMode', 'auto');
    print(fig, fullPath, '-dpng', '-r300');
end
close(fig);

fprintf('Figure saved to: %s\n', fullPath);

end

%--------------------------------------------------------------------------
% Build cache filename for one dataset (must match figures_preprocess_and_save.m)
%--------------------------------------------------------------------------
function name = figures_cache_filename(datasetName)
safe = strrep(strrep(datasetName, '-', '_'), '#', '_');
name = sprintf('figures_cache_%s.mat', safe);
end

%--------------------------------------------------------------------------
% Get spike counts per channel for a dataset (filter + TDTthresh)
%--------------------------------------------------------------------------
function spikeCounts = getSpikeCountsPerChannel(BLOCKPATH, STORE, CHANNELS, BP_FILTER, max_harmonic, notch_base, Q)
    spikeCounts = zeros(length(CHANNELS), 1);
    channels_prog = waitbar(0, 'Processing channels...');
    for i = 1:length(CHANNELS)
        ch = CHANNELS(i);
        try
            rawData = TDTbin2mat(BLOCKPATH, 'STORE', STORE, 'CHANNEL', ch);
        catch
            % Channel may not exist in this dataset
            waitbar(i / length(CHANNELS), channels_prog, sprintf('Processing Channel %d of %d', ch, length(CHANNELS)));
            continue;
        end
        fs = rawData.streams.(STORE).fs;
        x = double(rawData.streams.(STORE).data(:));

        % Notch filter 60 Hz harmonics (zero-phase)
        for f0 = notch_base:notch_base:max_harmonic
            if f0 < fs/2
                [B, A] = designNotchPeakIIR(...
                    Response="notch", ...
                    CenterFrequency=f0/(fs/2), ...
                    QualityFactor=Q);
                x = filtfilt(B, A, x);
            end
        end

        % Bandpass 300-2500 Hz (zero-phase)
        [bp_b, bp_a] = butter(4, BP_FILTER/(fs/2), 'bandpass');
        x = filtfilt(bp_b, bp_a, x);

        % TDTthresh spike detection (matching process_data.m)
        dataFiltered = rawData;
        dataFiltered.streams.(STORE).data = x.';
        spikes = TDTthresh(dataFiltered, STORE, 'MODE', 'auto', 'POLARITY', -1, 'STD', 6.5, 'TAU', 5);

        if ~isempty(spikes) && isfield(spikes, 'snips') && isfield(spikes.snips, 'Snip') && isfield(spikes.snips.Snip, 'ts')
            spikeCounts(i) = length(spikes.snips.Snip.ts);
        end

        waitbar(i / length(CHANNELS), channels_prog, sprintf('Processing Channel %d of %d', ch, length(CHANNELS)));
    end
    close(channels_prog);
end

%--------------------------------------------------------------------------
% Helper: get dataset path from workspace variable or folder name
%--------------------------------------------------------------------------
function datasetPath = getDatasetPath(input, basePath)
    if contains(input, 'processedData_')
        varName = input;
        if ~evalin('base', sprintf('exist(''%s'', ''var'')', varName))
            error('Workspace variable not found: %s\nRun figures_process_data.m first.', varName);
        end
        processedData = evalin('base', varName);
        if isfield(processedData, 'BLOCKPATH')
            datasetPath = processedData.BLOCKPATH;
        elseif isfield(processedData, 'ENDPATH')
            datasetPath = fullfile(basePath, processedData.ENDPATH);
        else
            error('Processed data structure missing BLOCKPATH or ENDPATH field');
        end
    else
        datasetPath = fullfile(basePath, input);
    end
end
