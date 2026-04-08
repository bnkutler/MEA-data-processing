%{
--------------------------------------------------------------------------
FUNCTION NAME: raster_plot

DESCRIPTION: 
    Generates a raster plot of spike activity in each channel for
    entire recording.   

INPUTS:
    - spikeData, datasetSpikes, datasetActiveChannels, recordLengthSecs
    (all come from process_data.m)
    - rasterPath and ENDPATH to determine where output plot is saved

OUTPUTS:
    - Raster plot, saved to ENDPATH

-------------------------------------------------------------------------
%}
function raster_plot(spikeData, datasetSpikes, datasetActiveChannels, recordLengthSecs, rasterPath, ENDPATH)
    
    CHANNELS = 1:64;
    %CHANNELS = 1:3;

    figure('Visible', 'off'); 
    hold on;
    for ch = CHANNELS
        spikeTimes = spikeData{ch}.snips.Snip.ts;
        for spike = 1:length(spikeTimes)
            plot([spikeTimes(spike), spikeTimes(spike)], [ch-0.4, ch+0.4], 'k');
        end
    end
    
    firingFrequency = datasetSpikes / recordLengthSecs;
    xlabel('Time (s)'); ylabel('Channel'); ...
        title(sprintf('%s\nActive Channels = %d, Total Spikes = %d, Firing Frequency = %.2f spikes/s', ...
        ENDPATH, datasetActiveChannels, datasetSpikes, firingFrequency)); axis tight;
    
    % Save the figure
    saveas(gcf, rasterPath, 'png');
    close(gcf);
end

    