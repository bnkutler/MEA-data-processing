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
function display_signal(rawPath, filteredPath, snippetPath, BLOCKPATH, ch)
STORE = 'Wav1'; 
chanIdx = ch;

dataRaw = TDTbin2mat(BLOCKPATH, 'STORE', STORE, 'CHANNEL', chanIdx); 

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

% Filtered signal (match process_data: notch 60:780 then 300–2500 bandpass)
fs = dataRaw.streams.(STORE).fs;
x = double(dataRaw.streams.(STORE).data(:));
max_harmonic = 780; notch_base = 60; Q = 35;
for f0 = notch_base:notch_base:max_harmonic
    if f0 < fs/2
        [B,A] = designNotchPeakIIR( ...
            Response="notch", ...
            CenterFrequency=f0/(fs/2), ...
            QualityFactor=Q);
        x = filtfilt(B, A, x);
    end
end
BP_FILTER = [300 2500];
[bb,aa] = butter(4, BP_FILTER/(fs/2), 'bandpass');
x = filtfilt(bb,aa,x);
dataFiltered = dataRaw;
dataFiltered.streams.(STORE).data = x.';

% Option for manual thresholding
%THRESH = -25e-6; NPTS = 30; OVERLAP = 0;
%dataFiltered = TDTthresh(dataFiltered, STORE, 'MODE', 'manual', 'THRESH', THRESH, 'NPTS', NPTS, 'OVERLAP', OVERLAP, 'REJECT', 200e-6);

dataFiltered = TDTthresh(dataFiltered, STORE, 'MODE', 'auto', 'POLARITY', -1, 'STD', 6.5, 'TAU', 3);

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

%Snippets
figure('Visible','off','Position',[100 100 800 600]); hold on;
for ii = 1:size(dataFiltered.snips.Snip.data,1)
    plot(dataFiltered.snips.Snip.data(ii,:)*1e6, 'color', colors(ii,:));
end
axis tight
xlabel('samples'); ylabel('\muV');
title(sprintf('Extracted snippets ch%d (N=%d)', chanIdx, size(dataFiltered.snips.Snip.data,1)));
saveas(gcf, snippetPath, 'png'); close(gcf);
end
