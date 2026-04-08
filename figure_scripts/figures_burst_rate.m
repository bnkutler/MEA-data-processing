%{
--------------------------------------------------------------------------
FUNCTION NAME: figures_burst_rate

DESCRIPTION:
    Generates two figures for burst rate (bursts/min) per channel (baseline
    vs treatment): (1) a paired-line figure (dots connected by lines,
    green if treatment > baseline, red if treatment < baseline), with mean
    markers and vertical IQR (Q1-Q3) bars on each half-violin, and
    (2) a boxplot. Boxplot: the overlaid mean excludes outliers (1.5*IQR rule).
    Uses the same data ingestion, filtering, and TDTthresh spike detection
    as figures_spike_rate.m; burst definition and rate formula follow
    burst_stats.m (ISI-threshold).
    Optional: ignoreSilentChannels + minRateThreshold on burst rate (burstRates in
    cache, bursts/min): drop a channel only if both baseline and treatment burst
    rates are below threshold (threshold 0 drops only pairs with 0 bursts/min on
    both sides). Spike rate (rates) is not used for this filter.
    Optional: exclude channel pairs where either condition exceeds a multiple
    of that condition's mean (one-pass means; large values influence the cutoff),
    same logic as figures_spike_rate.m.
    Optional: ketanserin mode recolors treatment only (orange); set xLabelTreatment
    manually (e.g. Ketanserin), as in figures_spike_rate.m.

INPUTS:
    None - All parameters are set as variables in the script

OUTPUTS:
    Figures saved to pipeline/figures/
    Optional: burst_rate_data.mat with rates and channel list
--------------------------------------------------------------------------
%}
function figures_burst_rate()

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

% Processing parameters (matching figures_spike_rate.m and process_data.m)
STORE = 'Wav1';
BP_FILTER = [300 2500];
max_harmonic = 780;
notch_base = 60;
Q = 35;

%----------------------------------------------------------------------
% Burst detection parameters (matching burst_stats.m)
%----------------------------------------------------------------------
isiMax = 0.100;   % (s) ISI <= this starts/continues a burst
isiEnd = 0.200;   % (s) ISI > this ends a burst
% Minimum spikes within one ISI-defined segment for that segment to count as a burst.
% Does not set a minimum total burst count or burst rate per channel/recording.
minSpikes = 3;

%----------------------------------------------------------------------
% Dot and line colors for paired-line plot (customize here). RGB in [0,1]. Alpha for dots.
%----------------------------------------------------------------------
colorBaseline = [0.50, 0.50, 0.50];  % grey (darker for dots)
colorTreatment = [0.25, 0.40, 0.60]; % blue (darker for dots)
colorIncrease = [0.5, 0.72, 0.55];  % line when treatment > baseline (dull green)
colorDecrease = [0.82, 0.58, 0.58]; % line when treatment < baseline (dull red)
alphaDots = 0.4;                     % translucency for scatter points (lower = darker where overlapping)

% Mean + IQR overlay on paired-line figure (simple mean and prctile quartiles on all plotted channels)
iqrSummaryLineWidth = 0.85;
iqrCapHalfWidth = 0.0035;            % half-width of horizontal caps at Q1/Q3 (x axis units)
meanSummaryMarkerSize = 5;           % MarkerSize (points) for black mean dot on IQR line

%----------------------------------------------------------------------
% Box colors for boxplot (customize here). RGB in [0,1].
%----------------------------------------------------------------------
colorBaselineBox = [0.88, 0.88, 0.88];  % grey
colorTreatmentBox = [0.573, 0.694, 0.843]; % reference blue #92B1D7
colorBaselineOutline = [0.65, 0.65, 0.65];  % darker grey for box/violin outline and mean line
colorTreatmentOutline = [0.35, 0.50, 0.70]; % darker blue for box/violin outline and mean line

% If true, override treatment colors to orange (baseline unchanged); set xLabelTreatment yourself
useKetanserinTreatmentColors = true;
if useKetanserinTreatmentColors
    colorTreatment = [0.90, 0.50, 0.12];
    colorTreatmentBox = [0.95, 0.72, 0.48];
    colorTreatmentOutline = [0.76, 0.48, 0.22];
