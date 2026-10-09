# Focused secondary-data reanalysis of Dora et al. (2026), OSF fm6cq.
# Original investigators collected, imputed, temporally filtered and standardized
# the data. This script extracts their imputations and fits a limited model set.
# Run: Rscript analyze.R path/to/sms.imp.processed.RData path/to/results
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
if (nzchar(Sys.getenv("ADDICTION_R_LIB"))) .libPaths(c(Sys.getenv("ADDICTION_R_LIB"), .libPaths()))
if(dir.exists('R-library')) .libPaths(c(file.path(getwd(),'R-library'),.libPaths()))
suppressPackageStartupMessages({library(glmmTMB); library(mice); library(ggplot2); library(jsonlite)})
options(contrasts = c("contr.sum", "contr.poly"))
set.seed(20261009)
out <- args[2]; dir.create(out, recursive = TRUE, showWarnings = FALSE)
e <- new.env(); load(args[1], envir = e)
stopifnot(setequal(ls(e), c("sms.imp.alc", "sms.imp.mar")))
x <- e$sms.imp.alc; stopifnot(x$m == 5L, nrow(x$data) == 79360L)
original <- x$data
original$observed_alcohol <- !is.na(original$alc.quant)
dats <- lapply(seq_len(x$m), function(i) {
  d <- mice::complete(x, i)
  d$observed_alcohol <- original$observed_alcohol
  d$PID <- factor(d$PID)
  d$birthsex <- factor(d$birthsex); d$weekday <- factor(d$weekday); d$season <- factor(d$season)
  b <- d[!duplicated(d$PID), ]
  d$copingz <- (d$DMQ.coping - mean(b$DMQ.coping)) / sd(b$DMQ.coping)
  stopifnot(max(abs(d$copingz - (d$DMQ.coping.low + 1))) < 1e-8)
  d
})
audit <- list(source = "https://osf.io/fm6cq/", imputations = x$m,
  participants = length(unique(original$PID)),
  scheduled_days_per_person = 32, scheduled_person_days = sum(original$operationalization == "mean"),
  observed_alcohol_days = sum(original$observed_alcohol & original$operationalization == "mean"),
  missing_original_alcohol_fraction = mean(!original$observed_alcohol[original$operationalization == "mean"]),
  note = "Original processed affect columns are NA in the .imp=0 frame. This is a derived-data representation, not evidence of 100% missing EMA affect. A raw complete-case comparison cannot be reconstructed from this download.",
  scope = "Four focused specifications for two affect summaries, five imputations each; two additional five-imputation sensitivities. Not the full published specification curve.")
jsonlite::write_json(audit, file.path(out, "data-audit.json"), auto_unbox = TRUE, pretty = TRUE)
all_fits <- list(); diagnostics <- list(); effects <- list()
specs <- expand.grid(operation = c("mean", "most"),
  specification = c("source_unadjusted", "source_adjusted", "coping_adjusted", "common_sample_unadjusted"), stringsAsFactors = FALSE)
