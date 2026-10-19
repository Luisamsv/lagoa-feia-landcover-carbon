# Lagoa Feia: land-cover change and modeled carbon stocks

Supporting data and recovered analysis code for **Shifting Landscapes, Compensating Carbon Gains and Losses: Four Decades of Land-Cover Change in a Brazilian Coastal Basin**.

Authors: Luísa Maria de Souza Viana; Eloá Corrêa Lessa Tostes; Keltony de Aquino Ferreira; Layra de Oliveira Silva; Marcos Sarmet Moreira de Barros Salomão; Carlos Eduardo Veiga de Carvalho.

Contact: luisaviana@pq.uenf.br

## Contents

- `RUN_ALL.R`: entry point for the integrated numerical workflow.
- `scripts/modules/`: selected modules connected to the actual supplied CSV schemas.
- `data/reference/`: 48 supplied reference files, preserved as received. Historical absolute paths inside archived inventories/logs document the original machine; they are not runtime dependencies.
- `archive/original_scripts/`: all 59 supplied R scripts, unchanged. This is a provenance archive containing historical versions and duplicates, not an execution sequence.
- `metadata/`: provenance, numerical audit and outstanding inputs.
- `Rasters.zip` and `watershed.zip`: spatial inputs already supplied separately in the GitHub repository; not duplicated in this package.

## Run the integrated numerical analyses

Download the repository and extract it. Keep the folders in this package at the repository root. In R, run:

```r
source("RUN_ALL.R", encoding = "UTF-8")
```

Alternatively:

```sh
Rscript RUN_ALL.R /path/to/lagoa-feia-landcover-carbon
```

The default mode uses base R and deposited processed inputs. It recalculates:

1. Carbon stocks from original-code areas and the original full-precision parameter table.
2. Carbon changes from original-code transition areas, aggregated transitions and native-cover loss/gain.
3. Mapping-interval climate means, climate–carbon correlations and exploratory carbon rolling variance.
4. Class-area OLS extrapolations for the 1985–2024, 2000–2024 and 2010–2024 fitting periods; carbon scenarios use effective densities and within-category composition fixed in 2024.
5. The recovered 2,187-combination descriptive parameter sensitivity grid and isolated stress tests.

Each run creates a new timestamped folder under `results/`. Deposited reference inputs are never overwritten. Inspect the generated reference checks and `SCOPE.txt`.

This default mode reproduces numerical calculations from deposited area/transition tables; it does not independently rebuild those spatial areas from the TIFFs. Reference checks establish agreement with the supplied records, not independent validation of land-cover classification or carbon parameters.

## Rebuild the raster-based calculations

Install `terra` separately, then enable the spatial stage:

```r
install.packages("terra") # once, if needed
Sys.setenv(LF_REBUILD_MAPS = "true")
source("RUN_ALL.R", encoding = "UTF-8")
```

Place `Rasters.zip` and `watershed.zip` at the root, or their already extracted files under `data/spatial/`. Archives are extracted without replacing existing files. The nine TIFFs must share one directory and retain the original names `proj_uso_clipado_YEAR_corrigido.tif` for 1985, 1990, 1995, 2000, 2005, 2010, 2015, 2020 and 2024. Include `watershed.shp`, `.shx`, `.dbf` and `.prj`.

The recovered original module applies the watershed mask using cell centers (`touches=FALSE`), treats code 0 as NoData, preserves the grid, and uses `terra::cellSize` for area. Expected valid-cell count: 4,183,460; expected classified area: approximately 335,809.5476 ha. Areas by code are compared with the deposited area table; that reference table is not an independent new spatial audit.

Four separate compartment rasters are optional because they increase runtime and disk usage:

```r
Sys.setenv(LF_EXPORT_FOUR_POOLS = "true")
```

Use `RUN_ALL.R` instead of the earlier provisional `00_base_historical.R`. The recovered original mask and zero-code handling supersede assumptions in that provisional script.

## Optional original hydroclimatic AR(1) simulations

The default mode preserves the deposited audited hydroclimatic AR(1) result and labels it as preserved. To recalculate the original simulations (1,999 surrogates; seed 180240):

```r
Sys.setenv(LF_RUN_AR1 = "true")
source("RUN_ALL.R", encoding = "UTF-8")
```

R/package versions may affect simulation results. Compare the generated output with `data/reference/EWS_hidroclima_AR1_ORIGINAL_PRESERVADO.csv`. The original session information is preserved in `data/reference/sessionInfo.txt`; the new run writes its own session information.

## Optional annual natural-wetland analysis

The recovered `06_wetland_GEE_optional.R` accesses MapBiomas Collection 10.1 in Google Earth Engine. It requires the spatial inputs, R packages `terra`, `sf`, `jsonlite`, `reticulate`, the Python Earth Engine API, and an authorized Earth Engine project/session. It is never started implicitly:

```r
Sys.setenv(LF_RUN_GEE = "true", EARTHENGINE_PROJECT = "your-authorized-project")
source("RUN_ALL.R", encoding = "UTF-8")
```

Its annual transition outputs were not included in the supplied Data.zip. This module and its remote dependencies have not been executed during repository preparation.

## Inputs still outstanding

The supplied material does not contain a populated CMIP6 results/source-input manifest or a populated ONI series. The four CSV templates previously uploaded (`carbon_parameters.csv`, `clima_mensal.csv`, `cmip6.csv`, `oni.csv`) contained headers only and are not used here. The original carbon parameter table has now been recovered in `data/reference/tabela_referencia_documentada_v1.csv`.

To cover the remaining parts of the manuscript, add the actual CMIP6 dataset and source-raster access information, the ONI series used, and the underlying climate processing inputs or exact public retrieval instructions. Archived scripts contain historical paths to these files; they are not substitutes for the inputs. See `metadata/OUTSTANDING_INPUTS.md`.

Final manuscript figure rendering is separate. Original plotting scripts are archived but not blindly invoked: some are earlier layouts with old figure numbering and Windows paths. Figure 1 is prepared in QGIS. Figures 3–5 remain colored and should use Times New Roman regular. Abandoned exploratory spatial future-map tests are not part of this integrated workflow.

## Scientific scope

Carbon values describe a fixed-density inventory, not measured sequestration. Sources include published estimates, functional proxies, explicit derivations and scope exclusions. Open-water carbon and sediments are excluded. Category expansion does not imply native-habitat recovery: Vegetation includes forest plantation and Wetland includes aquaculture. Climate context is separate from carbon accounting; causal climate–carbon effects are not estimated. Future scenario spreads are fitting-period sensitivity envelopes, not confidence intervals or spatial predictions.

## Validation status

Independent Python cross-checks of the supplied CSVs reproduced historical stocks, transition endpoint balances, interval climate means, the reported AI–carbon Pearson association and carbon rolling-variance Kendall statistics. OLS forecast areas matched deposited forecasts within 0.000051 ha. Exact values and limits are in `metadata/NUMERICAL_AUDIT.json`.

The integrated R workflow has not been executed in the preparation environment, which lacks R/terra and the spatial archives. Raster reconstruction, AR(1) Monte Carlo and the authenticated GEE stage remain to be run and checked on a suitable machine. The package must not be described as an end-to-end validated reproduction of every figure and analysis.

## Citation and reuse

Add the final archived version DOI and citation after publication of a release. No new license is imposed on third-party datasets or the supplied scripts by this packaging step. Reuse conditions must be specified by the rights holders before the final archived release.
