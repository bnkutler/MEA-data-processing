%{
--------------------------------------------------------------------------
FUNCTION NAME: figures_burst_pct_change_violin

DESCRIPTION:
    Vertical violin plot of channel-wise burst rate percent change (baseline
    vs DOI).     Loads burstRates from preprocess cache (same as figures_burst_rate.m).
    Uses ignoreSilentChannels / minRateThreshold on burstRates like figures_burst_rate.m
    (default minRateThreshold 0: drop only both-burst-zero pairs). Includes only baseline
    burst rate > 0 among remaining channels. Optional excludeSilencedPct: if true,
    drops pct ~ -100%% (burst silenced); if false (default), keeps them. Excludes channels
    where both baseline and treatment spike rates are < 0, or both spike rates are 0.
    Optional pctMaxInclude caps large positive outliers.
    Y-axis lower limit is fixed at -100%%. Upper ylim is always a multiple of 100: auto mode rounds headroom
    up to the next 100; manual pctYlim upper is rounded up to nearest 100.
    Boxplot uses Tukey whiskers (1.5*IQR); outlier markers hidden (Symbol '').
    Optional: useKetanserinTreatmentColors (same RGB as figures_spike_rate.m);
    set xLabelCondition (e.g. Ketanserin). Box colors match
    figures_spike_rate_pct_change_histogram.m DOI bars when ketanserin mode is off.
    Inlier
    mean is solid black; median is dashed light blue (1.5*IQR mean rule as
    figures_spike_rate.m). Violin is drawn from slightly above the lower ylim so
    the axis line is the only bottom edge; left/right violin edge lines only.
    y = 0% reference line only. Set pctYlim to the same numeric vector as
    figures_spike_pct_change_violin.m for directly comparable y-scales.

INPUTS:
    None - Edit baselineList, treatmentList, CHANNELS, pctYlim ([] = auto top
    rounded to 100s from Tukey upper fence), styling below.

OUTPUTS:
    Figure saved to pipeline/figures/burst_pct_change_violin_doi.png
--------------------------------------------------------------------------
%}
function figures_burst_pct_change_violin()

outputPath = '/Users/bkutler4/Desktop/hai_lab/pipeline/figures';
CACHEPATH = fullfile('/Users/bkutler4/Desktop/hai_lab/pipeline', 'figures', 'cache');

if ~exist(outputPath, 'dir')
    mkdir(outputPath);
end

% Y-axis (% change): [] => auto top = ceil(q3+1.5*IQR) to nearest 100 (+data safeguard)
pctYlim = [];

% Optional: exclude pct above this (e.g. match histogram); [] disables
pctMaxInclude = 1000;

% If true, drop observations with pct ~ -100%% (treatment burst rate 0); if false, include them
excludeSilencedPct = false;
silenceTol = 1e-6;       % abs(pct + 100) < this => silenced when excludeSilencedPct is true

% DOI histogram colors — figures_spike_rate_pct_change_histogram.m
colorTreatment = [0.25, 0.40, 0.60];
colorTreatmentOutline = [0.35, 0.50, 0.70];
histFaceAlpha = 0.75;

% If true, same ketanserin treatment colors as figures_spike_rate.m; set xLabelCondition (e.g. Ketanserin)
useKetanserinTreatmentColors = true;
if useKetanserinTreatmentColors
    colorTreatment = [0.90, 0.50, 0.12];
    colorTreatmentOutline = [0.76, 0.48, 0.22];
end

% Violin: lighter than box (blend toward white); edge = soft outline
violinFaceColor = 0.35 * colorTreatment + 0.65 * [1, 1, 1];
violinEdgeColor = 0.55 * colorTreatmentOutline + 0.45 * [1, 1, 1];
violinHalfWidth = 0.32;
violinYGridN = 180;
violinFaceAlpha = 0.45;
% Keep a tiny epsilon gap so the violin fill doesn't occlude the x-axis,
% but still visually "touches" the axis.
violinBottomGapFrac = 0.001;

% Category
xCenter = 1;
xLabelCondition = 'DOI';
boxWidth = 0.16;

% Match figures_burst_rate.m (bursts/min on burstRates)
ignoreSilentChannels = true;
minRateThreshold = 0;  % bursts/min; 0 => drop only when baseline & treatment burst are both 0; >0 => both below threshold

CHANNELS = 1:64;

