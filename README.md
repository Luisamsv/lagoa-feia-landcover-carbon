# Lagoa Feia: land-cover change and modeled carbon stocks

Data and R scripts associated with the manuscript:

**Shifting Landscapes, Compensating Carbon Gains and Losses:
Four Decades of Land-Cover Change in a Brazilian Coastal Basin**

## Authors

Luísa Maria de Souza Viana; Eloá Corrêa Lessa Tostes;
Keltony de Aquino Ferreira; Layra de Oliveira Silva;
Marcos Sarmet Moreira de Barros Salomão;
Carlos Eduardo Veiga de Carvalho.

Corresponding author: luisaviana@pq.uenf.br

## Repository status

This repository is being prepared for manuscript submission.
Data, analysis scripts, and reproduction instructions are being
organized. A complete archived release has not yet been published.

## Study overview

The study examines land-cover change and modeled carbon-stock
redistribution in the Lagoa Feia basin, southeastern Brazil,
during 1985–2024.

The analysis combines MapBiomas land-cover maps, carbon-density
parameters assigned to the original land-cover classes, and
pixel-level transition accounting.

Historical hydroclimatic records and single-model climate
projections provide separate environmental contexts.
Exploratory land-cover trend scenarios estimate future
carbon-storage potential.

## Main results

- 32.30% of the analyzed landscape changed study class
  between 1985 and 2024.
- Modeled carbon storage increased from 52.33 to 55.70 Tg C
  (+6.44%).
- Net gains coexisted with losses along specific vegetation
  and wetland transition pathways.
- Exploratory scenarios yielded 58.76–61.24 Tg C by 2070,
  depending on the period used to fit land-cover trends.

## Data sources

- MapBiomas Collection 10: historical land-cover maps.
- MapBiomas Collection 10.1: annual natural-wetland
  transition analysis.
- ANA HidroWeb: Usina Quissamã precipitation records.
- TerraClimate: potential evapotranspiration.
- NOAA Climate Prediction Center: Oceanic Niño Index.
- WorldClim CMIP6, MRI-ESM2-0: precipitation projections.
- Published studies: carbon-density estimates, functional
  proxies, and explicit parameter derivations.

Exact source identifiers, access information, processing
steps, and redistribution conditions will be documented
with the deposited files.

## Planned organization

- data/: input data and processed datasets.
- scripts/: final R scripts used in the study.
- results/: numerical results supporting the manuscript
  and supplementary material.
- figures/: final figures.
- metadata/: variable definitions, units, class
  correspondence, and data provenance.

## Interpretation

Carbon estimates use fixed reference densities and represent
modeled stock differences associated with mapped land cover.
They do not quantify realized sequestration or causal
climate effects.

Aggregated Vegetation and Wetland classes include managed
land-cover types; their expansion does not necessarily
represent native-habitat recovery.

Future scenarios are exploratory class-area extrapolations,
not spatial predictions of future land cover. Their spread
represents sensitivity to fitting periods, not confidence
intervals.

## Reproducibility

The final release will document the R and package versions,
required inputs, script execution order, and expected outputs.

## Citation and reuse

The citation and DOI of the archived release will be added
when available.

Third-party data remain subject to their original licenses.
Reuse conditions for original data products and code will
be specified before the final release.