end

%----------------------------------------------------------------------
% X-axis labels (customize if not using Baseline / DOI)
%----------------------------------------------------------------------
xLabelBaseline = 'Baseline';
xLabelTreatment = 'DOI';

%----------------------------------------------------------------------
% Channels to include in the plot (same ordering for baseline and treatment)
%----------------------------------------------------------------------
CHANNELS = 1:64;
% CHANNELS = 1:15;  % example: subset of channels
% Channel inclusion: threshold is burst rate (bursts/min, cache field burstRates); same Tukey-style rule shape as figures_spike_rate (both sides below threshold).
ignoreSilentChannels = true; % if true, drop channels where both baseline and treatment burst rates are below minRateThreshold
minRateThreshold = 0;      % bursts/min; ignored when ignoreSilentChannels is false. If 0, only drop pairs with 0 bursts/min on both sides.
excludeMeanMultiplierOutliers = false; % if true, drop paired rows where either rate > multiplier * mean for that condition
meanRateOutlierMultiplier = 15;       % must be > 1 when excludeMeanMultiplierOutliers is true

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

% Desired baseline and treatment dataset (one each for both figures)
baselineList = {'IdoControl-231101-144046_#1','IdoControl-231101-145330_#2','IdoControl-231101-150512_#3'};
treatmentList = {'IdoKetanserin-231101-133725_#1','IdoKetanserin-231101-134946_#2','IdoKetanserin-231101-140237_#3'};

% Validate
if isempty(baselineList) || isempty(treatmentList)
    error('baselineList and treatmentList must each contain at least one dataset name.');
end
if length(baselineList) ~= length(treatmentList)
    error('baselineList and treatmentList must have the same length.');
end

% Aggregate all pairs in order: baselineList{k} vs treatmentList{k}
ratesBaselineAll = [];
ratesTreatmentAll = [];
channelsUsedAll = [];
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
    burstRatesBaseline = loadedB.burstRates(:);
    burstRatesTreatment = loadedT.burstRates(:);
    channelsUsedB = loadedB.channelsUsed(:)';
    channelsUsedT = loadedT.channelsUsed(:)';

    [~, idxB] = ismember(CHANNELS, channelsUsedB);
    [~, idxT] = ismember(CHANNELS, channelsUsedT);
    validIdx = (idxB > 0) & (idxT > 0);
    if ~any(validIdx)
        continue;
    end

    ratesBaselinePair = burstRatesBaseline(idxB(validIdx));
    ratesTreatmentPair = burstRatesTreatment(idxT(validIdx));
    channelsUsedPair = CHANNELS(validIdx);

    valid = ~isnan(ratesBaselinePair) & ~isnan(ratesTreatmentPair);
    ratesBaselinePair = ratesBaselinePair(valid);
    ratesTreatmentPair = ratesTreatmentPair(valid);
    channelsUsedPair = channelsUsedPair(valid);

    if ignoreSilentChannels
        if minRateThreshold == 0
            nonSilent = ~(ratesBaselinePair == 0 & ratesTreatmentPair == 0);
        else
            nonSilent = ~(ratesBaselinePair < minRateThreshold & ratesTreatmentPair < minRateThreshold);
        end
        ratesBaselinePair = ratesBaselinePair(nonSilent);
        ratesTreatmentPair = ratesTreatmentPair(nonSilent);
        channelsUsedPair = channelsUsedPair(nonSilent);
    end

    ratesBaselineAll = [ratesBaselineAll; ratesBaselinePair]; %#ok<AGROW>
    ratesTreatmentAll = [ratesTreatmentAll; ratesTreatmentPair]; %#ok<AGROW>
    channelsUsedAll = [channelsUsedAll, channelsUsedPair]; %#ok<AGROW>
end

ratesBaseline = ratesBaselineAll;
ratesTreatment = ratesTreatmentAll;
channelsUsed = channelsUsedAll;
if isempty(ratesBaseline)
    error('No valid channels found across pairs after filtering (including ignoreSilentChannels setting).');
end

