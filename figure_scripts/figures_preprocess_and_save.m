%{
--------------------------------------------------------------------------
FUNCTION NAME: figures_preprocess_and_save

DESCRIPTION:
    Preprocesses MEA data for the figures_* scripts (spike rate, total spikes,
    burst rate, spike percent change). Runs TDT load, notch, bandpass,
    TDTthresh, then computes spike rates, counts, and burst rates per channel.
    Saves one cache file per dataset to pipeline/figures/cache/. Run this script
    once (unless you change filtering); figure scripts then load by dataset name.

INPUTS:
    None - All parameters are set as variables in the script

OUTPUTS:
    Cache files saved to pipeline/figures/cache/
--------------------------------------------------------------------------
%}
function figures_preprocess_and_save()

% Define paths
SDKPATH = '/Users/bkutler4/Desktop/hai_lab/TDTMatlabSDK';
addpath(genpath(SDKPATH));
BASEPATH = '/Users/bkutler4/Desktop/hai_lab/data';
CACHEPATH = fullfile('/Users/bkutler4/Desktop/hai_lab/pipeline', 'figures', 'cache');

if ~exist(CACHEPATH, 'dir')
    mkdir(CACHEPATH);
end

% Processing parameters (matching figures_spike_rate.m, figures_burst_rate.m)
STORE = 'Wav1';
BP_FILTER = [300 2500];
max_harmonic = 780;
notch_base = 60;
Q = 35;
isiMax = 0.100;
isiEnd = 0.200;
minSpikes = 3;

%----------------------------------------------------------------------
% Channels to process (user-editable)
%----------------------------------------------------------------------
CHANNELS = 1:64;
%CHANNELS = 1:15;

%==================================================================================================================================================================================================
% ALL DATASETS (commented out - copy names into datasets below)
%==================================================================================================================================================================================================
% Control (baseline):
% 'IdoControl-230914-130200_#1','IdoControl-230914-131548_#2','IdoControl-230914-132855_#3','IdoControl-230914-154022_#4','IdoControl-230914-155318_#5','IdoControl-230914-160601_#6'
% DOI (treatment):
% 'IdoDOI-230914-142502_#1','IdoDOI-230914-143740_#2','IdoDOI-230914-144945_#3','IdoDOI-230914-161838_#4','IdoDOI-230914-163140_#5','IdoDOI-230914-164512_#6'
% Control 2:
% 'IdoControl-231101-144046_#1','IdoControl-231101-145330_#2','IdoControl-231101-150512_#3'
% Ketanserin:
% 'IdoKetanserin-231101-133725_#1','IdoKetanserin-231101-134946_#2','IdoKetanserin-231101-140237_#3'
%==================================================================================================================================================================================================

% Single list: all datasets to preprocess. Run once; figure scripts load by name.
datasets = {...
    'IdoControl-230914-131548_#2', 'IdoControl-230914-154022_#4','IdoControl-230914-155318_#5','IdoControl-230914-160601_#6', ...
    'IdoDOI-230914-143740_#2', 'IdoDOI-230914-161838_#4','IdoDOI-230914-163140_#5','IdoDOI-230914-164512_#6', ...
    'IdoControl-231101-145330_#2','IdoControl-231101-150512_#3', ...
    'IdoKetanserin-231101-134946_#2','IdoKetanserin-231101-140237_#3'};

if isempty(datasets)
    error('No datasets defined. Edit the datasets list above.');
end

for d = 1:length(datasets)
    datasetName = datasets{d};
    datasetPath = fullfile(BASEPATH, datasetName);

    if ~exist(datasetPath, 'dir')
        warning('Dataset not found: %s', datasetPath);
        continue;
    end

    cacheName = cacheFilename(datasetName);
    cachePath = fullfile(CACHEPATH, cacheName);
    if exist(cachePath, 'file')
        fprintf('Cache exists, skipping: %s\n', datasetName);
        continue;
    end

    fprintf('Processing dataset %d of %d: %s\n', d, length(datasets), datasetName);

    [rates, counts, burstRates, channelsUsed] = ...
        processOneDataset(datasetPath, STORE, CHANNELS, BP_FILTER, max_harmonic, notch_base, Q, isiMax, isiEnd, minSpikes);

    save(cachePath, 'channelsUsed', 'rates', 'counts', 'burstRates', 'datasetName');
    fprintf('Saved cache: %s\n', cachePath);
end

fprintf('Preprocessing complete. Cache directory: %s\n', CACHEPATH);
end

%--------------------------------------------------------------------------
% Build cache filename from single dataset name (safe for filesystem)
%--------------------------------------------------------------------------
function name = cacheFilename(datasetName)
safe = strrep(strrep(datasetName, '-', '_'), '#', '_');
name = sprintf('figures_cache_%s.mat', safe);
end

%--------------------------------------------------------------------------
% Process one dataset: load, filter, detect spikes, return rates/counts/burst rates per channel
%--------------------------------------------------------------------------
function [rates, counts, burstRates, channelsUsed] = processOneDataset(BLOCKPATH, STORE, CHANNELS, BP_FILTER, max_harmonic, notch_base, Q, isiMax, isiEnd, minSpikes)
nCh = length(CHANNELS);
rates = NaN(nCh, 1);
counts = NaN(nCh, 1);
burstRates = NaN(nCh, 1);
durationSec = NaN;
channels_prog = waitbar(0, 'Processing channels...');

for i = 1:nCh
    ch = CHANNELS(i);
    try
        rawData = TDTbin2mat(BLOCKPATH, 'STORE', STORE, 'CHANNEL', ch);
    catch %#ok<CTCH>
        waitbar(i / nCh, channels_prog, sprintf('Processing Channel %d of %d', ch, nCh));
        continue;
    end
    fs = rawData.streams.(STORE).fs;
    x = double(rawData.streams.(STORE).data(:));
    if i == 1
        durationSec = numel(x) / fs;
    end

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
        ts = sort(spikes.snips.Snip.ts(:));
        counts(i) = length(ts);
        if durationSec > 0
            rates(i) = counts(i) * (60 / durationSec);
        else
            rates(i) = NaN;
        end
        % Burst detection (same as burst_stats.m / getBurstRatesPerChannel)
        if numel(ts) >= minSpikes
            ISI = diff(ts);
            inBurst = false;
            startIdx = NaN;
            burstStarts = [];
            burstEnds = [];
            for ii = 1:numel(ISI)
                if ~inBurst && ISI(ii) <= isiMax
                    inBurst = true;
                    startIdx = ii;
                elseif inBurst && ISI(ii) > isiEnd
                    endIdx = ii;
                    if endIdx - startIdx + 1 >= minSpikes
                        burstStarts(end+1) = startIdx; %#ok<AGROW>
                        burstEnds(end+1) = endIdx;     %#ok<AGROW>
                    end
                    inBurst = false;
                end
            end
            if inBurst
                endIdx = numel(ts);
                if endIdx - startIdx + 1 >= minSpikes
                    burstStarts(end+1) = startIdx;
                    burstEnds(end+1) = endIdx;
                end
            end
            burstCount = numel(burstStarts);
            burstRates(i) = (burstCount / durationSec) * 60;
        else
            burstRates(i) = 0;
        end
    else
        rates(i) = NaN;
    end

    waitbar(i / nCh, channels_prog, sprintf('Processing Channel %d of %d', ch, nCh));
end
close(channels_prog);

if isnan(durationSec) || durationSec <= 0
    rates = NaN(nCh, 1);
end
channelsUsed = CHANNELS;
end