%==================================================================================================================================================================================================
% ALL DATASETS (commented out - copy names into baselineList and treatmentList below)
%==================================================================================================================================================================================================
% Control (baseline):
% 'IdoControl-230914-130200_#1','IdoControl-230914-131548_#2','IdoControl-230914-132855_#3','IdoControl-230914-154022_#4','IdoControl-230914-155318_#5','IdoControl-230914-160601_#6'
% DOI (treatment):
% 'IdoDOI-230914-142502_#1','IdoDOI-230914-143740_#2','IdoDOI-230914-144945_#3','IdoDOI-230914-161838_#4','IdoDOI-230914-163140_#5','IdoDOI-230914-164512_#6'
% Control 2 / Ketanserin: (for future companion figures; reuse same pctYlim)
%==================================================================================================================================================================================================

  baselineList = {'IdoControl-231101-144046_#1','IdoControl-231101-145330_#2','IdoControl-231101-150512_#3'};
  treatmentList = {'IdoKetanserin-231101-133725_#1','IdoKetanserin-231101-134946_#2','IdoKetanserin-231101-140237_#3'};
 % baselineList = {'IdoControl-230914-130200_#1','IdoControl-230914-131548_#2','IdoControl-230914-132855_#3','IdoControl-230914-154022_#4','IdoControl-230914-155318_#5','IdoControl-230914-160601_#6'};
 % treatmentList = {'IdoDOI-230914-142502_#1','IdoDOI-230914-143740_#2','IdoDOI-230914-144945_#3','IdoDOI-230914-161838_#4','IdoDOI-230914-163140_#5','IdoDOI-230914-164512_#6'};

if isempty(baselineList) || isempty(treatmentList)
    error('baselineList and treatmentList must each contain at least one dataset name.');
end
if length(baselineList) ~= length(treatmentList)
    error('baselineList and treatmentList must have the same length.');
end

nPairs = numel(baselineList);
pctAll = [];
nExcludedSpikeBothNeg = 0;
nExcludedSpikeBothZero = 0;

for pairIdx = 1:nPairs
    baselineName = baselineList{pairIdx};
    treatmentName = treatmentList{pairIdx};

    cachePathBaseline = fullfile(CACHEPATH, figures_cache_filename(baselineName));
    cachePathTreatment = fullfile(CACHEPATH, figures_cache_filename(treatmentName));
    if ~exist(cachePathBaseline, 'file')
        error('No cache found for dataset ''%s''.\nRun figures_preprocess_and_save.m first.\nExpected: %s', baselineName, cachePathBaseline);
    end
    if ~exist(cachePathTreatment, 'file')
        error('No cache found for dataset ''%s''.\nRun figures_preprocess_and_save.m first.\nExpected: %s', treatmentName, cachePathTreatment);
    end
    fprintf('Loading pair %d/%d: %s vs %s\n', pairIdx, nPairs, baselineName, treatmentName);

    loadedB = load(cachePathBaseline);
    loadedT = load(cachePathTreatment);
    burstRatesBaseline = loadedB.burstRates(:);
    burstRatesTreatment = loadedT.burstRates(:);
    spikeRatesBaseline = loadedB.rates(:);
    spikeRatesTreatment = loadedT.rates(:);
    channelsUsedB = loadedB.channelsUsed(:)';
    channelsUsedT = loadedT.channelsUsed(:)';

    [~, idxB] = ismember(CHANNELS, channelsUsedB);
    [~, idxT] = ismember(CHANNELS, channelsUsedT);
    validIdx = (idxB > 0) & (idxT > 0);
    if ~any(validIdx)
        continue;
    end

    b = burstRatesBaseline(idxB(validIdx));
    t = burstRatesTreatment(idxT(validIdx));
    sB = spikeRatesBaseline(idxB(validIdx));
    sT = spikeRatesTreatment(idxT(validIdx));

    valid = ~isnan(b) & ~isnan(t) & ~isnan(sB) & ~isnan(sT);
    b = b(valid);
    t = t(valid);
    sB = sB(valid);
    sT = sT(valid);

    if ignoreSilentChannels
        if minRateThreshold == 0
            nonSilent = ~(b == 0 & t == 0);
        else
            nonSilent = ~(b < minRateThreshold & t < minRateThreshold);
        end
        b = b(nonSilent);
        t = t(nonSilent);
        sB = sB(nonSilent);
        sT = sT(nonSilent);
    end
    if isempty(b)
        continue;
    end

    bothSpikeNeg = sB < 0 & sT < 0;
    bothSpikeZero = sB == 0 & sT == 0;
    keepSpike = ~(bothSpikeNeg | bothSpikeZero);
    nExcludedSpikeBothNeg = nExcludedSpikeBothNeg + sum(bothSpikeNeg);
    nExcludedSpikeBothZero = nExcludedSpikeBothZero + sum(bothSpikeZero);
    b = b(keepSpike);
    t = t(keepSpike);
    sB = sB(keepSpike);
    sT = sT(keepSpike);

    use = b > 0;
    b = b(use);
    t = t(use);

    pctPair = 100 * (t - b) ./ b;
    pctAll = [pctAll; pctPair]; %#ok<AGROW>
