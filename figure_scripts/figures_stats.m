%{
--------------------------------------------------------------------------
FUNCTION NAME: figures_stats

DESCRIPTION:
    Dataset-level summary statistics for percent change in spike rate and burst
    rate (baseline vs treatment per cache pair). Channel-wise filtering matches
    figures_spike_pct_change_violin.m and figures_burst_pct_change_violin.m:
      Spike: drop only both-baseline-and-treatment 0 spikes/min; cap Inf (b=0,t>0)
      to pctMaxInclude or 1e6; optional excludeSilencedPct; optional pct cap.
      Burst: ignoreSilentChannels + minRateThreshold on burst rates; drop both
      spike < 0; drop both spike == 0; baseline burst > 0 for % change; same
      excludeSilencedPct and pctMaxInclude as the burst violin.
    Keeps the per-channel percent-change values remaining after those filters
    (matching the violin plots), then runs a hierarchical bootstrap over
    recordings and channels to estimate the pooled median percent change and
    whether its confidence interval excludes 0.

INPUTS:
    Edit baselineList, treatmentList, CHANNELS, and the flags below to match the
    percent-change violin scripts you are reporting alongside.

OUTPUTS:
    Concise publication-style text to Command Window; optional per-dataset lines
    when verboseDatasetMedians = true.
--------------------------------------------------------------------------
%}
function figures_stats()

CACHEPATH = fullfile('/Users/bkutler4/Desktop/hai_lab/pipeline', 'figures', 'cache');

% --- Match figures_spike_pct_change_violin.m / figures_burst_pct_change_violin.m ---
silenceTol = 1e-6;
pctMaxInclude = 1000;       % [] disables high-end trim (match violin)
excludeSilencedPct = false; % if true, drop pct ~ -100% (silenced rate)

% Burst violin only (figures_burst_pct_change_violin.m):
ignoreSilentChannels = true;
minRateThreshold = 0;     % bursts/min: 0 => drop only both burst == 0; >0 => both < threshold

% If true, print each dataset's median % change and channel count for checking
verboseDatasetMedians = true;

% Hierarchical bootstrap settings (recordings resampled first, then channels)
nBootstrap = 10000;
bootstrapSeed = 1;

CHANNELS = 1:64;

%baselineList = {'IdoControl-231101-144046_#1','IdoControl-231101-145330_#2','IdoControl-231101-150512_#3'};
%treatmentList = {'IdoKetanserin-231101-133725_#1','IdoKetanserin-231101-134946_#2','IdoKetanserin-231101-140237_#3'};
baselineList = {'IdoControl-230914-130200_#1','IdoControl-230914-131548_#2','IdoControl-230914-132855_#3','IdoControl-230914-154022_#4','IdoControl-230914-155318_#5','IdoControl-230914-160601_#6'};
treatmentList = {'IdoDOI-230914-142502_#1','IdoDOI-230914-143740_#2','IdoDOI-230914-144945_#3','IdoDOI-230914-161838_#4','IdoDOI-230914-163140_#5','IdoDOI-230914-164512_#6'};

if isempty(baselineList) || isempty(treatmentList)
    error('baselineList and treatmentList must each contain at least one dataset name.');
end
if numel(baselineList) ~= numel(treatmentList)
    error('baselineList and treatmentList must have the same length.');
end

nPairs = numel(baselineList);
spikeDatasetMedians = NaN(nPairs, 1);
burstDatasetMedians = NaN(nPairs, 1);
spikePctByDataset = cell(nPairs, 1);
burstPctByDataset = cell(nPairs, 1);

