# Data dictionary and decisions

The original `sms.imp.processed.RData` contains `sms.imp.alc` and `sms.imp.mar`, each a `mids` object. This project uses `sms.imp.alc`, extracting all five imputations through `mice::complete`.

| Variable | Meaning and use |
|---|---|
| PID | Participant identifier; random intercept grouping factor. |
| study_day | Source study-day identifier; combined with PID to verify unique rows within an operationalization. |
| operationalization | Five affect summaries repeat the same days. This project filters `mean` or `most` separately. |
| mood.negative | Source within-person-standardized negative affect, using author-defined prior-onset filtering. `mean` is daily mean; `most` is last eligible report. |
| mood.positive | Source standardized positive affect; included as an adjusted-model covariate. |
| alc.quant | Source-aligned daily alcohol count from next-morning reporting; observed instrument ends at 30+. Imputed values can exceed 30. |
| DMQ.coping | Baseline mean coping-motive score. The project calculates `copingz` from one record per each of 496 unique participants. |
| DMQ.coping.low/high | Source recentered scores. The project verifies its canonical z against `DMQ.coping.low + 1` and explicitly probes z = −1, 0, +1. Source column names do not define this project's low/high labels. |
| birthsex | Source categorical sex-at-birth variable; residual missingness remains. |
| mar.quantgram | Source same-day cannabis quantity; a covariate only. Cannabis is not an outcome in this project. |
| weekday / season | Source categorical calendar covariates. Season has residual missingness; therefore adjusted-model samples are smaller. |
| observed_alcohol | Project indicator from nonmissing `alc.quant` in the processed `.imp=0` object. This does not indicate complete affect records. |
| affect | Project alias of `mood.negative` for model formulas. |

Both affect summaries use only source-defined eligible reports. On non-use days, the authors apply each participant's median onset cutoff. These are outcome-dependent processing decisions; 'prior-use' does not mean an independently scheduled forecast window.

For each specification, the complete covariate set defines that model's sample separately within each imputation. The `common_sample_unadjusted` model uses the adjusted-model sample while omitting its adjustment covariates. `observed_outcomes` additionally retains only originally observed alcohol counts, but uses imputed affect. `capped_imputed_tail` caps only imputed counts at 30 and does not alter observed 30+ reports.

`zi` in numerical output is already sign-reversed to report drinking, whereas glmmTMB's fitted zero coefficients model no drinking. `cond` is the truncated-negative-binomial mean-parameter coefficient. Its exponentiation is not an exact positive-day expected-count ratio. Confidence intervals are pooled across five supplied imputations.

## Additional eligible-sample decomposition

`affect_mean` is the participant mean of `mood.negative` over eligible covariate-complete rows within each affect operation and imputation. `affect_within` subtracts that mean. The model includes both terms, with a within-affect-by-coping interaction. Source units are retained. This post hoc check is recorded in `plans/revision-plan.json`.
