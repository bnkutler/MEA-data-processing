%{
--------------------------------------------------------------------------
FUNCTION NAME: main

DESCRIPTION: 
    Main driver script for MEA data processing pipeline.
    Loads TDT data, processes it, then generates raw/filtered signal,
    average spike rate plot, raster plot, burst statistics, and 
    spectrogram


INPUTS:
    None (Requires defined pathways and datsets)

OUTPUTS:
    Figures directed to OUTPUTPATH
-------------------------------------------------------------------------
%}
function main()

% Define paths and datasets
SDKPATH = '/Users/bkutler4/Desktop/hai_lab/TDTMatlabSDK';
addpath(genpath(SDKPATH));
BASEPATH = '/Users/bkutler4/Desktop/hai_lab/data';
OUTPUTPATH = '/Users/bkutler4/Desktop/hai_lab/pipeline/pipeline_outputs2';

%Control 1
%datasets = {'IdoControl-230914-130200_#1','IdoControl-230914-131548_#2','IdoControl-230914-132855_#3','IdoControl-230914-154022_#4','IdoControl-230914-155318_#5','IdoControl-230914-160601_#6'};
%DOI
%datasets = {'IdoDOI-230914-142502_#1','IdoDOI-230914-143740_#2','IdoDOI-230914-144945_#3','IdoDOI-230914-161838_#4','IdoDOI-230914-163140_#5','IdoDOI-230914-164512_#6'};
%Control 2
%datasets = {'IdoControl-231101-144046_#1','IdoControl-231101-145330_#2','IdoControl-231101-150512_#3'};
%Ketanserin
%datasets = {'IdoKetanserin-231101-133725_#1','IdoKetanserin-231101-134946_#2','IdoKetanserin-231101-140237_#3'};
% All datasets
%datasets = {'IdoControl-230914-132855_#3','IdoControl-230914-154022_#4','IdoControl-230914-155318_#5','IdoControl-230914-160601_#6',...
    %'IdoDOI-230914-144945_#3','IdoDOI-230914-161838_#4','IdoDOI-230914-163140_#5','IdoDOI-230914-164512_#6',...
    %'IdoControl-231101-144046_#1','IdoControl-231101-145330_#2','IdoControl-231101-150512_#3',...
    %'IdoKetanserin-231101-133725_#1','IdoKetanserin-231101-134946_#2','IdoKetanserin-231101-140237_#3'}

datasets =  {'IdoDOI-230914-144945_#3'};
% Waitbar
datasets_prog = waitbar(0, 'Processing datasets...');

for i = 1:length(datasets)
    ENDPATH = datasets{i};
    BLOCKPATH = fullfile(BASEPATH, ENDPATH);

    % process_data
    [spikeData, datasetSpikes, datasetActiveChannels, recordLengthSecs] = process_data(BLOCKPATH);

    % display_signal
    rawPath = fullfile(OUTPUTPATH, sprintf('raw_signal%s.png',ENDPATH));
    filteredPath = fullfile(OUTPUTPATH, sprintf('filtered_signal%s.png',ENDPATH));
    display_signal(rawPath, filteredPath, BLOCKPATH)

    % spike_rate_average_plot
    %spikeRatePath = fullfile(OUTPUTPATH, sprintf('spike_rate_%s.png',ENDPATH));
    %spike_rate_average_plot(spikeData, recordLengthSecs, spikeRatePath);

    % raster_plot
    rasterPath = fullfile(OUTPUTPATH, sprintf('raster_plot_%s.png',ENDPATH));
    raster_plot(spikeData, datasetSpikes, datasetActiveChannels, recordLengthSecs, rasterPath, ENDPATH);

    % burst_stats
    %burstStatsPath = fullfile(OUTPUTPATH, sprintf('burst_stats_%s.png',ENDPATH));
    %channelLabels = 1:numel(spikeData);
    %burst_stats(spikeData, recordLengthSecs, channelLabels, burstStatsPath);

    % spectrogram_plot
    spectroPath = fullfile(OUTPUTPATH, sprintf('spectrogram_%s.png',ENDPATH));
    spectrogram_plot(BLOCKPATH, spectroPath);
    
    % Update waitbar
    waitbar(i / length(datasets), datasets_prog, sprintf('Processing Dataset %d of %d', i, length(datasets)));

end
close(datasets_prog)