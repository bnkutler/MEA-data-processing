%{
--------------------------------------------------------------------------
FUNCTION NAME: display_signal

DESCRIPTION: 
    Generates a raw signal and filtered signal with threshold.
    

INPUTS:
    - rawData, dataFiltered
    (both come from process_data.m)
    - rawPath and filteredPath to determine where output plots are saved


OUTPUTS:
    - Raw signal plot and filtered signal plot

-------------------------------------------------------------------------
%}
function display_signal(rawPath, filteredPath, BLOCKPATH)
STORE = 'Wav1'; 
chanIdx = 1;

dataRaw = TDTbin2mat(BLOCKPATH, 'STORE', STORE, 'CHANNEL', 1); 

% Raw signal
sig_raw = dataRaw.streams.(STORE).data;
fs_raw = dataRaw.streams.(STORE).fs;
ts_raw = (0:numel(sig_raw)-1)/fs_raw;
sig_raw_uV = sig_raw * 1e6;

figure('Visible','off','Position',[100 100 1000 400]); hold on;
plot(ts_raw, sig_raw_uV, 'color', [.7 .7 .7]);
xlabel('Time (s)'); ylabel('\muV');
xlim([0 650]);
title(sprintf('Raw Signal of ch%d', chanIdx));
saveas(gcf, rawPath, 'png'); close(gcf);

% Filtered signal
comb_data = dataRaw;
for f0 = [60 300]
    comb_data = TDTdigitalfilter(comb_data, STORE, 'NOTCH', f0, 'ORDER', 4);
end
BP_FILTER = [300 2500];
dataFiltered = TDTdigitalfilter(comb_data, STORE, BP_FILTER, 'ORDER', 8);

% Option for manual thresholding
%THRESH = -25e-6; NPTS = 30; OVERLAP = 0;
%dataFiltered = TDTthresh(dataFiltered, STORE, 'MODE', 'manual', 'THRESH', THRESH, 'NPTS', NPTS, 'OVERLAP', OVERLAP, 'REJECT', 200e-6);

dataFiltered = TDTthresh(dataFiltered, STORE, 'MODE', 'auto', 'POLARITY', -1, 'STD', 6.5, 'TAU', 5);

maxvals = max(dataFiltered.snips.Snip.data, [], 2)*1e6;
minvals = min(dataFiltered.snips.Snip.data, [], 2)*1e6;

ts = (1:numel(dataFiltered.streams.(STORE).data(1,:)))/dataFiltered.streams.(STORE).fs;

figure('Visible','off','Position',[100 100 1000 400]); hold on;
plot(ts, dataFiltered.streams.(STORE).data(1,:)*1e6, 'color', [.7 .7 .7]);
axis([ts(1) ts(end) min(minvals) max(maxvals)]); 

thresh = max(minvals);
plot([ts(1), ts(end)], [thresh, thresh], 'r--', 'LineWidth', 2)
xlabel('Time (s)'); ylabel('\muV');
colors = vals2colormap(minvals, 'spring', [min(minvals)*.9 max(minvals)]);
scatter(dataFiltered.snips.Snip.ts, minvals, 10, colors, 'filled');

title(sprintf('Filtered Signal of ch%d', chanIdx));
subtitle('with threshold');
legend({'stream', 'threshold', 'spike'});

saveas(gcf, filteredPath, 'png'); close(gcf);
end