end

if isempty(pctAll)
    error('No valid channel observations (baseline burst rate > 0, aligned channels).');
end

if nExcludedSpikeBothNeg > 0
    fprintf('Excluded channels with spike rate < 0 on both baseline and treatment: %d\n', nExcludedSpikeBothNeg);
end
if nExcludedSpikeBothZero > 0
    fprintf('Excluded channels with 0 spike/min on both baseline and treatment: %d\n', nExcludedSpikeBothZero);
end

if excludeSilencedPct
    nBeforeSilence = numel(pctAll);
    nonSilent = abs(pctAll + 100) >= silenceTol;
    pctData = pctAll(nonSilent);
    nSilenced = nBeforeSilence - numel(pctData);
    fprintf('Excluded burst-silenced (-100%%): %d  |  Remaining: %d\n', nSilenced, numel(pctData));
    if isempty(pctData)
        error('No observations after excluding -100%% burst-silenced channels.');
    end
else
    pctData = pctAll;
    fprintf('Burst %% change observations (includes burst-silenced at -100%%): %d\n', numel(pctData));
end

if ~isempty(pctMaxInclude)
    keep = pctData <= pctMaxInclude;
    nDropHi = sum(~keep);
    pctData = pctData(keep);
    fprintf('Excluded pct > %.0f%%: %d  |  Remaining: %d\n', pctMaxInclude, nDropHi, numel(pctData));
end

if isempty(pctData)
    error('No observations after pctMaxInclude filter.');
end

q1 = prctile(pctData, 25);
q3 = prctile(pctData, 75);
iqrPct = q3 - q1;
upperFence = q3 + 1.5 * iqrPct;

if isempty(pctYlim)
    yRoundFence = ceil(upperFence / 100) * 100;
    maxPct = max(pctData);
    if maxPct > yRoundFence
        yLimTop = ceil(maxPct / 100) * 100;
    else
        yLimTop = yRoundFence;
    end
    labelHeadroom = max(15, 0.03 * (yLimTop + 100));
    yLimHi = ceil((yLimTop + labelHeadroom) / 100) * 100;
    yLimUse = [-100, yLimHi];
    fprintf('Auto y-limits: [%.2f %.2f]  (floor -100%%; top rounded up to nearest 100 after Tukey fence + headroom). Copy pctYlim for cross-figure comparison.\n', yLimUse(1), yLimUse(2));
else
    yLimUse = pctYlim(:)';
    yLimUse(1) = -100;
    yLimUse(2) = ceil(yLimUse(2) / 100) * 100;
end

% Summary stats (on plotted data)
medPct = median(pctData, 'omitnan');
inRangePct = pctData >= (q1 - 1.5 * iqrPct) & pctData <= (q3 + 1.5 * iqrPct);
if sum(inRangePct) > 0
    meanPctInlier = mean(pctData(inRangePct));
else
    meanPctInlier = mean(pctData);
end
nCh = numel(pctData);

fprintf('Median: %.2f%%  |  IQR: [%.2f, %.2f]%%  |  Mean (1.5*IQR inliers): %.2f%%  |  N: %d  |  Pairs: %d\n', ...
    medPct, q1, q3, meanPctInlier, nCh, nPairs);

%--------------------------------------------------------------------------
% Figure
%--------------------------------------------------------------------------
fprintf('Creating violin figure...\n');
fig = figure('Visible', 'off', 'Position', [100, 100, 380, 620], 'Color', 'w');
set(fig, 'Units', 'inches');
set(fig, 'PaperUnits', 'inches');
set(fig, 'PaperSize', [3.8, 6.2]);
set(fig, 'PaperPosition', [0, 0, 3.8, 6.2]);
hold on;

ylim(yLimUse);
spanY = yLimUse(2) - yLimUse(1);
violinYLo = yLimUse(1) + max(0, violinBottomGapFrac * spanY);
yGrid = linspace(violinYLo, yLimUse(2), violinYGridN)';

try
    [f, ~] = ksdensity(pctData, yGrid, 'BoundaryCorrection', 'reflection');
catch
    [f, ~] = ksdensity(pctData, yGrid);