if excludeMeanMultiplierOutliers
    if ~(isscalar(meanRateOutlierMultiplier) && isfinite(meanRateOutlierMultiplier) && meanRateOutlierMultiplier > 1)
        error('meanRateOutlierMultiplier must be a finite scalar > 1 when excludeMeanMultiplierOutliers is true.');
    end
    mB = mean(ratesBaseline(:));
    mT = mean(ratesTreatment(:));
    keepMeanMult = ratesBaseline <= meanRateOutlierMultiplier * mB & ratesTreatment <= meanRateOutlierMultiplier * mT;
    nDropMean = sum(~keepMeanMult);
    ratesBaseline = ratesBaseline(keepMeanMult);
    ratesTreatment = ratesTreatment(keepMeanMult);
    channelsUsed = channelsUsed(keepMeanMult);
    fprintf('Mean-multiplier outlier filter: excluded %d channel observation(s) (multiplier = %.4g).\n', nDropMean, meanRateOutlierMultiplier);
    if isempty(ratesBaseline)
        error('No channels remain after mean-multiplier outlier filter.');
    end
end

nCh = length(ratesBaseline);
nIncrease = sum(ratesTreatment > ratesBaseline);
nDecrease = sum(ratesTreatment < ratesBaseline);
pctIncrease = 100 * nIncrease / nCh;
pctDecrease = 100 * nDecrease / nCh;

%==============================================================================
% Figure 1: Paired-line (burst rate)
%==============================================================================
xBaseline = ones(nCh, 1);      % all at x = 1
xTreatment = repmat(1.22, nCh, 1); % all at x = 1.22

fprintf('Creating paired-line figure...\n');
fig = figure('Visible', 'off', 'Position', [100, 100, 600, 600], 'Color', 'w');
set(fig, 'Units', 'inches');
set(fig, 'PaperUnits', 'inches');
set(fig, 'PaperSize', [6, 6]);
set(fig, 'PaperPosition', [0, 0, 6, 6]);
hold on;

