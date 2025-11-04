%{
--------------------------------------------------------------------------
FUNCTION NAME: process_data

DESCRIPTION: 
    Transforms TDT data to be readable by MatLab using TDTbin2mat,
    then adds band-pass filter and notch filter and stores data.

INPUTS:
    BLOCKPATH - path to specific dataset

OUTPUTS:
    spikeData - Processed data for all channels from dataset
    datasetSpikes - Number of spikes
    datasetActiveChannels - Number of active channels
    recorddLengthSecs - Length of recording in seconds
-------------------------------------------------------------------------
%}

function [spikeData, datasetSpikes, datasetActiveChannels, recordLengthSecs, spikes, rawData] = process_data(BLOCKPATH)

    % Initialize
    STORE = 'Wav1';
    CHANNELS = 1:64;
    %CHANNELS = 1:3;
    datasetSpikes = 0; 
    datasetActiveChannels = 0; 
    recordLengthSecs = 0;
    BP_FILTER = [300 2500];
    max_harmonic = 780;
    notch_base = 60;
    Q = 35;

    spikeData = cell(length(CHANNELS), 1);
    spikeTimes = cell(length(CHANNELS), 1);
    spikeCountsPerChannel = zeros(length(CHANNELS), 1);
    
    % Waitbar that displays progress on channels processed
    channels_prog = waitbar(0, 'Processing channels...');
    
    % Convert and filter
    for i = 1:length(CHANNELS)
        ch = CHANNELS(i);
        rawData = TDTbin2mat(BLOCKPATH, 'STORE', STORE, 'CHANNEL', ch);
        fs = rawData.streams.(STORE).fs;
        x = double(rawData.streams.(STORE).data(:));

        % notch 60 Hz harmonics (zero-phase)
        for f0 = notch_base:notch_base:max_harmonic
            if f0 < fs/2
                [B,A] = designNotchPeakIIR( ...
                    Response="notch", ...
                    CenterFrequency=f0/(fs/2), ...
                    QualityFactor=Q);
                x = filtfilt(B, A, x);
            end
        end

        % bandpass 300–2500 Hz (zero-phase)
        [bp_b,bp_a] = butter(4, BP_FILTER/(fs/2), 'bandpass');
        x = filtfilt(bp_b,bp_a,x);

        dataFiltered = rawData;
        dataFiltered.streams.(STORE).data = x.';

        spikes = TDTthresh(dataFiltered, STORE, 'MODE', 'auto', 'POLARITY', -1, 'STD', 6.5, 'TAU', 5);
        spikeData{ch} = spikes;

        % For recording length, ensure it's calculated once per dataset
        if ch == CHANNELS(1)
            nSamples = length(rawData.streams.(STORE).data);
            recordLengthSecs = nSamples / fs;
        end

        % Update spike counts and active channel counts
        if ~isempty(spikeData{ch})
            spikeCount = length(spikeData{ch}.snips.Snip.ts);
            datasetSpikes = datasetSpikes + spikeCount;
            spikeCountsPerChannel(ch) = spikeCount;
            datasetActiveChannels = datasetActiveChannels + 1;
        end

        % Update waitbar
        waitbar(i / length(CHANNELS), channels_prog, sprintf('Processing Channel %d of %d', ch, length(CHANNELS)));
    end
    
    close(channels_prog);

end
