%{
--------------------------------------------------------------------------
FUNCTION NAME: burst_stats

DESCRIPTION:
    Computes per-channel burst rate (bursts/min) and percent of spikes 
    that occurred within bursts, using ISI-threshold definition

INPUTS:
    - spikeData, recordLengthSecs (all come from process_data.m)
    - channelLabels
    - burstStatsPath to direct figure output

--------------------------------------------------------------------------
%}

function burst_stats(spikeData, recordLengthSecs, channelLabels, burstStatsPath)
isiMax = 0.100; 
isiEnd = 0.200; 
minSpikes = 3;

nCh = numel(spikeData);
burstRatePerMin   = nan(nCh,1);
pctSpikesInBursts = nan(nCh,1);

for k = 1:nCh
    if isfield(spikeData{k},'snips') && isfield(spikeData{k}.snips,'Snip')
        ts = sort(spikeData{k}.snips.Snip.ts(:));
    else
        ts = [];
    end

    if numel(ts) < minSpikes
        burstRatePerMin(k) = 0;
        pctSpikesInBursts(k) = 0;
        continue
    end

    ISI = diff(ts);
    inBurst = false; startIdx = NaN; burstStarts = []; burstEnds = [];

    for i = 1:numel(ISI)
        if ~inBurst && ISI(i) <= isiMax
            inBurst = true; startIdx = i;
        elseif inBurst && ISI(i) > isiEnd
            endIdx = i;
            if endIdx - startIdx + 1 >= minSpikes
                burstStarts(end+1) = startIdx; %#ok<AGROW>
                burstEnds(end+1)   = endIdx;   %#ok<AGROW>
            end
            inBurst = false;
        end
    end
    if inBurst
        endIdx = numel(ts);
        if endIdx - startIdx + 1 >= minSpikes
            burstStarts(end+1) = startIdx;
            burstEnds(end+1)   = endIdx;
        end
    end

    burstCount = numel(burstStarts);
    spikesInBursts = sum(burstEnds - burstStarts + 1);
    burstRatePerMin(k) = (burstCount / recordLengthSecs) * 60;
    pctSpikesInBursts(k) = 100 * spikesInBursts / numel(ts);
end

mBurstRate = mean(burstRatePerMin,'omitnan');
mPctInBursts = mean(pctSpikesInBursts,'omitnan');

figure('Visible','off','Position',[100 100 800 600],'Color','w');
subplot(2,1,1);
bar(channelLabels, burstRatePerMin);
xlabel('Channel'); ylabel('Bursts/min'); title('Burst Rate per Channel'); grid on;

subplot(2,1,2);
bar(channelLabels, pctSpikesInBursts);
xlabel('Channel'); ylabel('% Spikes in Bursts'); title('Percent of Spikes in Bursts'); grid on;

sgtitle(sprintf('Mean Rate = %.2f bursts/min | Mean %% in bursts = %.2f%%', mBurstRate, mPctInBursts));
saveas(gcf, burstStatsPath, 'png');
close(gcf);
end