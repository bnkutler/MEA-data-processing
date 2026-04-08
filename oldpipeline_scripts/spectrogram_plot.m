%{
--------------------------------------------------------------------------
FUNCTION NAME: spectrogam_plot

DESCRIPTION: 
    Generates a spectrogram from 0 to 4kHz
    
INPUTS:
    - BLOCKPATH and spectroPath to determine where plot is saved

OUTPUTS:
    - Spectrogram plot

-------------------------------------------------------------------------
%}
function spectrogram_plot(BLOCKPATH, spectroPath, ch)

STORE = 'Wav1';
chanIdx = ch;

rawData = TDTbin2mat(BLOCKPATH, 'STORE', STORE, 'CHANNEL', chanIdx);
fs = rawData.streams.(STORE).fs;
x = double(rawData.streams.(STORE).data(:));

% match process_data: notch 60:780 then 300–2500 bandpass (zero-phase)
notch_base = 60; max_harmonic = 780; Q = 35; BP_FILTER = [300 2500];
for f0 = notch_base:notch_base:max_harmonic
    if f0 < fs/2
        [b,a] = iirnotch(f0/(fs/2), (f0/(fs/2))/Q);
        x = filtfilt(b,a,x);
    end
end
[bb,aa] = butter(4, BP_FILTER/(fs/2), 'bandpass');
x = filtfilt(bb,aa,x);

% first minute
x = x(1:round(60*fs)); 

figure('Visible','off','Position',[100 100 1000 400]);
spectrogram(x, 256, [], [], fs, 'yaxis');
ylim([0 2.5]);
title(sprintf('60 sec Spectrogram of ch%d', chanIdx));

set(gcf,'color','w');
saveas(gcf, spectroPath, 'png');
close(gcf);
end