# mea-data-processing

MATLAB pipeline for **multi-electrode array (MEA)** electrophysiology analyzed with **Tucker-Davis Technologies (TDT)** data. Most figure scripts read **preprocessed cache** files (spike rates, counts, burst rates per channel). Raw recordings and large caches are typically kept out of git; use a `.gitignore` for `data/` and `pipeline/figures/cache/*.mat` if you mirror that layout.

## Prerequisites and workflow

1. Install the **TDT Matlab SDK** and ensure MATLAB can call `TDTbin2mat`, `TDTthresh`, etc.
2. Edit **`SDKPATH`**, **`BASEPATH`**, and figure **output paths** in each script to match your clone (many scripts still use a local `hai_lab` path by default).
3. Run **`figures_preprocess_and_save.m`** once (or after changing filters) to build one `.mat` cache per dataset under `pipeline/figures/cache/`.
4. Edit **`baselineList`**, **`treatmentList`**, and **`CHANNELS`** in the figure script you need, then run it in MATLAB.

Full behavior, filters, and outputs are documented in each script’s leading `%{ ... %}` block.

## Figure scripts (`pipeline/`)

| Script | What it does | Data source |
|--------|----------------|-------------|
| `figures_preprocess_and_save.m` | Builds per-dataset cache: TDT load, notch/bandpass, `TDTthresh`, spike counts/rates and burst rates → `pipeline/figures/cache/*.mat`. | Live TDT (reads dataset folders on disk) |
| `figures_stats.m` | Console summary: spike and burst **percent change** with the same channel filters as the two `% change` violin scripts; **hierarchical bootstrap** on pooled median vs 0. | Cache |
| `figures_spike_pct_change_violin.m` | Violin + boxplot of **channel-wise spike rate % change** (pooled baseline–treatment pairs); optional silencing trim and `pctMaxInclude`. | Cache |
| `figures_burst_pct_change_violin.m` | Violin + boxplot of **channel-wise burst rate % change**; burst silence rules, spike-based exclusions, baseline burst > 0 for % change. | Cache |
| `figures_spike_rate.m` | Paired-line + boxplot of **spike rate (spikes/min)**; optional silent-channel threshold and mean-multiplier outlier filter. | Cache |
| `figures_burst_rate.m` | Paired-line + boxplot of **burst rate (bursts/min)**; optional burst silence threshold; optional mean-multiplier outlier filter. | Cache |
| `figures_total_spikes.m` | Paired-line + boxplot of **total spike count** per channel (same detection pipeline as spike rate). | Cache |
| `figures_spike_rate_change_bar.m` | Per-recording **% of channels** silenced / decreased / increased among baseline-active spike channels; chi-square vs 50/50 on increase vs decrease (non-silenced). | Cache |
| `figures_burst_rate_change_bar.m` | Same category breakdown for **burst rate** among baseline-active burst channels; optional burst silence filter. | Cache |
| `figures_spike_percent_change.m` | Scatter of **% change in spike count** (e.g. DOI vs Ketanserin); excludes channels with zero baseline or zero treatment counts. | Cache |
| `figures_spike_rate_pct_change_histogram.m` | **Histogram** of spike rate % change (baseline vs treatment); excludes baseline rate 0; optional % range cutoff for bins. | Cache |
| `figures_compare_filtered_signals.m` | Side-by-side **filtered voltage traces** for selected channels (control vs treatment); publication-style layout. | Live TDT |
| `figures_process_data.m` | **Two-dataset** filtering and comparison figure (similar role to compare_filtered); processes from disk without writing a long-term figure cache. | Live TDT |

