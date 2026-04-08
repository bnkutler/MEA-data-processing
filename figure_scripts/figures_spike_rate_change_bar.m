%{
--------------------------------------------------------------------------
FUNCTION NAME: figures_spike_rate_change_bar

DESCRIPTION:
    Boxplots of per-dataset percentages (silenced / decreased / increased) for
    baseline-active channels (spike rate from cache, same pipeline as
    figures_spike_rate.m). For each aligned channel with baseline rate > 0:
        Silenced  — treatment spike rate == 0 (was active, now silent)
        Decreased — treatment rate > 0 and < baseline (still active, lower)
        Increased — treatment rate > baseline
    Channels with baseline rate == 0 are excluded. Unchanged (within tolerance)
    is excluded from the percentage denominator (n = silenced+decreased+increased
    per pair); unchanged counts remain in console output.
    After aggregation, prints a chi-square goodness-of-fit test (50/50) on
    increased vs decreased counts only (silenced and unchanged excluded), with
    a significance line at p < 0.05. Requires Statistics and Machine Learning
    Toolbox (chi2cdf).

INPUTS:
    None - Edit baselineList, treatmentList, and CHANNELS at top of script.

OUTPUTS:
    Figure saved to pipeline/figures/spike_rate_change_categories.png
    Requires figures_preprocess_and_save.m cache for each dataset name.
    Console: chi-square summary for increase vs decrease (non-silenced).
    Figure has no axis labels or title; see comment block above the figure for
    suggested y-axis, x-axis, and title text for publication.
--------------------------------------------------------------------------
%}
function figures_spike_rate_change_bar()

outputPath = '/Users/bkutler4/Desktop/hai_lab/pipeline/figures';
CACHEPATH = fullfile('/Users/bkutler4/Desktop/hai_lab/pipeline', 'figures', 'cache');

if ~exist(outputPath, 'dir')
    mkdir(outputPath);
end

% Colors (match figures_spike_rate.m paired plot)
colorSilenced = [0.38, 0.38, 0.38];
colorDecrease = [0.82, 0.58, 0.58];
colorIncrease = [0.5, 0.72, 0.55];
rateEqualRelTol = 1e-6;  % |t-b| <= relTol*max(b,eps) counts as unchanged (both > 0)

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

baselineList = {'IdoControl-231101-144046_#1','IdoControl-231101-145330_#2','IdoControl-231101-150512_#3'};
treatmentList = {'IdoKetanserin-231101-133725_#1','IdoKetanserin-231101-134946_#2','IdoKetanserin-231101-140237_#3'};

if isempty(baselineList) || isempty(treatmentList)
    error('baselineList and treatmentList must each contain at least one dataset name.');
end
if length(baselineList) ~= length(treatmentList)
    error('baselineList and treatmentList must have the same length.');
end

nSilenced = 0;
nDecreased = 0;
nIncreased = 0;
nUnchanged = 0;
pctSil = [];
pctDec = [];
pctInc = [];

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

    b = ratesBaseline(idxB(validIdx));
    t = ratesTreatment(idxT(validIdx));

    valid = ~isnan(b) & ~isnan(t);
    b = b(valid);
    t = t(valid);

    use = b > 0;
    b = b(use);
    t = t(use);

    silent = (t == 0);
    nS = sum(silent);
    nSilenced = nSilenced + nS;

    active = ~silent;
    b2 = b(active);
    t2 = t(active);

    if isempty(b2)
        nD = 0;
        nI = 0;
        nU = 0;
    else
        diff = t2 - b2;
        thresh = rateEqualRelTol .* max(b2, eps);
        unch = abs(diff) <= thresh;
        inc = diff > 0 & ~unch;
        dec = diff < 0 & ~unch;
        nD = sum(dec);
        nI = sum(inc);
        nU = sum(unch);
    end
    nIncreased = nIncreased + nI;
    nDecreased = nDecreased + nD;
    nUnchanged = nUnchanged + nU;

    nDenom = nS + nD + nI;
    if nDenom == 0
        warning('Pair %d (%s vs %s): all channels unchanged (within tol); excluded from percent boxplot.', pairIdx, baselineName, treatmentName);
        continue;
    end
    pctSil(end+1) = 100 * nS / nDenom; %#ok<AGROW>
    pctDec(end+1) = 100 * nD / nDenom; %#ok<AGROW>
    pctInc(end+1) = 100 * nI / nDenom; %#ok<AGROW>
end

nClassified = nSilenced + nDecreased + nIncreased + nUnchanged;
if nClassified == 0
    error('No valid channel observations (need baseline spike rate > 0 and aligned channels in cache).');
end

fprintf('Baseline-active channel observations: %d\n', nClassified);
fprintf('  Silenced:  %d\n', nSilenced);
fprintf('  Decreased: %d\n', nDecreased);
fprintf('  Increased: %d\n', nIncreased);
fprintf('  Unchanged: %d\n', nUnchanged);

printIncreaseDecreaseChi2Gof(nIncreased, nDecreased);

if isempty(pctSil)
    error('No dataset pairs with nonzero silenced+decreased+increased denominator (cannot build percent boxplot).');
end

%--------------------------------------------------------------------------
% Suggested publication text (figure has no labels/title on axes):
%   Y-axis:  Percent of channels (or Percentage (%)); caption: among baseline-
%            active channels; denominator excludes unchanged; three categories
%            sum to 100% per recording.
%   X-axis:  Silenced | Decreased | Increased
%   Title:   Distribution of channel response categories across recordings (spike rate)
%--------------------------------------------------------------------------
fprintf('Creating boxplot figure...\n');
fig = figure('Visible', 'off', 'Position', [100, 100, 600, 600], 'Color', 'w');
set(fig, 'Units', 'inches');
set(fig, 'PaperUnits', 'inches');
set(fig, 'PaperSize', [6, 6]);
set(fig, 'PaperPosition', [0, 0, 6, 6]);
hold on;

