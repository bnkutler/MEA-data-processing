%{
--------------------------------------------------------------------------
FUNCTION NAME: figures_spike_rate_pct_change_histogram

DESCRIPTION:
    Histogram of percent change in spike rate (baseline vs DOI) across all
    channels from all listed dataset pairs. Loads precomputed spike rates from
    cache (same as figures_spike_rate.m). For each aligned channel:
        pct = 100 * (rate_DOI - rate_baseline) / rate_baseline
    Channels with baseline spike rate == 0 are excluded. Only channels with
    pct in [pctMinCutoff, pctMaxCutoff] (default -100% to +1000%) are plotted;
    the rest are excluded as outliers. Negative rates cannot fall below -100%
    vs baseline if non-negative; large positive spikes are capped. Y-axis is
    channel count per bin; x-axis is padded to the data range (asymmetric).

INPUTS:
    None - Edit baselineList, treatmentList, and CHANNELS at top of script.

OUTPUTS:
    Figure saved to pipeline/figures/spike_rate_pct_change_histogram.png
    Requires figures_preprocess_and_save.m cache for each dataset name.
--------------------------------------------------------------------------
%}
function figures_spike_rate_pct_change_histogram()

outputPath = '/Users/bkutler4/Desktop/hai_lab/pipeline/figures';
CACHEPATH = fullfile('/Users/bkutler4/Desktop/hai_lab/pipeline', 'figures', 'cache');

if ~exist(outputPath, 'dir')
    mkdir(outputPath);
end

% Styling (match figures_spike_rate.m paired figure)
colorTreatment = [0.25, 0.40, 0.60];
colorTreatmentOutline = [0.35, 0.50, 0.70];
histNumBins = 45;
histFaceAlpha = 0.75;

% Hard cutoffs on percent change (%) for histogram and x-axis (tunable)
pctMinCutoff = -100;   % exclude pct < -100 (max decrease vs baseline)
pctMaxCutoff = 1000;   % exclude pct > 1000

%----------------------------------------------------------------------
% Channels to include (same ordering for baseline and treatment per pair)
%----------------------------------------------------------------------
CHANNELS = 1:64;

%==================================================================================================================================================================================================
% ALL DATASETS (commented out - copy names into baselineList and treatmentList below)
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

% Baseline (Control) and DOI: paired by index (1st with 1st, etc.)
baselineList = {'IdoControl-230914-130200_#1','IdoControl-230914-131548_#2','IdoControl-230914-132855_#3','IdoControl-230914-154022_#4','IdoControl-230914-155318_#5','IdoControl-230914-160601_#6'};
treatmentList = {'IdoDOI-230914-142502_#1','IdoDOI-230914-143740_#2','IdoDOI-230914-144945_#3','IdoDOI-230914-161838_#4','IdoDOI-230914-163140_#5','IdoDOI-230914-164512_#6'};

if isempty(baselineList) || isempty(treatmentList)
    error('baselineList and treatmentList must each contain at least one dataset name.');
end
if length(baselineList) ~= length(treatmentList)
    error('baselineList and treatmentList must have the same length.');
end

pctAll = [];
for pairIdx = 1:length(baselineList)
    baselineName = baselineList{pairIdx};
    treatmentName = treatmentList{pairIdx};

    cachePathBaseline = fullfile(CACHEPATH, figures_cache_filename(baselineName));
    cachePathTreatment = fullfile(CACHEPATH, figures_cache_filename(treatmentName));
    if ~exist(cachePathBaseline, 'file')
        error('No cache found for dataset ''%s''.\nRun figures_preprocess_and_save.m with this dataset in the datasets list first.\nExpected: %s', baselineName, cachePathBaseline);
    end
    if ~exist(cachePathTreatment, 'file')
        error('No cache found for dataset ''%s''.\nRun figures_preprocess_and_save.m with this dataset in the datasets list first.\nExpected: %s', treatmentName, cachePathTreatment);
    end
    fprintf('Loading pair %d/%d from cache: %s and %s\n', pairIdx, length(baselineList), baselineName, treatmentName);

    loadedB = load(cachePathBaseline);
    loadedT = load(cachePathTreatment);
    ratesBaseline = loadedB.rates(:);
    ratesTreatment = loadedT.rates(:);
    channelsUsedB = loadedB.channelsUsed(:)';
    channelsUsedT = loadedT.channelsUsed(:)';

    [~, idxB] = ismember(CHANNELS, channelsUsedB);
    [~, idxT] = ismember(CHANNELS, channelsUsedT);
    validIdx = (idxB > 0) & (idxT > 0);
    if ~any(validIdx)
        continue;
    end

    ratesBaselinePair = ratesBaseline(idxB(validIdx));
    ratesTreatmentPair = ratesTreatment(idxT(validIdx));

    valid = ~isnan(ratesBaselinePair) & ~isnan(ratesTreatmentPair);
    ratesBaselinePair = ratesBaselinePair(valid);
    ratesTreatmentPair = ratesTreatmentPair(valid);

    use = ratesBaselinePair > 0;
    ratesBaselinePair = ratesBaselinePair(use);
    ratesTreatmentPair = ratesTreatmentPair(use);

    pctPair = 100 * (ratesTreatmentPair - ratesBaselinePair) ./ ratesBaselinePair;
    pctAll = [pctAll; pctPair]; %#ok<AGROW>
