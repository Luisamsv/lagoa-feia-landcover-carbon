# Lagoa Feia | Historical areas, fixed-density carbon and transitions.
# BASE IMPLEMENTATION: not a replacement for all original analysis scripts.
# From the repository root: source('scripts/00_base_historical.R')
# Or: Rscript scripts/00_base_historical.R /path/to/repository
# Install separately if necessary: install.packages('terra')

main <- function(root = getwd()) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  if (!requireNamespace('terra', quietly = TRUE)) stop("Install 'terra' first.")
  cfg <- list(years = c(1985,1990,1995,2000,2005,2010,2015,2020,2024),
              expected_area = 335809.5476, area_tolerance = 0.1,
              expected_cells = 4183460, carbon_tolerance = 0.001)
  output <- file.path(root, 'results', 'base_historical')
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  log <- file.path(output, 'execution.log')
  writeLines(paste('Started:', Sys.time()), log)
  note <- function(...) {
    msg <- paste(..., collapse = ' '); message(msg)
    cat(msg, '\n', file = log, append = TRUE)
  }
  save_csv <- function(x, name) write.csv(x, file.path(output, name),
                                          row.names = FALSE, na = '', fileEncoding = 'UTF-8')
  input_dir <- file.path(root, 'data', 'spatial')
  dir.create(input_dir, recursive = TRUE, showWarnings = FALSE)
  # Extract only known archives; reject unsafe paths and preserve existing files.
  for (archive in c('Rasters.zip', 'watershed.zip')) {
    z <- file.path(root, archive)
    if (!file.exists(z)) next
    entries <- utils::unzip(z, list = TRUE)$Name
    safe <- gsub('\\\\', '/', entries)
    if (any(grepl('(^/|^[A-Za-z]:|(^|/)\\.\\.(/|$))', safe)))
      stop('Unsafe archive entry in ', archive)
    utils::unzip(z, exdir = input_dir, overwrite = FALSE)
  }
  # Search only the intended input area; outputs cannot be mistaken for inputs.
  all_inputs <- list.files(input_dir, recursive = TRUE, full.names = TRUE)
  locate <- function(name) {
    p <- all_inputs[basename(all_inputs) == name]
    if (length(p) != 1L) stop('Expected exactly one ', name, '; found ', length(p),
                              '. Check data/spatial and archive contents.')
    p
  }
  paths <- vapply(cfg$years, function(y) locate(paste0('proj_uso_clipado_', y,
                                                     '_corrigido.tif')), character(1))
  basin_path <- locate('watershed.shp')
  stem <- tools::file_path_sans_ext(basin_path)
  if (!all(file.exists(paste0(stem, c('.shp','.shx','.dbf','.prj')))))
    stop('Incomplete watershed shapefile: .shp/.shx/.dbf/.prj required.')
  inventory <- c(paths, paste0(stem, c('.shp','.shx','.dbf','.prj')))
  save_csv(data.frame(file = substring(inventory, nchar(root)+2),
                      md5 = unname(tools::md5sum(inventory))), 'input_checksums.csv')
  # Parameters are deliberately NOT reconstructed from rounded manuscript values.
  pf <- file.path(root, 'data', 'parameters', 'carbon_parameters.csv')
  if (!file.exists(pf)) stop('Missing data/parameters/carbon_parameters.csv. ',
       'Supply the original full-precision parameter table; see supplied example.')
  p <- read.csv(pf, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c('code','mapbiomas_class','study_class','aboveground_MgC_ha',
                'belowground_MgC_ha','soil_MgC_ha','dead_MgC_ha','total_MgC_ha')
  if (!all(required %in% names(p))) stop('Missing parameter columns: ',
                                     paste(setdiff(required,names(p)),collapse=', '))
  numeric_cols <- c('code', required[4:8])
  if (!all(vapply(p[numeric_cols], is.numeric, logical(1))) ||
      any(!is.finite(as.matrix(p[numeric_cols])))) stop('Invalid numeric parameters.')
  if (anyDuplicated(p$code) || any(p$code != floor(p$code)) ||
      any(p$code <= 0 | p$code >= 1000) || any(as.matrix(p[required[4:8]]) < 0))
    stop('Invalid, negative or duplicated parameter values/codes.')
  classes <- c('Vegetation','Wetland','Pasture','Agriculture','Water',
               'Urban','Beach','Non-vegetated')
  if (anyNA(p$study_class) || any(!p$study_class %in% classes)) stop('Invalid study_class.')
  # Tiny differences can reflect publication rounding; larger ones require review.
  if (any(abs(rowSums(p[required[4:7]])-p$total_MgC_ha) > 0.001))
    stop('Pool sum differs from total by more than 0.001 Mg C/ha.')
  if (!33 %in% p$code || p$total_MgC_ha[match(33,p$code)] != 0)
    stop('Reference inventory requires code 33 = zero represented carbon.')
  save_csv(p, 'parameters_used.csv')
  rs <- lapply(paths, terra::rast)
  ref <- rs[[1]]
  basin <- terra::vect(basin_path)
  if (!nzchar(terra::crs(ref)) || !nzchar(terra::crs(basin))) stop('Missing CRS.')
  # Already clipped rasters define the analysis footprint; do not mask again.
  # The polygon is retained as provenance and is not silently used to change cells.
  if (terra::is.lonlat(ref)) stop('Expected the final projected analysis rasters.')
  area <- terra::cellSize(ref, unit = 'ha', mask = TRUE)
  area_total <- as.numeric(terra::global(area, 'sum', na.rm = TRUE)[1,1])
  if (abs(area_total-cfg$expected_area) > cfg$area_tolerance)
    stop('Footprint area differs from manuscript: ', area_total, ' ha.')
  summaries <- vector('list', length(rs))
  for (i in seq_along(rs)) {
    r <- rs[[i]]
    if (terra::nlyr(r) != 1L) stop('Expected one band for ', cfg$years[i])
    terra::compareGeom(ref, r, lyrs = TRUE, crs = TRUE, ext = TRUE,
                       rowcol = TRUE, res = TRUE, stopOnError = TRUE)
    different <- terra::global(is.na(ref) != is.na(r), 'sum', na.rm = TRUE)[1,1]
    if (!is.finite(different) || different != 0) stop('Different NA footprint: ',cfg$years[i])
    f <- terra::freq(r, digits = NA)
    if (any(f$value != floor(f$value)) || any(!f$value %in% p$code))
      stop('Unknown/non-integer MapBiomas codes in ',cfg$years[i],': ',
           paste(setdiff(f$value,p$code),collapse=', '))
    if (sum(f$count) != cfg$expected_cells) stop('Unexpected valid-cell count.')
    a <- as.data.frame(terra::zonal(area, r, fun = 'sum', na.rm = TRUE))
    names(a) <- c('code','area_ha')
    a <- merge(p, a, by = 'code', all.x = TRUE, sort = TRUE)
    a$area_ha[is.na(a$area_ha)] <- 0
    a$year <- cfg$years[i]
    a$carbon_Tg <- a$area_ha*a$total_MgC_ha/1e6
    summaries[[i]] <- a
    note('Computed year', cfg$years[i])
  }
  original <- do.call(rbind,summaries)
  save_csv(original,'area_carbon_original_codes.csv')
  by_class <- aggregate(cbind(area_ha,carbon_Tg)~year+study_class, original,sum)
  save_csv(by_class,'area_carbon_study_classes.csv')
  totals <- aggregate(cbind(area_ha,carbon_Tg)~year,original,sum)
  save_csv(totals,'basin_totals.csv')
  # Adjacent intervals plus the direct 1985 -> 2024 endpoint comparison.
  pairs <- rbind(cbind(seq_len(length(rs)-1L),2:length(rs)),c(1L,length(rs)))
  balances <- list()
  for (k in seq_len(nrow(pairs))) {
    i <- pairs[k,1]; j <- pairs[k,2]
    code_pair <- rs[[i]]*1000+rs[[j]]
    a <- as.data.frame(terra::zonal(area,code_pair,fun='sum',na.rm=TRUE))
    names(a) <- c('pair','area_ha')
    a$origin_code <- a$pair %/% 1000; a$destination_code <- a$pair %% 1000
    oi <- match(a$origin_code,p$code); di <- match(a$destination_code,p$code)
    if (anyNA(oi) || anyNA(di)) stop('Transition code absent from parameter table.')
    a$origin_class <- p$study_class[oi];a$destination_class <- p$study_class[di]
    a$delta_density_MgC_ha <- p$total_MgC_ha[di]-p$total_MgC_ha[oi]
    a$delta_carbon_Tg <- a$area_ha*a$delta_density_MgC_ha/1e6
    a$from <- cfg$years[i];a$to <- cfg$years[j]
    suffix <- paste(a$from[1],a$to[1],sep='_')
    save_csv(a,paste0('transitions_original_',suffix,'.csv'))
    ag <- aggregate(cbind(area_ha,delta_carbon_Tg)~origin_class+destination_class,a,sum)
    save_csv(ag,paste0('transitions_study_classes_',suffix,'.csv'))
    inter <- a$origin_class != a$destination_class
    net <- sum(a$delta_carbon_Tg)
    expected <- totals$carbon_Tg[match(cfg$years[j],totals$year)]-
                totals$carbon_Tg[match(cfg$years[i],totals$year)]
    if (abs(net-expected)>1e-6 || abs(sum(a$area_ha)-area_total)>0.001)
      stop('Transition closure failed: ',suffix)
    balances[[k]] <- data.frame(from=cfg$years[i],to=cfg$years[j],
      gain_interclass_Tg=sum(a$delta_carbon_Tg[inter & a$delta_carbon_Tg>0]),
      loss_interclass_Tg=sum(a$delta_carbon_Tg[inter & a$delta_carbon_Tg<0]),
      within_class_Tg=sum(a$delta_carbon_Tg[!inter]),net_Tg=net,
      changed_study_class_pct=100*sum(a$area_ha[inter])/area_total,
      closure_error_Tg=net-expected)
    note('Computed transitions',suffix)
  }
  save_csv(do.call(rbind,balances),'transition_balances.csv')
  reference <- c(52.32852723,52.1019801,52.1644566,53.5389167,54.9253222,
                 54.7658923,55.3550470,55.9847116,55.69598820)
  audit <- data.frame(year=cfg$years,reference_Tg=reference,
     recalculated_Tg=totals$carbon_Tg[match(cfg$years,totals$year)])
  audit$difference_Tg <- audit$recalculated_Tg-audit$reference_Tg
  audit$within_tolerance <- abs(audit$difference_Tg)<=cfg$carbon_tolerance
  save_csv(audit,'manuscript_reference_check.csv')
  capture.output(sessionInfo(),file=file.path(output,'sessionInfo.txt'))
  if (!all(audit$within_tolerance)) stop('Results differ from the manuscript. ',
      'Inspect manuscript_reference_check.csv; do not use as a validated release.')
  note('Historical base completed. Climate, sensitivity, trend scenarios and figures ',
       'require the original final modules; they were NOT reproduced by this script.')
  invisible(list(totals=totals,reference_check=audit))
}
args <- if (sys.nframe()==0L) commandArgs(trailingOnly=TRUE) else character()
main(if(length(args)) args[[1]] else getwd())
