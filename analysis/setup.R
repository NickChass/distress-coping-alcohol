required<-c('glmmTMB','mice','ggplot2','jsonlite')
recorded<-c(glmmTMB='1.1.15.2',mice='3.19.0',ggplot2='4.0.3',jsonlite='2.0.0')
if(nzchar(Sys.getenv('ADDICTION_R_LIB'))) .libPaths(c(Sys.getenv('ADDICTION_R_LIB'),.libPaths()))
missing<-required[!vapply(required,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)){
  lib<-Sys.getenv('R_LIBS_USER');if(!nzchar(lib))lib<-file.path(getwd(),'R-library')
  dir.create(lib,recursive=TRUE,showWarnings=FALSE);.libPaths(c(lib,.libPaths()))
  install.packages(missing,repos='https://cloud.r-project.org',lib=lib)
  if(!nzchar(Sys.getenv('R_LIBS_USER')))cat('For subsequent commands set ADDICTION_R_LIB to:',normalizePath(lib),'\n')
}
for(p in required){stopifnot(requireNamespace(p,quietly=TRUE));v<-as.character(packageVersion(p));cat(p,v,ifelse(v==recorded[p],'(recorded version)','(differs from recorded run)'), '\n')}
cat('Recorded R version: 4.6.0; current:',as.character(getRversion()),'\n')