n = numel(pctSil);
y = [pctSil(:); pctDec(:); pctInc(:)];
g = [ones(n, 1); 2 * ones(n, 1); 3 * ones(n, 1)];
% Match original bar chart: categories at x = 1, 2, 3 (BarWidth was 0.65)
boxPositions = [1, 2, 3];
boxplot(y, g, ...
    'Positions', boxPositions, ...
    'Labels', {'', '', ''}, ...
    'Widths', 0.55, ...
    'Symbol', '');

% Style boxes (left to right: Silenced, Decreased, Increased)
hBox = findobj(gca, 'Tag', 'Box');
nx = zeros(length(hBox), 1);
for jb = 1:length(hBox)
    xd = get(hBox(jb), 'XData');
    nx(jb) = mean(xd(:));
end
[~, sortIdx] = sort(nx);
hBoxSorted = hBox(sortIdx);
faceColors = [colorSilenced; colorDecrease; colorIncrease];
outlineColors = [0.22, 0.22, 0.22; 0.55, 0.35, 0.35; 0.28, 0.45, 0.28];
for jb = 1:length(hBoxSorted)
    xd = get(hBoxSorted(jb), 'XData');
    yd = get(hBoxSorted(jb), 'YData');
    hp = patch(xd, yd, faceColors(jb, :), 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    uistack(hp, 'bottom');
    set(hBoxSorted(jb), 'Color', outlineColors(jb, :), 'LineWidth', 1.2);
end
hMed = findobj(gca, 'Tag', 'Median');
set(hMed, 'Color', [0 0 0], 'LineWidth', 1.5);
hWhisker = [findobj(gca, 'Tag', 'Upper Whisker'); findobj(gca, 'Tag', 'Lower Whisker')];
if ~isempty(hWhisker)
    set(hWhisker, 'Color', [0.3 0.3 0.3], 'LineStyle', '-', 'LineWidth', 1.2);
end
hCap = [findobj(gca, 'Tag', 'Upper Adjacent Value'); findobj(gca, 'Tag', 'Lower Adjacent Value')];
for k = 1:length(hCap)
    xd = get(hCap(k), 'XData');
    xm = (xd(1) + xd(2)) / 2;
    d = (xd(2) - xd(1)) * 0.5;
    set(hCap(k), 'XData', [xm - d/2, xm + d/2], 'LineWidth', 1.2);
end

meanVals = [mean(pctSil), mean(pctDec), mean(pctInc)];
for jb = 1:3
    xd = get(hBoxSorted(jb), 'XData');
    x1 = min(xd(:));
    x2 = max(xd(:));
    plot([x1, x2], [meanVals(jb), meanVals(jb)], '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.2);
end

set(gca, 'FontSize', 18, 'FontName', 'Arial', 'TickDir', 'out', 'FontWeight', 'bold');
ax = gca;
ax.XAxis.FontSize = 16;
ax.YAxis.FontSize = 18;
ax.YAxis.FontWeight = 'bold';
ax.LineWidth = 1.7;
ax.Position = [0.18, 0.18, 0.74, 0.68];
ax.XAxis.TickLength = [0.014 0.014];
ax.YAxis.TickLength = [0.014 0.014];
box off;
xlabel('');
ylabel('');
title('');
xlim([0.5, 3.5]);
ylim([0, 100 * 1.05]);
yTickStep = computeNiceTickStep(100 * 1.05, 8);
yticks(0:yTickStep:ceil(100 * 1.05 / yTickStep) * yTickStep);

if nUnchanged > 0
    annotation(fig, 'textbox', [0.35, 0.88, 0.55, 0.08], ...
        'String', sprintf('Unchanged (within tol): %d', nUnchanged), ...
        'FontSize', 12, 'FontName', 'Arial', 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
end

filename = 'spike_rate_change_categories.png';
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
function printIncreaseDecreaseChi2Gof(nIncreased, nDecreased)
N = nIncreased + nDecreased;
if N == 0
    fprintf(['Increase vs Decrease (excluding silenced): No channels with directional change ', ...
        '(all non-silenced unchanged or no observations); chi-square not computed.\n']);
    fprintf('Goodness-of-fit vs 50/50: not applicable.\n');
    return;
end
obs = [nIncreased, nDecreased];
expCounts = [N / 2, N / 2];
chi2_stat = sum((obs - expCounts).^2 ./ expCounts);
df = 1;
try
    p = 1 - chi2cdf(chi2_stat, df);
catch ME
    fprintf('Chi-square / chi2cdf failed: %s\n', ME.message);
    return;
end
pctInc = 100 * nIncreased / N;
pctDec = 100 * nDecreased / N;
pStr = formatPChi2Bar(p);
fprintf(['Increase vs Decrease (excluding silenced): Increased = %.1f%% (%d), ', ...
    'Decreased = %.1f%% (%d); Chi-square goodness-of-fit vs 50/50: chi2(%d) = %.4g, p = %s\n'], ...
    pctInc, nIncreased, pctDec, nDecreased, df, chi2_stat, pStr);
if p < 0.05
    fprintf('The deviation from a 50/50 split is statistically significant (p < 0.05).\n');
else
    fprintf('The deviation from a 50/50 split is not statistically significant (p >= 0.05).\n');
end
end

%--------------------------------------------------------------------------
function s = formatPChi2Bar(p)
if p < 0.001
    s = '<0.001';
elseif p < 0.01
    s = sprintf('%.3f', p);
else
    s = sprintf('%.3g', p);
end
end