for pairIdx = 1:nPairs
    baselineName = baselineList{pairIdx};
    treatmentName = treatmentList{pairIdx};

    cachePathBaseline = fullfile(CACHEPATH, figures_cache_filename(baselineName));
    cachePathTreatment = fullfile(CACHEPATH, figures_cache_filename(treatmentName));
    if ~exist(cachePathBaseline, 'file')
        error('No cache for ''%s''. Expected: %s', baselineName, cachePathBaseline);
    end
    if ~exist(cachePathTreatment, 'file')
        error('No cache for ''%s''. Expected: %s', treatmentName, cachePathTreatment);
    end

    loadedB = load(cachePathBaseline);
    loadedT = load(cachePathTreatment);
    channelsUsedB = loadedB.channelsUsed(:)';
    channelsUsedT = loadedT.channelsUsed(:)';

    [~, idxB] = ismember(CHANNELS, channelsUsedB);
    [~, idxT] = ismember(CHANNELS, channelsUsedT);
    validIdx = (idxB > 0) & (idxT > 0);
    if ~any(validIdx)
        warning('Pair %d: no aligned channels (%s vs %s). Skipped.', pairIdx, baselineName, treatmentName);
        continue;
    end

    rsB = loadedB.rates(:);
    rsT = loadedT.rates(:);

    % --- Spike (same as figures_spike_pct_change_violin.m) ---
    pctS = [];
    bS = rsB(idxB(validIdx));
    tS = rsT(idxT(validIdx));
    okS = ~isnan(bS) & ~isnan(tS);
    bS = bS(okS);
    tS = tS(okS);
    keepS = ~(bS == 0 & tS == 0);
    bS = bS(keepS);
    tS = tS(keepS);
    if isempty(bS)
        medSpike = NaN;
        nSpike = 0;
    else
        pctS = 100 * (tS - bS) ./ bS;
        infMask = isinf(pctS);
        if any(infMask)
            if ~isempty(pctMaxInclude)
                pctS(infMask) = pctMaxInclude;
            else
                pctS(infMask) = 1e6;
            end
        end
        if excludeSilencedPct
            pctS = pctS(abs(pctS + 100) >= silenceTol);
        end
        if ~isempty(pctMaxInclude)
            pctS = pctS(pctS <= pctMaxInclude);
        end
        pctS = pctS(~isnan(pctS));
        nSpike = numel(pctS);
        if nSpike > 0
            medSpike = median(pctS, 'omitnan');
        else
            medSpike = NaN;
        end
    end

    % --- Burst (same as figures_burst_pct_change_violin.m) ---
    pctB = [];
    rbB = loadedB.burstRates(:);
    rbT = loadedT.burstRates(:);
    bB = rbB(idxB(validIdx));
    tB = rbT(idxT(validIdx));
    sB = rsB(idxB(validIdx));
    sT = rsT(idxT(validIdx));
    okB = ~isnan(bB) & ~isnan(tB) & ~isnan(sB) & ~isnan(sT);
    bB = bB(okB);
    tB = tB(okB);
    sB = sB(okB);
    sT = sT(okB);
    if ignoreSilentChannels
        if minRateThreshold == 0
            nonSilent = ~(bB == 0 & tB == 0);
        else
            nonSilent = ~(bB < minRateThreshold & tB < minRateThreshold);
        end
        bB = bB(nonSilent);
        tB = tB(nonSilent);
        sB = sB(nonSilent);
        sT = sT(nonSilent);
    end
    if isempty(bB)
        medBurst = NaN;
        nBurst = 0;
    else
        bothSpikeNeg = sB < 0 & sT < 0;
        bothSpikeZero = sB == 0 & sT == 0;
        keepSpike = ~(bothSpikeNeg | bothSpikeZero);
        bB = bB(keepSpike);
        tB = tB(keepSpike);
        if isempty(bB)
            medBurst = NaN;
            nBurst = 0;
        else
            useB = bB > 0;
            bB = bB(useB);
            tB = tB(useB);
            if isempty(bB)
                medBurst = NaN;
                nBurst = 0;
            else
                pctB = 100 * (tB - bB) ./ bB;
                if excludeSilencedPct
                    pctB = pctB(abs(pctB + 100) >= silenceTol);
                end
                if ~isempty(pctMaxInclude)
                    pctB = pctB(pctB <= pctMaxInclude);
                end
                pctB = pctB(~isnan(pctB));
                nBurst = numel(pctB);
                if nBurst > 0
                    medBurst = median(pctB, 'omitnan');
                else
                    medBurst = NaN;
                end
            end
        end
    end

    spikeDatasetMedians(pairIdx) = medSpike;
    burstDatasetMedians(pairIdx) = medBurst;
    spikePctByDataset{pairIdx} = pctS;
    burstPctByDataset{pairIdx} = pctB;

    if verboseDatasetMedians
        fprintf('Dataset %d: %s vs %s\n', pairIdx, baselineName, treatmentName);
        fprintf('  Spike: n after filters = %d, median %% change = %.4g\n', nSpike, medSpike);
        fprintf('  Burst: n after filters = %d, median %% change = %.4g\n', nBurst, medBurst);
    end