specs <- rbind(specs, data.frame(operation = "mean", specification = c("observed_outcomes", "capped_imputed_tail")))
for (s in seq_len(nrow(specs))) {
  op <- specs$operation[s]; spec <- specs$specification[s]
  fs <- vector("list", x$m)
  for (i in seq_len(x$m)) {
    d <- subset(dats[[i]], operationalization == op)
    stopifnot(!anyDuplicated(paste(d$PID, d$study_day)))
    d$affect <- d$mood.negative
    adjusted <- !spec %in% c("source_unadjusted", "common_sample_unadjusted")
    moderation <- spec %in% c("coping_adjusted", "observed_outcomes", "capped_imputed_tail")
    common <- spec != "source_unadjusted"
    if (common) d <- d[complete.cases(d[, c("alc.quant", "affect", "copingz", "birthsex", "mar.quantgram", "mood.positive", "weekday", "season")]), ]
    else d <- d[complete.cases(d[, c("alc.quant", "affect")]), ]
    if (spec == "observed_outcomes") d <- d[d$observed_alcohol, ]
    if (spec == "capped_imputed_tail") d$alc.quant[!d$observed_alcohol] <- pmin(d$alc.quant[!d$observed_alcohol], 30)
    stopifnot(all(is.finite(d$affect)), all(d$alc.quant >= 0), all(abs(d$alc.quant - round(d$alc.quant)) < 1e-8))
    rhs <- if (moderation) "affect * copingz" else "affect"
    if (adjusted) rhs <- paste(rhs, "+ birthsex + mar.quantgram + mood.positive + weekday + season")
    form <- as.formula(paste("alc.quant ~", rhs, "+ (1 | PID)"))
    zi <- as.formula(paste("~", rhs, "+ (1 | PID)"))
    warnings <- character()
    fit <- withCallingHandlers(glmmTMB(form, ziformula = zi, data = d,
      family = truncated_nbinom2(), control = glmmTMBControl(parallel = 1, optCtrl = list(iter.max = 1000, eval.max = 1500))),
      warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") })
    valid <- fit$fit$convergence == 0 && isTRUE(fit$sdr$pdHess)
    diagnostics[[length(diagnostics)+1L]] <- data.frame(operation = op, specification = spec, imputation = i,
      n_days = nrow(d), n_people = length(unique(d$PID)), use_days = sum(d$alc.quant > 0),
      valid = valid, convergence = fit$fit$convergence, positive_hessian = isTRUE(fit$sdr$pdHess),
      max_gradient = max(abs(fit$sdr$gradient.fixed)), warnings = paste(warnings, collapse = "; "))
    fs[[i]] <- fit
    cat(op, spec, "imputation", i, "n", nrow(d), "valid", valid, "\n"); flush.console()
  }
  key <- paste(op, spec, sep = "__"); all_fits[[key]] <- fs
  if (!all(vapply(fs, function(f) f$fit$convergence == 0 && isTRUE(f$sdr$pdHess), logical(1)))) stop("Invalid model: inspect diagnostics before reporting")
  pool_effect <- function(component, coping = NA_real_) {
    q <- u <- numeric(x$m)
    for (j in seq_len(x$m)) {
      beta <- fixef(fs[[j]])[[component]]; V <- vcov(fs[[j]])[[component]]
      L <- setNames(rep(0, length(beta)), names(beta)); L["affect"] <- 1
      if (!is.na(coping)) L["affect:copingz"] <- coping
      # Zero hurdle models P(no drinking); reverse its sign for drinking odds.
      q[j] <- sum(L * beta) * ifelse(component == "zi", -1, 1)
      u[j] <- as.numeric(t(L) %*% V %*% L)
    }
    pp <- mice::pool.scalar(Q = q, U = u, n = min(vapply(fs, df.residual, numeric(1))) + 1, k = 1)
    se <- sqrt(pp$t); critical <- qt(.975, df = pp$df)
    data.frame(operation = op, specification = spec, component = component, coping_z = coping,
      estimate = pp$qbar, se = se, df = pp$df, lower = pp$qbar-critical*se, upper = pp$qbar+critical*se,
      ratio = exp(pp$qbar), ratio_lower = exp(pp$qbar-critical*se), ratio_upper = exp(pp$qbar+critical*se),
      p = 2*pt(-abs(pp$qbar/se), df = pp$df), m = x$m)
  }
  for (component in c("zi", "cond")) {
    effects[[length(effects)+1L]] <- pool_effect(component, if (spec %in% c("coping_adjusted", "observed_outcomes", "capped_imputed_tail")) 0 else NA_real_)
    if (spec %in% c("coping_adjusted", "observed_outcomes", "capped_imputed_tail")) for (c in c(-1, 1)) effects[[length(effects)+1L]] <- pool_effect(component, c)
  }
  # Save numerical checkpoints after each completed specification.
  write.csv(do.call(rbind, diagnostics), file.path(out,"model-diagnostics.csv"), row.names = FALSE)
  write.csv(do.call(rbind, effects), file.path(out,"pooled-effects.csv"), row.names = FALSE)
}
eff <- do.call(rbind, effects); diag <- do.call(rbind, diagnostics)
write.csv(diag, file.path(out, "model-diagnostics.csv"), row.names = FALSE)
write.csv(eff, file.path(out, "pooled-effects.csv"), row.names = FALSE)
saveRDS(all_fits, file.path(out, "fitted-models.rds"))
capture.output(sessionInfo(), file = file.path(out, "session-info.txt"))
jsonlite::write_json(list(audit = audit, diagnostics = diag, effects = eff), file.path(out, "results.json"), auto_unbox = TRUE, pretty = TRUE, na = "null")

labels <- c(source_unadjusted = "Original unadjusted specification", source_adjusted = "Original adjusted specification",
  coping_adjusted = "Adjusted with coping interaction", common_sample_unadjusted = "Unadjusted on adjusted sample")
a <- subset(eff, component == "zi" & specification %in% names(labels) & (is.na(coping_z) | coping_z == 0))
a$label <- factor(labels[a$specification], levels = rev(unname(labels)))
a$summary <- ifelse(a$operation == "mean", "Daily mean before drinking", "Last report before drinking")
theme_set(theme_minimal(base_size = 11) + theme(panel.grid.minor = element_blank(), legend.position = "bottom"))
p1 <- ggplot(a, aes(x = ratio, y = label, color = summary)) + geom_vline(xintercept = 1, linetype = 2, color = "grey50") +
  geom_errorbar(aes(xmin = ratio_lower, xmax = ratio_upper), orientation = "y", width = .16, position = position_dodge(width = .4)) +
  geom_point(position = position_dodge(width = .4), size = 2.5) + scale_x_log10() +
  labs(x = "Odds ratio for drinking per within-person SD of negative affect", y = NULL, color = NULL,
    title = "Higher negative affect does not consistently precede more drinking",
    subtitle = "Focused reanalysis with 95% pooled intervals; observational associations") +
  scale_color_manual(values = c("#176a63", "#435b86"))
ggsave(file.path(out, "figure-1-negative-affect.png"), p1, width = 9.0, height = 4.3, dpi = 240)
ggsave(file.path(out, "figure-1-negative-affect.pdf"), p1, width = 9.0, height = 4.3)
b <- subset(eff, component == "zi" & specification %in% c("coping_adjusted", "observed_outcomes", "capped_imputed_tail") & operation == "mean")
b$label <- factor(b$specification, levels = c("coping_adjusted", "observed_outcomes", "capped_imputed_tail"), labels = c("Author-provided imputations", "Observed alcohol outcomes only", "Imputed alcohol capped at 30"))
p2 <- ggplot(b, aes(x = coping_z, y = ratio, color = label)) + geom_hline(yintercept = 1, linetype = 2, color = "grey50") +
  geom_line(position = position_dodge(width = .08)) + geom_errorbar(aes(ymin = ratio_lower, ymax = ratio_upper), width = .08, position = position_dodge(width = .08)) +
  geom_point(size = 2.4, position = position_dodge(width = .08)) + scale_y_log10() + scale_x_continuous(breaks = c(-1,0,1), labels = c("Lower (-1 SD)","Mean", "Higher (+1 SD)")) +
  labs(x = "Baseline coping motives", y = "Odds ratio for drinking per within-person SD of negative affect", color = NULL,
    title = "Coping motives and the distress–drinking association", subtitle = "Conditional effects with pooled 95% intervals; sensitivity estimates") +
  scale_color_manual(values = c("#176a63", "#435b86", "#9a6738"))
ggsave(file.path(out, "figure-2-coping-sensitivity.png"), p2, width = 9.0, height = 5.2, dpi = 240)
ggsave(file.path(out, "figure-2-coping-sensitivity.pdf"), p2, width = 9.0, height = 5.2)
cat("COMPLETE", nrow(diag), "model fits,", nrow(eff), "pooled estimates\n")
