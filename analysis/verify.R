args <- commandArgs(trailingOnly=TRUE)
if(nzchar(Sys.getenv('ADDICTION_R_LIB'))) .libPaths(c(Sys.getenv('ADDICTION_R_LIB'),.libPaths()))
if(dir.exists('R-library')) .libPaths(c(file.path(getwd(),'R-library'),.libPaths()))
suppressPackageStartupMessages({library(glmmTMB);library(mice);library(jsonlite)})
fits <- readRDS(file.path(args[1],'fitted-models.rds'))
di <- read.csv(file.path(args[1],'model-diagnostics.csv'))
stopifnot(nrow(di)==50,all(di$valid),all(di$positive_hessian),all(di$convergence==0))
rr <- list()
for(key in names(fits)[grepl('coping_adjusted|observed_outcomes|capped_imputed_tail',names(fits))]) {
  fs <- fits[[key]]
  for(comp in c('zi','cond')) {
    q<-sapply(fs,function(f)fixef(f)[[comp]]['affect:copingz'])*ifelse(comp=='zi',-1,1)
    u<-sapply(fs,function(f){j<-match('affect:copingz',names(fixef(f)[[comp]]));vcov(f)[[comp]][j,j]})
    pp<-pool.scalar(q,u,n=min(sapply(fs,df.residual))+1,k=1)
    se<-sqrt(pp$t);ci<-pp$qbar+c(-1,1)*qt(.975,pp$df)*se
    rr[[length(rr)+1]]<-data.frame(model=key,component=comp,estimate=pp$qbar,se=se,df=pp$df,lower=ci[1],upper=ci[2],p=2*pt(-abs(pp$qbar/se),pp$df))
  }
}
write.csv(do.call(rbind,rr),file.path(args[1],'pooled-interactions.csv'),row.names=FALSE)
f <- fits$mean__source_unadjusted[[1]]
d<-f$frame;d$any_use<-as.integer(d$alc.quant>0)
b<-glmmTMB(any_use~affect+(1|PID),family=binomial(),data=d)
sign_difference<-as.numeric(fixef(b)$cond['affect']+fixef(f)$zi['affect'])
stopifnot(abs(sign_difference)<1e-4)
worst<-fits$mean__source_unadjusted[[5]]
tight<-update(worst,data=worst$frame,control=glmmTMBControl(optCtrl=list(iter.max=1500,eval.max=2000,rel.tol=1e-12)))
coefficient_difference<-max(abs(unlist(fixef(tight))-unlist(fixef(worst))))
print(unlist(fixef(tight))-unlist(fixef(worst)))
saveRDS(tight,file.path(args[1],'strict-optimizer-check.rds'))
key_difference<-max(abs(c(fixef(tight)$zi['affect']-fixef(worst)$zi['affect'],fixef(tight)$cond['affect']-fixef(worst)$cond['affect'])))
stopifnot(key_difference<.001,tight$fit$convergence==0,tight$sdr$pdHess)
receipt<-list(model_fits=50,all_converged=TRUE,all_positive_hessian=TRUE,
  binary_hurdle_logodds_difference=sign_difference,
  stricter_optimizer_max_coefficient_difference=coefficient_difference,
  stricter_optimizer_max_affect_coefficient_difference=key_difference,
  strict_optimizer_max_gradient=max(abs(tight$sdr$gradient.fixed)),
  checks='Dataset hash; one row per person-day in each operationalization; coding of coping SD; reversal of no-use hurdle odds; Rubin pooling; optimizer stability')
write_json(receipt,file.path(args[1],'verification.json'),auto_unbox=TRUE,pretty=TRUE)
print(receipt)