end

spikeBoot = hierarchicalBootstrapPct(spikePctByDataset, nBootstrap, bootstrapSeed);
burstBoot = hierarchicalBootstrapPct(burstPctByDataset, nBootstrap, bootstrapSeed);

fprintf('\n--- Publication-style summary (hierarchical bootstrap on channel %% change, paired to violin plots) ---\n');

printBootstrapLine('Spike rate', spikeBoot);
printBootstrapLine('Burst rate', burstBoot);

fprintf('------------------------------------------------------------------------\n');

end

%--------------------------------------------------------------------------
function printBootstrapLine(label, out)
if out.nDatasets == 0
    fprintf('%s: no valid datasets with channel observations after filters.\n', label);
    return;
end

pStr = formatP(out.pApprox);
fprintf(['%s: pooled median %% change = %.4g%%, 95%%%% hierarchical bootstrap CI = [%.4g, %.4g]%%, ', ...
    'approx p = %s, n = %d datasets, %d channels\n'], ...
    label, out.observed, out.ci(1), out.ci(2), pStr, out.nDatasets, out.nChannels);
end

%--------------------------------------------------------------------------
function s = formatP(p)
if p < 0.001
    s = '<0.001';
elseif p < 0.01
    s = sprintf('%.3f', p);
else
    s = sprintf('%.3g', p);
end
end

%--------------------------------------------------------------------------
function out = hierarchicalBootstrapPct(pctByDataset, nBoot, rngSeed)
valid = cellfun(@(x) ~isempty(x), pctByDataset);
pctByDataset = pctByDataset(valid);

if isempty(pctByDataset)
    out = struct('observed', NaN, 'ci', [NaN NaN], 'pApprox', NaN, ...
        'nDatasets', 0, 'nChannels', 0, 'bootStats', []);
    return;
end

for i = 1:numel(pctByDataset)
    pctByDataset{i} = pctByDataset{i}(:);
    pctByDataset{i} = pctByDataset{i}(~isnan(pctByDataset{i}));
end
pctByDataset = pctByDataset(~cellfun(@isempty, pctByDataset));

if isempty(pctByDataset)
    out = struct('observed', NaN, 'ci', [NaN NaN], 'pApprox', NaN, ...
        'nDatasets', 0, 'nChannels', 0, 'bootStats', []);
    return;
end

rng(rngSeed);

nD = numel(pctByDataset);
nChannels = sum(cellfun(@numel, pctByDataset));
obsAll = vertcat(pctByDataset{:});
observed = median(obsAll, 'omitnan');

bootStats = NaN(nBoot, 1);
for b = 1:nBoot
    dsIdx = randi(nD, [nD, 1]);
    pooled = [];
    for j = 1:nD
        x = pctByDataset{dsIdx(j)};
        chIdx = randi(numel(x), [numel(x), 1]);
        pooled = [pooled; x(chIdx)]; %#ok<AGROW>
    end
    bootStats(b) = median(pooled, 'omitnan');
end

ci = prctile(bootStats, [2.5 97.5]);
pApprox = 2 * min(mean(bootStats <= 0), mean(bootStats >= 0));
pApprox = min(pApprox, 1);

out = struct('observed', observed, 'ci', ci, 'pApprox', pApprox, ...
    'nDatasets', nD, 'nChannels', nChannels, 'bootStats', bootStats);
end

%--------------------------------------------------------------------------
function name = figures_cache_filename(datasetName)
safe = strrep(strrep(datasetName, '-', '_'), '#', '_');
name = sprintf('figures_cache_%s.mat', safe);
end
