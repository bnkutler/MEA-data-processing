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
function spectrogram_plot(BLOCKPATH, spectroPath)

STORE = 'Wav1';
notch_base = 60;
max_harmonic = 780;

rawData = TDTbin2mat(BLOCKPATH, 'STORE', STORE, 'CHANNEL', 1);
comb_data = rawData;
for f0 = notch_base:notch_base:max_harmonic
    comb_data = TDTdigitalfilter(comb_data, 'Wav1', 'NOTCH', f0, 'ORDER', 4);
end
filteredData = TDTdigitalfilter(comb_data, STORE, [300 2500], 'ORDER', 8);

x = double(filteredData.streams.(STORE).data(1,:));
fs = filteredData.streams.(STORE).fs;

% First minute only
x = x(1 : round(60*fs));

figure('Visible','off','Position',[100 100 1000 400]);
spectrogram(x, 256, [], [], fs, 'yaxis');
ylim([0 4]); 

set(gcf,'color','w');
saveas(gcf, spectroPath, 'png');
close(gcf);
end
