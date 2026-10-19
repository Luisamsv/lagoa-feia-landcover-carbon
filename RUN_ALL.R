# Lagoa Feia | entry point for the recovered final workflow.
# source('RUN_ALL.R') from repository root, or Rscript RUN_ALL.R /path/to/repository
# Defaults: recalculate numerical tables from deposited inputs.
# Optional raster reconstruction: Sys.setenv(LF_REBUILD_MAPS='true')
# Optional original AR(1) simulations: Sys.setenv(LF_RUN_AR1='true')
# Optional authenticated GEE wetland stage: Sys.setenv(LF_RUN_GEE='true')
run_repository <- function(root) {
  root <- normalizePath(root,winslash='/',mustWork=TRUE)
  ref <- file.path(root,'data','reference')
  output <- file.path(root,'results',paste0('run_',format(Sys.time(),'%Y%m%d_%H%M%S')))
  if(dir.exists(output)) stop('Output directory already exists. Retry with a new timestamp.')
  dir.create(output,recursive=TRUE)
  precisa <- function(f)if(!file.exists(f))stop('Missing input: ',f)
  ler <- function(f) {precisa(f);read.csv(f,check.names=FALSE,stringsAsFactors=FALSE,fileEncoding='UTF-8-BOM')}
  campos <- function(x,n)if(!all(n %in% names(x)))stop('Missing columns: ',paste(setdiff(n,names(x)),collapse=', '))
  salvar <- function(x,n,cfg)write.csv(x,file.path(cfg$saida,n),row.names=FALSE,na='',fileEncoding='UTF-8')
  yes <- function(x)identical(tolower(Sys.getenv(x,unset='false')),'true')
  cfg <- list(root=root,referencia=ref,saida=output,pasta=output,
    clima=file.path(ref,'clima_utilizado_carbono.csv'),pet='',auditoria=file.path(output,'audit_inputs'),
    anos=c(1985,1990,1995,2000,2005,2010,2015,2020,2024),area_esperada=335809.5476,
    celulas_esperadas=4183460,tolerancia_area_ha=.1,tolerancia_carbono_Tg=1e-5,
    criar_quatro_pools=yes('LF_EXPORT_FOUR_POOLS'),retomar=FALSE)
  log <- file(file.path(output,'execution.log'),open='wt',encoding='UTF-8')
  sink(log,split=TRUE);on.exit({sink();close(log)},add=TRUE)
  cat('Root:',root,'\nOutput:',output,'\n')
  # Never overwrite deposited references. Record every supplied reference checksum.
  inputs <- list.files(ref,full.names=TRUE)
  if(!length(inputs)) stop('Extract package folders at repository root; data/reference is absent/empty.')
  salvar(data.frame(file=basename(inputs),md5=unname(tools::md5sum(inputs))), 'reference_checksums.csv',cfg)
  p <- ler(file.path(ref,'tabela_referencia_documentada_v1.csv'))
  pc <- ler(file.path(ref,'carbono_por_codigo_REFERENCIA_v1.csv'))
  serie <- ler(file.path(ref,'serie_historica_carbono_REFERENCIA_v1.csv'))
  h <- ler(cfg$clima)
  pools <- c('C_above','C_below','C_soil','C_dead')
  campos(p,c('lucode','classe_real','classe_estudo',pools,'C_total'))
  campos(pc,c('ano','lucode','area_ha','carbono_total_Tg'))
  campos(serie,c('ano','carbono_total_Tg'))
  campos(h,c('ano_hid','P_mm','PET_mm','AI','completo'))
  if(anyDuplicated(p$lucode)||anyDuplicated(pc[c('ano','lucode')])||anyDuplicated(serie$ano))stop('Duplicate keys.')
  if(!is.numeric(as.matrix(p[c(pools,'C_total')])) ||
     any(!is.finite(as.matrix(p[c(pools,'C_total')]))) ||
     any(as.matrix(p[c(pools,'C_total')])<0) || any(abs(rowSums(p[pools])-p$C_total)>1e-7))stop('Invalid pools.')
  if(!setequal(serie$ano,cfg$anos)||!setequal(pc$ano,cfg$anos))stop('Unexpected years.')
  serie <- serie[order(serie$ano),]
  h <- h[order(h$ano_hid),]
  if(anyDuplicated(h$ano_hid)||!identical(as.integer(h$ano_hid),1985:2024)||
     !is.logical(h$completo)||anyNA(h$completo)||sum(h$completo)!=37L||
     !identical(as.integer(h$ano_hid[!h$completo]),c(2012L,2014L,2023L))||
     any(!is.finite(h$PET_mm))||any(h$PET_mm<=0)||
     any(!is.finite(h$P_mm[h$completo]))||any(!is.finite(h$AI[h$completo]))||
     any(abs(h$AI[h$completo]-h$P_mm[h$completo]/h$PET_mm[h$completo])>1e-6)||
     abs(mean(h$P_mm[h$completo])-898.0919)>.01)stop('Climate audit failed.')
  a <- pc[c('ano','lucode','area_ha')]
  if(any(!is.finite(a$area_ha))||any(a$area_ha<0)||any(!a$lucode %in% p$lucode))stop('Invalid areas/codes.')
  pc$C_total <- p$C_total[match(pc$lucode,p$lucode)]
  pc$classe_estudo <- p$classe_estudo[match(pc$lucode,p$lucode)]
  pc$carbono_total_Tg <- pc$area_ha*pc$C_total/1e6
  totals <- aggregate(cbind(area_ha,carbono_total_Tg)~ano,pc,sum)
  checks <- merge(totals,serie[c('ano','carbono_total_Tg')],by='ano',suffixes=c('_recalculated','_reference'))
  checks$error_Tg <- checks$carbono_total_Tg_recalculated-checks$carbono_total_Tg_reference
  salvar(checks,'historical_reference_check.csv',cfg)
  if(any(abs(checks$error_Tg)>1e-5)||any(abs(checks$area_ha-cfg$area_esperada)>.1))stop('Historical closure failed.')
  salvar(pc,'carbono_por_codigo_RECALCULADO.csv',cfg)
  classes_data <- aggregate(cbind(area_ha,carbono_total_Tg)~ano+classe_estudo,pc,sum)
  salvar(classes_data,'carbono_por_classe_RECALCULADO.csv',cfg)
  # Recalculate transition carbon from deposited original-code transition AREAS.
  # Rebuilding those areas from TIFFs is a separate explicitly selected stage below.
  pairs <- rbind(data.frame(inicio=head(cfg$anos,-1),fim=tail(cfg$anos,-1)),data.frame(inicio=1985,fim=2024))
  bal <- list();native <- c(3,11,12,49,50)
  for(k in seq_len(nrow(pairs))) {
    y0 <- pairs$inicio[k];y1 <- pairs$fim[k]
    t <- ler(file.path(ref,paste0('transicoes_codigos_carbono_',y0,'_',y1,'.csv')))
    campos(t,c('codigo_inicial','codigo_final','area_ha'))
    if(anyDuplicated(t[c('codigo_inicial','codigo_final')])||any(!is.finite(t$area_ha))||any(t$area_ha<0))stop('Invalid transition areas.')
    i <- match(t$codigo_inicial,p$lucode);j <- match(t$codigo_final,p$lucode)
    if(anyNA(i)||anyNA(j))stop('Unknown transition code.')
    t$grupo_inicial <- p$classe_estudo[i];t$grupo_final <- p$classe_estudo[j]
    t$delta_carbono_Tg <- t$area_ha*(p$C_total[j]-p$C_total[i])/1e6
    c0 <- sum(t$area_ha*p$C_total[i])/1e6;c1 <- sum(t$area_ha*p$C_total[j])/1e6
    expected <- serie$carbono_total_Tg[match(c(y0,y1),serie$ano)]
    if(any(abs(c(c0,c1)-expected)>1e-5)||abs(sum(t$area_ha)-cfg$area_esperada)>.1)stop('Transition closure failed.')
    ag <- aggregate(cbind(area_ha,delta_carbono_Tg)~grupo_inicial+grupo_final,t,sum)
    salvar(t,paste0('transicoes_codigos_',y0,'_',y1,'_RECALCULADAS.csv'),cfg)
    salvar(ag,paste0('transicoes_classes_',y0,'_',y1,'_RECALCULADAS.csv'),cfg)
    changed <- t$grupo_inicial!=t$grupo_final
    bal[[k]] <- data.frame(ano_inicial=y0,ano_final=y1,periodo=paste(y0,y1,sep='-'),
      perda_nativa_ha=sum(t$area_ha[t$codigo_inicial %in% native & !t$codigo_final %in% native]),
      ganho_nativo_ha=sum(t$area_ha[!t$codigo_inicial %in% native & t$codigo_final %in% native]),
      estoque_inicial_Tg=c0,estoque_final_Tg=c1,delta_Tg=c1-c0,delta_pct=100*(c1-c0)/c0,
      ganhos_brutos_Tg=sum(t$delta_carbono_Tg[t$delta_carbono_Tg>0]),
      perdas_brutas_Tg=sum(t$delta_carbono_Tg[t$delta_carbono_Tg<0]),
      area_mudou_classe_pct=100*sum(t$area_ha[changed])/sum(t$area_ha))
  }
  balance <- do.call(rbind,bal);salvar(balance,'balanco_RECALCULADO.csv',cfg)
  modules <- file.path(root,'scripts','modules')
  # Recovered numerical modules share helpers only inside this workflow's scope.
  for(m in c('01_maps_original.R','02_statistics.R','04_projections.R','05_sensitivity.R'))
    source(file.path(modules,m),local=TRUE,encoding='UTF-8')
  arref <- file.path(ref,'EWS_hidroclima_AR1_ORIGINAL_PRESERVADO.csv')
  precisa(arref)
  if(!file.copy(arref,file.path(output,'EWS_teste_nulo_AR1_AUDITADO.csv')))stop('Failed to stage AR1 reference.')
  if(yes('LF_RUN_AR1')) source(file.path(modules,'03_AR1.R'),local=TRUE,encoding='UTF-8')
  est <- etapa_estatisticas(cfg,serie,balance)
  if(length(est$pendencias))stop(paste(est$pendencias,collapse='\n'))
  run_projections(cfg,classes_data,serie)
  run_sensitivity(cfg,p,a)
  # Optional: reconstruct original spatial processing, preserving original mask semantics.
  if(yes('LF_REBUILD_MAPS') || yes('LF_RUN_GEE')) {
    if(!requireNamespace('terra',quietly=TRUE))stop("Install 'terra' for spatial reconstruction.")
    spatial <- file.path(root,'data','spatial');dir.create(spatial,recursive=TRUE,showWarnings=FALSE)
    for(zipname in c('Rasters.zip','watershed.zip')) {
      z <- file.path(root,zipname)
      if(file.exists(z)) {
        n <- gsub('\\\\','/',utils::unzip(z,list=TRUE)$Name)
        if(any(grepl('(^/|^[A-Za-z]:|(^|/)\\.\\.(/|$))',n)))stop('Unsafe archive entries.')
        utils::unzip(z,exdir=spatial,overwrite=FALSE)
      }
    }
    locate <- function(name) {
      f <- list.files(spatial,recursive=TRUE,full.names=TRUE)
      f <- f[basename(f)==name]
      if(length(f)!=1L)stop('Expected exactly one ',name,' in data/spatial/.')
      f
    }
    paths <- vapply(cfg$anos,function(y)locate(paste0('proj_uso_clipado_',y,'_corrigido.tif')),character(1))
    if(length(unique(dirname(paths)))!=1L)stop('Place all nine TIFFs in one folder.')
    cfg$mapas <- dirname(paths[1]);cfg$bacia <- locate('watershed.shp')
    shp <- paste0(tools::file_path_sans_ext(cfg$bacia),c('.shp','.shx','.dbf','.prj'))
    if(!all(file.exists(shp)))stop('Shapefile components missing.')
    spatial_inputs <- c(paths,shp)
    salvar(data.frame(file=substring(spatial_inputs,nchar(root)+2),md5=unname(tools::md5sum(spatial_inputs))),
      'spatial_checksums.csv',cfg)
    dir.create(cfg$auditoria,showWarnings=FALSE)
    write.csv(a,file.path(cfg$auditoria,'areas_por_codigo_original.csv'),row.names=FALSE)
    if(yes('LF_REBUILD_MAPS'))etapa_mapas(cfg,p,serie)
    if(yes('LF_RUN_GEE'))source(file.path(modules,'06_wetland_GEE_optional.R'),local=TRUE,encoding='UTF-8')
  }
  capture.output(sessionInfo(),file=file.path(output,'sessionInfo.txt'))
  writeLines(c('Numerical historical tables, climate associations, carbon rolling variance,',
    'OLS trend scenarios and documented carbon sensitivity were recalculated.',
    paste('Rebuilt spatial inputs:',yes('LF_REBUILD_MAPS')),
    paste('Recomputed original AR1 simulations:',yes('LF_RUN_AR1')),
    paste('Requested authenticated annual wetland GEE stage:',yes('LF_RUN_GEE')),
    'CMIP6/ONI source datasets and full raw climate processing are not included.',
    'Final manuscript figure rendering is separate; archived original plotting scripts are not automatically executed.'),
    file.path(output,'SCOPE.txt'))
  cat('\nCompleted configured stages. Read results/.../SCOPE.txt.\n')
  invisible(output)
}
.script <- tryCatch(sys.frame(1)$ofile,error=function(e)NULL)
.args <- if(sys.nframe()==0L)commandArgs(trailingOnly=TRUE) else character()
.root <- if(length(.args)) .args[1] else if(!is.null(.script)) dirname(normalizePath(.script,mustWork=TRUE)) else getwd()
run_repository(.root)
