args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==3)
if(nzchar(Sys.getenv('ADDICTION_R_LIB'))) .libPaths(c(Sys.getenv('ADDICTION_R_LIB'),.libPaths()))
if(dir.exists('R-library')) .libPaths(c(file.path(getwd(),'R-library'),.libPaths()))
suppressPackageStartupMessages({library(glmmTMB);library(mice);library(jsonlite)})
options(contrasts=c('contr.sum','contr.poly'));set.seed(20261009)
e<-new.env();load(args[1],envir=e);x<-e$sms.imp.alc
fits<-readRDS(file.path(args[2],'fitted-models.rds'));out<-args[3];dir.create(out,recursive=TRUE,showWarnings=FALSE)
pool<-function(fs,component,term,n_override=NULL,coping=NA_real_) {
 q<-u<-numeric(length(fs))
 for(j in seq_along(fs)) {
  b<-fixef(fs[[j]])[[component]];v<-vcov(fs[[j]])[[component]]
  stopifnot(identical(sub('^zi~','',rownames(v)),names(b)))
  L<-setNames(rep(0,length(b)),names(b));L[term]<-1
  if(!is.na(coping))L[paste0(term,':copingz')]<-coping
  q[j]<-sum(L*b)*ifelse(component=='zi',-1,1);u[j]<-as.numeric(t(L)%*%v%*%L)
 }
 n<-if(is.null(n_override))min(sapply(fs,df.residual))+1 else n_override
 p<-mice::pool.scalar(q,u,n=n,k=1);se<-sqrt(p$t);ci<-p$qbar+c(-1,1)*qt(.975,p$df)*se
 data.frame(component=component,term=term,coping_z=coping,estimate=p$qbar,se=se,df=p$df,lower=ci[1],upper=ci[2],ratio=exp(p$qbar),ratio_lower=exp(ci[1]),ratio_upper=exp(ci[2]),p=2*pt(-abs(p$qbar/se),p$df),m=length(fs))
}
# Independent reconstruction of one Rubin-pooled coefficient.
fs<-fits$mean__source_unadjusted;q<-sapply(fs,function(f)-fixef(f)$zi['affect']);u<-sapply(fs,function(f)vcov(f)$zi[2,2])
expected<-read.csv(file.path(args[2],'pooled-effects.csv'));expected<-subset(expected,operation=='mean'&specification=='source_unadjusted'&component=='zi')
manual_mean<-mean(q);manual_variance<-mean(u)+(1+1/length(q))*var(q)
stopifnot(abs(manual_mean-expected$estimate)<1e-12,abs(sqrt(manual_variance)-expected$se)<1e-12)
extra_fits<-list();diagnostics<-list();effects<-list();audits<-list()
for(op in c('mean','most')) {
 fs<-vector('list',x$m)
 for(i in seq_len(x$m)) {
  d<-mice::complete(x,i);b<-d[!duplicated(d$PID),]
  d$copingz<-(d$DMQ.coping-mean(b$DMQ.coping))/sd(b$DMQ.coping)
  d<-subset(d,operationalization==op)
  d<-d[complete.cases(d[,c('alc.quant','mood.negative','copingz','birthsex','mar.quantgram','mood.positive','weekday','season')]),]
  d$PID<-factor(d$PID);d$birthsex<-factor(d$birthsex);d$weekday<-factor(d$weekday);d$season<-factor(d$season)
  d$affect_mean<-ave(d$mood.negative,d$PID,FUN=mean);d$affect_within<-d$mood.negative-d$affect_mean
  pm<-d[!duplicated(d$PID),'affect_mean'];stopifnot(!anyDuplicated(paste(d$PID,d$study_day)))
  audits[[length(audits)+1]]<-data.frame(operation=op,imputation=i,n_days=nrow(d),n_people=nlevels(d$PID),eligible_person_mean_sd=sd(pm),eligible_person_mean_min=min(pm),eligible_person_mean_max=max(pm))
  f<-withCallingHandlers(glmmTMB(alc.quant~affect_within*copingz+affect_mean+birthsex+mar.quantgram+mood.positive+weekday+season+(1|PID),
   ziformula=~affect_within*copingz+affect_mean+birthsex+mar.quantgram+mood.positive+weekday+season+(1|PID),
   family=truncated_nbinom2(),data=d,control=glmmTMBControl(parallel=1,optCtrl=list(iter.max=1500,eval.max=2000))),warning=function(w){message(conditionMessage(w));invokeRestart('muffleWarning')})
  fs[[i]]<-f;diagnostics[[length(diagnostics)+1]]<-data.frame(operation=op,imputation=i,n_days=nrow(d),n_people=nlevels(d$PID),convergence=f$fit$convergence,positive_hessian=isTRUE(f$sdr$pdHess),max_gradient=max(abs(f$sdr$gradient.fixed)))
  cat(op,'within-between imputation',i,'convergence',f$fit$convergence,'Hessian',f$sdr$pdHess,'\n');flush.console()
  write.csv(do.call(rbind,diagnostics),file.path(out,'within-between-diagnostics.csv'),row.names=FALSE)
 }
 extra_fits[[op]]<-fs
 stopifnot(all(sapply(fs,function(f)f$fit$convergence==0&&isTRUE(f$sdr$pdHess))))
 for(comp in c('zi','cond')) {
  for(c in c(-1,0,1)){p<-pool(fs,comp,'affect_within',coping=c);p$operation<-op;effects[[length(effects)+1]]<-p}
  p<-pool(fs,comp,'affect_within:copingz');p$operation<-op;effects[[length(effects)+1]]<-p
 }
}
write.csv(do.call(rbind,effects),file.path(out,'within-between-effects.csv'),row.names=FALSE)
write.csv(do.call(rbind,audits),file.path(out,'centering-audit.csv'),row.names=FALSE)
saveRDS(extra_fits,file.path(out,'within-between-models.rds'))
cluster<-list()
for(op in c('mean','most')) {
 fs<-fits[[paste0(op,'__coping_adjusted')]];np<-min(sapply(fs,function(f)length(unique(f$frame$PID))))
 for(comp in c('zi','cond')){
  p<-pool(fs,comp,'affect:copingz',n_override=np);p$operation<-op;p$complete_data_df<-np-1;cluster[[length(cluster)+1]]<-p
 }
}
write.csv(do.call(rbind,cluster),file.path(out,'participant-df-sensitivity.csv'),row.names=FALSE)
write_json(list(additional_models=10,all_valid=TRUE,manual_Rubin_estimate_difference=manual_mean-expected$estimate,manual_Rubin_standard_error_difference=sqrt(manual_variance)-expected$se,post_hoc=TRUE),file.path(out,'revision-verification.json'),auto_unbox=TRUE,pretty=TRUE)
capture.output(sessionInfo(),file=file.path(out,'session-info.txt'))
cat('COMPLETE 10 additional models; within-between and df sensitivities\n')