% Vertical distribution curves (violins) behind dots: baseline left of x=1, treatment right of x=1.22
yAll = [ratesBaseline; ratesTreatment];
yGrid = linspace(max(0, min(yAll) - 1), max(yAll) + 1, 100);
[fB, ~] = ksdensity(ratesBaseline, yGrid);
[fT, ~] = ksdensity(ratesTreatment, yGrid);
violinW = 0.06;
if max(fB) > 0
    fB = (fB / max(fB)) * violinW;
    yB = yGrid(:);
    hpB = patch([0.98 - fB(:); 0.98 * ones(numel(yB), 1)], [yB; flipud(yB)], colorBaseline, 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    uistack(hpB, 'bottom');
    plot(0.98 - fB, yB, 'Color', colorBaselineOutline, 'LineWidth', 1.2);
end
if max(fT) > 0
    fT = (fT / max(fT)) * violinW;
    yT = yGrid(:);
    hpT = patch([1.24 * ones(numel(yT), 1); 1.24 + flipud(fT(:))], [yT; flipud(yT)], colorTreatment, 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    uistack(hpT, 'bottom');
    plot(1.24 + fT, yT, 'Color', colorTreatmentOutline, 'LineWidth', 1.2);
end

% IQR/mean x: inside half-violin, shifted toward dot columns (1 / 1.22) from geometric center
violinEdgeBaseline = 0.98;
violinEdgeTreatment = 1.24;
xSummaryBaseline = violinEdgeBaseline - 0.006;
xSummaryTreatment = violinEdgeTreatment + 0.006;

% Draw connecting lines (behind dots)
for i = 1:nCh
    if ratesTreatment(i) > ratesBaseline(i)
        lineColor = colorIncrease;
    else
        lineColor = colorDecrease;
    end
    plot([xBaseline(i), xTreatment(i)], [ratesBaseline(i), ratesTreatment(i)], ...
        'Color', lineColor, 'LineWidth', 1.2);
end

% Baseline dots (translucent)
scatter(xBaseline, ratesBaseline, 76, colorBaseline, 'filled', 'MarkerFaceAlpha', alphaDots);

% Treatment dots (translucent)
scatter(xTreatment, ratesTreatment, 76, colorTreatment, 'filled', 'MarkerFaceAlpha', alphaDots);

% Mean + IQR (Q1-Q3) over half-violins (same stats as dot data)
plotMeanIqrMarker(gca, xSummaryBaseline, ratesBaseline, iqrCapHalfWidth, iqrSummaryLineWidth, meanSummaryMarkerSize);
plotMeanIqrMarker(gca, xSummaryTreatment, ratesTreatment, iqrCapHalfWidth, iqrSummaryLineWidth, meanSummaryMarkerSize);

% Axes (ymax includes quartiles so IQR bars are never clipped)
qPaired = [prctile(ratesBaseline, [25 75]); prctile(ratesTreatment, [25 75])];
ymax = max([ratesBaseline; ratesTreatment; qPaired(:)]);
xlim([0.88, 1.30]);
xticks([1, 1.22]);
xticklabels({'', ''});
ylim([0, ymax * 1.05]);
yTop = ymax * 1.05;
yTickStep = computeNiceTickStep(yTop, 8);
yticks(0:yTickStep:ceil(yTop / yTickStep) * yTickStep);
ylabel('');
set(gca, 'FontSize', 18, 'FontName', 'Arial', 'TickDir', 'out', 'FontWeight', 'bold');
ax = gca;
ax.XAxis.FontSize = 18;
ax.YAxis.FontSize = 18;
ax.YAxis.FontWeight = 'bold';
ax.LineWidth = 1.7;
ax.Position = [0.16, 0.12, 0.80, 0.76];
ax.XAxis.TickLength = [0.014 0.014];
box off;

statsLabels = sprintf('\\bfActive channels:\\rm\n\\bfChannels with increased burst rate:\\rm\n\\bfChannels with decreased burst rate:\\rm');
statsValues = sprintf('%d\n%.1f%%\n%.1f%%', nCh, pctIncrease, pctDecrease);
annotation(fig, 'textbox', [0.28, 0.865, 0.52, 0.11], 'String', statsLabels, ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontSize', 14, 'FontName', 'Arial', 'EdgeColor', 'none', 'Interpreter', 'tex');
annotation(fig, 'textbox', [0.805, 0.865, 0.155, 0.11], 'String', statsValues, ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
    'FontSize', 14, 'FontName', 'Arial', 'EdgeColor', 'none', 'Interpreter', 'tex');

filename1 = 'burst_rate_baseline_vs_treatment.png';
fullPath1 = fullfile(outputPath, filename1);
try
    exportgraphics(fig, fullPath1, 'Resolution', 300);
catch
    set(fig, 'PaperPositionMode', 'auto');
    print(fig, fullPath1, '-dpng', '-r300');
end
close(fig);

fprintf('Figure saved to: %s\n', fullPath1);

%==============================================================================
% Figure 2: Boxplot (burst rate) - styling matches figures_spike_rate.m boxplot
%==============================================================================
y = [ratesBaseline; ratesTreatment];
g = [ones(nCh, 1); 2 * ones(nCh, 1)];

fprintf('Creating boxplot figure...\n');
fig = figure('Visible', 'off', 'Position', [100, 100, 600, 600], 'Color', 'w');
set(fig, 'Units', 'inches');
set(fig, 'PaperUnits', 'inches');
set(fig, 'PaperSize', [6, 6]);
set(fig, 'PaperPosition', [0, 0, 6, 6]);
hold on;

% Box-and-whisker: quartiles, median, whiskers (1.5*IQR), outliers
boxplot(y, g, ...
    'Positions', [1, 1.26], ...
    'Labels', {xLabelBaseline, xLabelTreatment}, ...
    'Widths', 0.14, ...
    'Symbol', '');

% Style box plot elements (median line and box face) via axes children
hBox = findobj(gca, 'Tag', 'Box');
for j = 1:length(hBox)
    xd = get(hBox(j), 'XData');
    yd = get(hBox(j), 'YData');
    if j == 1
        hp = patch(xd, yd, colorTreatmentBox, 'FaceAlpha', 0.6, 'EdgeColor', 'none');
        uistack(hp, 'bottom');
        set(hBox(j), 'Color', colorTreatmentOutline, 'LineWidth', 1.2);
    else
        hp = patch(xd, yd, colorBaselineBox, 'FaceAlpha', 0.6, 'EdgeColor', 'none');
        uistack(hp, 'bottom');
        set(hBox(j), 'Color', colorBaselineOutline, 'LineWidth', 1.2);
    end
end
hMed = findobj(gca, 'Tag', 'Median');
set(hMed, 'Color', [0 0 0], 'LineWidth', 1.5);
hWhisker = [findobj(gca, 'Tag', 'Upper Whisker'); findobj(gca, 'Tag', 'Lower Whisker')];
if ~isempty(hWhisker)
    set(hWhisker, 'Color', [0.3 0.3 0.3], 'LineStyle', '-', 'LineWidth', 1.2);
end

% Shorter min/max (cap) lines at whisker ends
hCap = [findobj(gca, 'Tag', 'Upper Adjacent Value'); findobj(gca, 'Tag', 'Lower Adjacent Value')];
for k = 1:length(hCap)
    xd = get(hCap(k), 'XData');
    xm = (xd(1) + xd(2)) / 2;
    d = (xd(2) - xd(1)) * 0.5;
    set(hCap(k), 'XData', [xm - d/2, xm + d/2], 'LineWidth', 1.2);
end

% Overlay mean as dashed horizontal line for each group (mean excludes outliers, 1.5*IQR rule)
q1B = prctile(ratesBaseline, 25); q3B = prctile(ratesBaseline, 75); iqrB = q3B - q1B;
inRangeB = ratesBaseline >= (q1B - 1.5*iqrB) & ratesBaseline <= (q3B + 1.5*iqrB);
if sum(inRangeB) > 0
    meanBaseline = mean(ratesBaseline(inRangeB));
else
    meanBaseline = mean(ratesBaseline);
end
q1T = prctile(ratesTreatment, 25); q3T = prctile(ratesTreatment, 75); iqrT = q3T - q1T;
inRangeT = ratesTreatment >= (q1T - 1.5*iqrT) & ratesTreatment <= (q3T + 1.5*iqrT);
if sum(inRangeT) > 0
    meanTreatment = mean(ratesTreatment(inRangeT));
else
    meanTreatment = mean(ratesTreatment);
end
% Mean line x-range from actual box edges (hBox(1) is right/DOI, hBox(2) is left/Baseline in MATLAB order)
xd1 = get(hBox(1), 'XData'); x1Left = min(xd1); x1Right = max(xd1);
xd2 = get(hBox(2), 'XData'); x2Left = min(xd2); x2Right = max(xd2);
hMean1 = plot([x2Left, x2Right], [meanBaseline, meanBaseline], '--', 'Color', colorBaselineOutline, 'LineWidth', 1.2);
hMean2 = plot([x1Left, x1Right], [meanTreatment, meanTreatment], '--', 'Color', colorTreatmentOutline, 'LineWidth', 1.2);
uistack([hMean1, hMean2], 'top');

% Axes
xlim([0.82, 1.38]);
xticks([1, 1.26]);
xticklabels({'', ''});
ymax = max([ratesBaseline; ratesTreatment]);
ylim([0, ymax * 1.05]);
yTop = ymax * 1.05;
yTickStep = computeNiceTickStep(yTop, 8);
yticks(0:yTickStep:ceil(yTop / yTickStep) * yTickStep);
ylabel('');
set(gca, 'FontSize', 18, 'FontName', 'Arial', 'TickDir', 'out', 'FontWeight', 'bold');
ax = gca;
ax.XAxis.FontSize = 18;
ax.YAxis.FontSize = 18;
ax.YAxis.FontWeight = 'bold';
ax.LineWidth = 1.7;
ax.Position = [0.16, 0.12, 0.80, 0.84];
ax.XAxis.TickLength = [0.014 0.014];
box off;

filename2 = 'burst_rate_boxplot.png';
fullPath2 = fullfile(outputPath, filename2);
try
    exportgraphics(fig, fullPath2, 'Resolution', 300);
catch
    set(fig, 'PaperPositionMode', 'auto');
    print(fig, fullPath2, '-dpng', '-r300');
end
close(fig);

fprintf('Figure saved to: %s\n', fullPath2);

end

%--------------------------------------------------------------------------
% Paired-line figure: vertical IQR bar (Q1-Q3), caps, black mean dot.
% Q1/Q3/mean use only points inside Tukey 1.5*IQR fences (match boxplot whiskers).
%--------------------------------------------------------------------------
function plotMeanIqrMarker(ax, x, yData, capHalfWidth, lineWidth, meanMarkerSize)
y = yData(:);
q1f = prctile(y, 25);
q3f = prctile(y, 75);
iqr = q3f - q1f;
if iqr > 0
    lo = q1f - 1.5 * iqr;
    hi = q3f + 1.5 * iqr;
    yIn = y(y >= lo & y <= hi);
else
    yIn = y;
end
if isempty(yIn)
    yIn = y;
end
q1q3 = prctile(yIn, [25 75]);
q1 = q1q3(1);
q3 = q1q3(2);
mu = mean(yIn);
hold(ax, 'on');
h1 = plot(ax, [x x], [q1 q3], 'k-', 'LineWidth', lineWidth);
h2 = plot(ax, [x - capHalfWidth, x + capHalfWidth], [q1 q1], 'k-', 'LineWidth', lineWidth);
h3 = plot(ax, [x - capHalfWidth, x + capHalfWidth], [q3 q3], 'k-', 'LineWidth', lineWidth);
h4 = plot(ax, x, mu, 'o', 'Color', 'k', 'MarkerFaceColor', 'k', 'MarkerSize', meanMarkerSize, 'LineWidth', 0.35);
uistack([h1, h2, h3, h4], 'top');
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

%--------------------------------------------------------------------------
% Build cache filename for one dataset (must match figures_preprocess_and_save.m)
%--------------------------------------------------------------------------
function name = figures_cache_filename(datasetName)
safe = strrep(strrep(datasetName, '-', '_'), '#', '_');
name = sprintf('figures_cache_%s.mat', safe);
end

%--------------------------------------------------------------------------
% Get burst rates (bursts/min) per channel. Same load/filter/TDTthresh as
% figures_spike_rate; burst detection and rate formula from burst_stats.m.
% Returns [burstRates, durationSec]. Failed channels set to NaN.
%--------------------------------------------------------------------------
function [burstRates, durationSec] = getBurstRatesPerChannel(BLOCKPATH, STORE, CHANNELS, BP_FILTER, max_harmonic, notch_base, Q, isiMax, isiEnd, minSpikes)
    nCh = length(CHANNELS);
    burstRates = NaN(nCh, 1);
    durationSec = NaN;
    channels_prog = waitbar(0, 'Processing channels...');
    for i = 1:nCh
        ch = CHANNELS(i);
        try
            rawData = TDTbin2mat(BLOCKPATH, 'STORE', STORE, 'CHANNEL', ch);
        catch
            waitbar(i / nCh, channels_prog, sprintf('Processing Channel %d of %d', ch, nCh));
            continue;
        end
        fs = rawData.streams.(STORE).fs;
        x = double(rawData.streams.(STORE).data(:));
        if isnan(durationSec)
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

        if isempty(spikes) || ~isfield(spikes, 'snips') || ~isfield(spikes.snips, 'Snip') || ~isfield(spikes.snips.Snip, 'ts')
            burstRates(i) = NaN;
            waitbar(i / nCh, channels_prog, sprintf('Processing Channel %d of %d', ch, nCh));
            continue;
        end

        ts = sort(spikes.snips.Snip.ts(:));

        if numel(ts) < minSpikes
            burstRates(i) = 0;
            waitbar(i / nCh, channels_prog, sprintf('Processing Channel %d of %d', ch, nCh));
            continue;
        end

        % Burst detection (same state machine as burst_stats.m)
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
                    burstEnds(end+1) = endIdx;    %#ok<AGROW>
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

        waitbar(i / nCh, channels_prog, sprintf('Processing Channel %d of %d', ch, nCh));
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