end
hViolin = [];
fMax = max(f);
if fMax > 0
    fNorm = (f / fMax) * violinHalfWidth;
    xL = xCenter - fNorm(:);
    xR = xCenter + fNorm(:);
    hViolin = patch([xL; flipud(xR)], [yGrid; flipud(yGrid)], violinFaceColor, ...
        'FaceAlpha', violinFaceAlpha, 'EdgeColor', 'none');
    uistack(hViolin, 'bottom');
    plot(xL, yGrid, 'Color', violinEdgeColor, 'LineWidth', 1);
    plot(xR, yGrid, 'Color', violinEdgeColor, 'LineWidth', 1);
    uistack(hViolin, 'bottom');
end

yline(0, '-', 'Color', [0 0 0], 'LineWidth', 1.0);

boxplot(pctData, 'Positions', xCenter, 'Widths', boxWidth, 'Symbol', '', 'Colors', [0 0 0]);
ylim(yLimUse);
hBox = findobj(gca, 'Tag', 'Box');
for j = 1:numel(hBox)
    xd = get(hBox(j), 'XData');
    yd = get(hBox(j), 'YData');
    hpBox = patch(xd, yd, colorTreatment, 'FaceAlpha', histFaceAlpha, 'EdgeColor', 'none');
    uistack(hpBox, 'bottom');
    if ~isempty(hViolin)
        uistack(hViolin, 'bottom');
    end
    set(hBox(j), 'Color', colorTreatmentOutline, 'LineWidth', 1.2);
end
hMed = findobj(gca, 'Tag', 'Median');
if ~isempty(hMed)
    set(hMed, 'Color', violinEdgeColor, 'LineWidth', 2, 'LineStyle', '--');
end
hWh = [findobj(gca, 'Tag', 'Upper Whisker'); findobj(gca, 'Tag', 'Lower Whisker')];
if ~isempty(hWh)
    set(hWh, 'LineWidth', 1.1, 'Color', [0 0 0], 'LineStyle', '-');
end
hAdj = [findobj(gca, 'Tag', 'Upper Adjacent Value'); findobj(gca, 'Tag', 'Lower Adjacent Value')];
for k = 1:numel(hAdj)
    xd = get(hAdj(k), 'XData');
    xm = (xd(1) + xd(2)) / 2;
    d = (xd(2) - xd(1)) * 0.5;
    set(hAdj(k), 'XData', [xm - d/2, xm + d/2], 'LineWidth', 1.2, 'Color', [0 0 0], 'LineStyle', '-');
end

if ~isempty(hBox)
    xdBox = get(hBox(1), 'XData');
    xMeanLeft = min(xdBox);
    xMeanRight = max(xdBox);
    hMeanLn = plot([xMeanLeft, xMeanRight], [meanPctInlier, meanPctInlier], '-', ...
        'Color', [0 0 0], 'LineWidth', 1.2);
    uistack(hMeanLn, 'top');
end

xlim([0.62, 1.38]);
xticks(xCenter);
xticklabels({xLabelCondition});

ylabel('Percent change in burst rate (%)', 'FontSize', 18, 'FontName', 'Arial', 'FontWeight', 'bold');
set(gca, 'FontSize', 18, 'FontName', 'Arial', 'TickDir', 'out', 'FontWeight', 'bold', 'YGrid', 'off', 'XGrid', 'off');
ax = gca;
ax.XAxis.FontSize = 18;
ax.YAxis.FontSize = 18;
ax.YAxis.FontWeight = 'bold';
ax.LineWidth = 1.7;
ax.Position = [0.20, 0.10, 0.72, 0.74];
ax.XAxis.TickLength = [0.014 0.014];
ax.YAxis.TickLength = [0.014 0.014];
box off;

% Redraw x-axis last so the black axis line remains visible on top
% of the violin/box elements.
hXAxis = plot([0.62, 1.38], [yLimUse(1), yLimUse(1)], '-', ...
    'Color', [0 0 0], 'LineWidth', 1.7);
uistack(hXAxis, 'top');

yTickStep = computeNiceTickStep(yLimUse(2) - yLimUse(1), 9);
ytVals = yLimUse(1):yTickStep:yLimUse(2);
if isempty(ytVals) || ytVals(end) < yLimUse(2)
    ytVals = [ytVals, yLimUse(2)];
end
ytVals = unique([ytVals(:); 0]);
ytVals = sort(ytVals);
yticks(ytVals);

filename = 'burst_pct_change_violin_doi.png';
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
function name = figures_cache_filename(datasetName)
safe = strrep(strrep(datasetName, '-', '_'), '#', '_');
name = sprintf('figures_cache_%s.mat', safe);
end

%--------------------------------------------------------------------------
function step = computeNiceTickStep(span, targetTickCount)
if span <= 0 || targetTickCount < 2
    step = 50;
    return;
end
rawStep = span / (targetTickCount - 1);
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