end

if isempty(pctAll)
    error('No valid channel pairs after filtering (need baseline spike rate > 0 and aligned channels in cache).');
end

nTotal = numel(pctAll);
fprintf('Total channel observations (before pct cutoffs): %d\n', nTotal);

inRange = (pctAll >= pctMinCutoff) & (pctAll <= pctMaxCutoff);
pctPlot = pctAll(inRange);
nExcluded = nTotal - numel(pctPlot);
fprintf('Included in histogram: %d  |  Excluded (outside [%.0f%%, %.0f%%]): %d (%.1f%%)\n', ...
    numel(pctPlot), pctMinCutoff, pctMaxCutoff, nExcluded, 100 * nExcluded / nTotal);

if isempty(pctPlot)
    error('No channel observations remain after applying pct cutoffs [%.0f%%, %.0f%%].', ...
        pctMinCutoff, pctMaxCutoff);
end

%--------------------------------------------------------------------------
% Histogram (xline at 0% reference)
%--------------------------------------------------------------------------
fprintf('Creating histogram figure...\n');
fig = figure('Visible', 'off', 'Position', [100, 100, 600, 600], 'Color', 'w');
set(fig, 'Units', 'inches');
set(fig, 'PaperUnits', 'inches');
set(fig, 'PaperSize', [6, 6]);
set(fig, 'PaperPosition', [0, 0, 6, 6]);
hold on;

h = histogram(pctPlot, histNumBins, 'FaceColor', colorTreatment, 'FaceAlpha', histFaceAlpha, ...
    'EdgeColor', colorTreatmentOutline, 'LineWidth', 0.8);
xa = min(pctPlot);
xb = max(pctPlot);
span = xb - xa;
if span <= 0
    span = max(abs(xa), 1);
end
pad = 0.05 * span;
xlim([xa - pad, xb + pad]);
xline(0, 'k-', 'LineWidth', 1.5);

yTop = max(h.Values);
if yTop == 0
    yTop = 1;
end
ylim([0, yTop * 1.08]);
yTickStep = computeNiceTickStep(yTop * 1.08, 8);
yticks(0:yTickStep:ceil(yTop * 1.08 / yTickStep) * yTickStep);

xlabel('Percent change in spike rate (%)', 'FontSize', 18, 'FontName', 'Arial', 'FontWeight', 'bold');
ylabel('Number of channels', 'FontSize', 18, 'FontName', 'Arial', 'FontWeight', 'bold');
set(gca, 'FontSize', 18, 'FontName', 'Arial', 'TickDir', 'out', 'FontWeight', 'bold');
ax = gca;
ax.XAxis.FontSize = 18;
ax.YAxis.FontSize = 18;
ax.YAxis.FontWeight = 'bold';
ax.LineWidth = 1.7;
ax.Position = [0.16, 0.12, 0.80, 0.76];
ax.XAxis.TickLength = [0.014 0.014];
ax.YAxis.TickLength = [0.014 0.014];
box off;

filename = 'spike_rate_pct_change_histogram.png';
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
% Choose a "nice" y tick step (1/2/5 * 10^n) for readable axes
%--------------------------------------------------------------------------
function step = computeNiceTickStep(yMax, targetTickCount)
if yMax <= 0 || targetTickCount < 2
    step = 1;
    return;
end
rawStep = yMax / (targetTickCount - 1);
mag = 10^floor(log10(rawStep));
frac = rawStep / mag;
if frac <= 1
    niceFrac = 1;
elseif frac <= 2
    niceFrac = 2;
elseif frac <= 5
    niceFrac = 5;
else
    niceFrac = 10;
end
step = niceFrac * mag;
end
