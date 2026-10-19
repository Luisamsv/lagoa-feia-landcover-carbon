# Lagoa Feia: land-cover change and modeled carbon stocks

Data and analysis code for **Shifting Landscapes, Compensating Carbon Gains and Losses: Four Decades of Land-Cover Change in a Brazilian Coastal Basin**.

Authors: Luísa Maria de Souza Viana; Eloá Corrêa Lessa Tostes; Keltony de Aquino Ferreira; Layra de Oliveira Silva; Marcos Sarmet Moreira de Barros Salomão; Carlos Eduardo Veiga de Carvalho.

Contact: luisaviana@pq.uenf.br

## Files and folders

| Location | Content |
|---|---|
| `RUN_ALL.R` | Main entry point; keep this file at the repository root. |
| `scripts/modules/` | Six distinct analysis modules; each has a separate purpose. |
| `data/reference/` | Fifteen populated input/reference CSVs. |
| `metadata/` | Variable dictionary, original-name mapping, code provenance, numerical checks and missing-input notes. |
| `Rasters.zip`, `watershed.zip` | Spatial inputs already deposited separately; keep them at the root. |

There are no duplicate historical scripts or archive folders in this publication package. File names and user instructions are in English. Original CSV column names and parameter provenance text are retained to avoid changing the supplied records; English descriptions are provided in `metadata/variable_dictionary.csv`. `metadata/file_name_mapping.csv` connects the English file names to the original source names. Source-script names in provenance records are identifiers, not additional executable copies.

## Run the numerical workflow

Download and extract the repository, preserving its folders. In R:

```r
source("RUN_ALL.R", encoding = "UTF-8")
```

Alternatively:

```sh
Rscript RUN_ALL.R /path/to/lagoa-feia-landcover-carbon
```

The default workflow uses base R and the deposited processed inputs. It recalculates historical carbon stocks, original-code and aggregated transition balances, native-cover gains/losses, interval climate summaries, climate–carbon correlations, carbon rolling variance, OLS land-cover/carbon trend scenarios and descriptive parameter sensitivity. It creates a new timestamped folder under `results/` and never overwrites the reference data.

Default historical calculations start from deposited original-code **area and transition tables**. Independent reconstruction of those areas from TIFFs is optional, as described below. Compare generated checks with the supplied records and read `SCOPE.txt` in the output folder.

## Modules

| Module | Purpose |
|---|---|
| `01_rebuild_maps.R` | Rebuild masked land-cover, carbon and transition products from the original TIFFs. Optional; requires terra. |
| `02_statistics.R` | Interval climate summaries, correlations and exploratory carbon rolling variance. |
| `03_AR1.R` | Original stationary AR(1) hydroclimate simulations. Optional. |
| `04_projections.R` | Three OLS fitting periods and carbon scenarios with within-category composition fixed in 2024. |
| `05_sensitivity.R` | Documented joint parameter alternatives and isolated stress tests. |
| `06_wetland_GEE_optional.R` | Annual natural-wetland transition analysis using Earth Engine. Optional; requires authorized remote access. |

Run modules through `RUN_ALL.R`, rather than sourcing each one independently.

## Optional spatial reconstruction

```r
install.packages("terra") # once, if needed
Sys.setenv(LF_REBUILD_MAPS = "true")
source("RUN_ALL.R", encoding = "UTF-8")
```

Keep `Rasters.zip` and `watershed.zip` at the repository root, or place their extracted contents under `data/spatial/`. Archives are extracted without overwriting existing files. The nine original TIFF names are intentionally preserved as `proj_uso_clipado_YEAR_corrigido.tif` for 1985, 1990, 1995, 2000, 2005, 2010, 2015, 2020 and 2024. All nine must share one directory. Include `watershed.shp`, `.shx`, `.dbf` and `.prj`.

The recovered spatial method applies the watershed mask by cell center (`touches=FALSE`), converts code 0 to NoData, preserves the original grid and calculates area using `terra::cellSize`. Expected classified area is approximately 335,809.5476 ha across 4,183,460 cells. Spatial totals are checked against deposited reference tables; agreement is not independent validation of classification quality.

Four compartment rasters can be exported by also setting `LF_EXPORT_FOUR_POOLS=true`. They require additional runtime and disk space.

## Optional hydroclimatic AR(1) simulation

```r
Sys.setenv(LF_RUN_AR1 = "true")
source("RUN_ALL.R", encoding = "UTF-8")
```

The original procedure uses 1,999 surrogates and seed 180240. In default mode, the deposited AR(1) result is preserved rather than recalculated. When simulations are requested, compare their output with `data/reference/hydroclimate_ar1_reference.csv`; results may depend on R and package versions. The new run records `sessionInfo.txt`.

## Optional Earth Engine analysis

Install the required R packages (`terra`, `sf`, `jsonlite`, `reticulate`) and the Python Earth Engine API, and configure an authorized Earth Engine session/project. Then:

```r
Sys.setenv(LF_RUN_GEE = "true", EARTHENGINE_PROJECT = "your-authorized-project")
source("RUN_ALL.R", encoding = "UTF-8")
```

This module uses MapBiomas Collection 10.1 annual maps. The nine historical local TIFFs do not substitute for the complete annual series. The selected recovered version retains the raster support boundary, sample checks and explicitly documented count tolerance. Its annual output tables were not supplied with the input package.

## Scientific interpretation

Carbon estimates use fixed reference densities, including published estimates, functional proxies, explicit derivations and exclusions. They describe modeled stock differences, not measured sequestration. Aquatic biomass and open-water sediment carbon are outside the reference inventory. Aggregated Vegetation includes forest plantation; Wetland includes aquaculture. Category gains do not establish native-habitat recovery.

Climate context is separate from the carbon accounting. No causal climate–carbon effect is estimated. Future class-area scenarios are exploratory OLS extrapolations; their spread is sensitivity to fitting periods, not a confidence interval or a spatial prediction.

## Validation and remaining inputs

Independent numerical checks reproduced historical stock and transition balances, interval climate means, the reported Pearson association and carbon rolling-variance Kendall statistics. OLS projection areas agreed within 0.000051 ha. See `metadata/numerical_audit.json`.

R/terra and the spatial archives were unavailable in the preparation environment, so the integrated R workflow, raster stage, Monte Carlo simulations and authenticated Earth Engine analysis were not executed there. This package is not yet an end-to-end validated reproduction of every analysis and figure.

Actual CMIP6 data/source access information and the ONI series used in the study still need to be added. Final manuscript figure rendering is separate and not invoked here. Figure 1 is prepared in QGIS. Read `metadata/MISSING_INPUTS.md` before archiving a final release.

## Citation and reuse

Add the DOI and citation of the final archived release when available. Third-party data retain their original conditions. Specify licenses for author-owned code/data before the final release; this packaging step does not assign new licenses.
