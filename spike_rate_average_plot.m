%{
--------------------------------------------------------------------------
FUNCTION NAME: spike_rate_average_plot

DESCRIPTION: 
    Calculates average spike rate, that is the average of the spikes/minute
    for all minute long intervals in the recording, for each channel.

INPUTS:
    - spikeData, recordLengthSecs (both come from process_data.m)
    - spikeRatePath to determine where output plot is saved

OUTPUTS:
    - Spike rate average plot, saved to ENDPATH
-------------------------------------------------------------------------
%}
function spike_rate_average_plot(spikeData, recordLengthSecs, spikeRatePath)

    % Initialize parameters
    %CHANNELS = 1:64;
    CHANNELS = 1:3;
    totalTime = recordLengthSecs;
    binSize = 60;
    numBins = ceil(totalTime / binSize);

    averageSpikesPerChannel = zeros(length(CHANNELS), 1);

    % Iterate through each channel
    for i = 1:length(CHANNELS)
        spikeTimes = spikeData{i}.snips.Snip.ts;
        spikeRates = zeros(1, numBins);

        % For each bin of 60 seconds, count spikes
        for j = 1:numBins
            startTime = (j - 1) * binSize;
            endTime = min(j * binSize, totalTime);
            binDuration = endTime - startTime;
        
            spikeRates(j) = sum(spikeTimes >= startTime & spikeTimes < endTime);

            if binDuration < 60
                spikeRates(j) = spikeRates(j) * (60 / binDuration);
            end
        end

        % Average spike rates from each bin
        averageSpikesPerChannel(i) = mean(spikeRates);
    end

    % Plot figure
    figure('Visible', 'off');
    bar(1:length(CHANNELS), averageSpikesPerChannel, 'FaceColor', [0, 0.447, 0.741]);
    xlabel('Channel');
    ylabel('Average Spike Rate (spikes per minute)');
    title('Average Spike Rate per Channel');
    grid on;
    ylim([0 1000]);

    % Save figure
    saveas(gcf, spikeRatePath, 'png');
    close(gcf);

end