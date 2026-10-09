# Distress Coping Motives and Alcohol Use in Daily Life

**Nicholai Chasseau · Independent secondary-data working paper**

**Project development:** September 2026–present. **Working-paper release:** 9 October 2026; under author review.

How does daily distress relate to alcohol use, and does that association differ with baseline coping motives? This project uses investigator-collected and processed ecological momentary assessment data to build a transparent bridge from cognitive appraisal research to substance-use research.

**[Read the working paper](https://nickchass.github.io/distress-coping-alcohol/manuscript/Manuscript.html)** · **[Download the PDF](manuscript/Manuscript.pdf)** · **[Read the case study](https://nickchass.github.io/case-studies/distress-coping-alcohol.html)**

The working paper contains a developed literature review, explicit research questions, detailed methods, complete conditional-effect tables, three figures, a critical discussion, and a proposed prospective appraisal study. This release is under author review and has not been peer reviewed.

## What was analysed

The source cohort comprises **496 young adults** and **15,872 scheduled participant-days**. Actual model samples vary across imputations and specifications; see the diagnostics and manuscript rather than treating the scheduled denominator as the sample in every model.

- 50 initial multilevel hurdle models across five investigator-supplied imputations.
- 10 additional, explicitly post hoc models separating eligible-sample daily deviations from residual person means.
- Daily-mean and last eligible affect reports; covariate and common-sample comparisons; coping-motive interactions; observed-alcohol-outcome and imputed-count-cap sensitivities.
- Rubin-pooled uncertainty, sample audits, convergence and Hessian checks, a binary coding check, and a stricter optimizer comparison.

All 60 substantive models converged with a positive-definite Hessian. Numerical verification is documented; it does not establish the validity of causal or missing-data assumptions.

## Main result

The unadjusted daily-mean drinking odds ratio was **0.921 [0.872, 0.974]**. After adjustment it was **0.987 [0.936, 1.042]**. Coping interaction intervals included zero, and eligible-sample within-between decomposition gave a similar interpretation. These focused models do not establish a robust positive distress-drinking association.

Appraisal was **not measured**. The proposed next study measures event meaning, perceived coping resources, alcohol-relief expectations, craving, opportunity, and later use in distinct time windows. It is a proposal with no recruited participants or participant findings.

![Negative affect and drinking likelihood](results/figure-1-negative-affect.png)

## Data provenance and attribution

Original investigation: Dora, J., Kuczynski, A. M., McCabe, C. J., Creswell, K. G., Dvorak, R. D., Howard, A. L., Patrick, M. E., Shoda, Y., Smith, G. T., Wright, A. G. C., & King, K. M. (2026). *Testing the robustness of daily associations of affect with alcohol and cannabis use*. Journal of Psychopathology and Clinical Science, 135(3), 413-432. [doi:10.1037/abn0001097](https://doi.org/10.1037/abn0001097).

The original investigators collected the data, processed affect windows, and supplied imputations. Their public materials are at [OSF fm6cq](https://osf.io/fm6cq/). This reanalysis is unaffiliated with those investigators and does not imply endorsement. It examines a limited subset of decisions, not their complete specification curve or permutation inference. Participant data, investigator-authored source scripts, the source article, and fitted model objects are excluded from this repository.

## Reproduce the analysis

Requirements: Python 3.8+ for the standard-library download helper, R, and the packages listed in `analysis/setup.R`. The recorded run used R 4.6.0, glmmTMB 1.1.15.2, mice 3.19.0, ggplot2 4.0.3, and jsonlite 2.0.0. The setup script checks required packages and records differences from these versions. This is a recorded environment, not a locked dependency snapshot.

From the repository root:

```bash
Rscript analysis/setup.R
python3 download_data.py
Rscript analysis/analyze.R data/sms.imp.processed.RData results
Rscript analysis/verify.R results
Rscript analysis/revision_checks.R data/sms.imp.processed.RData results results/revision
Rscript analysis/plot_revision.R results results/revision results
```

The downloader checks the exact processed-file SHA-256 hash and stops if the source differs. The first analysis produces 50 fits and local model objects; the revision script requires those objects and adds ten fits. Model objects and downloaded data are ignored by Git. Computation can take several minutes or longer depending on hardware. Newly fitted numerical results can differ slightly with package, compiler, and optimizer versions. The manuscript's reported results are the archived aggregate output for this release.

The observed-outcome sensitivity retains the original affect imputations and is not a complete-case analysis. The count component uses a zero-truncated negative binomial; its log coefficient is not exactly the log ratio of the positive-truncated mean. The logistic component models non-use, so signs are reversed when reporting drinking odds ratios. These distinctions are explained in the paper.

## Repository contents

| Folder or file | Purpose |
|---|---|
| `manuscript/` | Working paper in PDF, editable Word, Markdown and HTML |
| `analysis/` | Model fitting, numerical checks, post hoc refinements and plotting |
| `results/` | Aggregate estimates, diagnostics, figures and environment records |
| `plans/` | Initial plan, audit amendment and post hoc refinement chronology |
| `provenance/` | Source download manifest and data dictionary |
| `download_data.py` | Fetch the original processed data directly and verify the hash |
| `CITATION.cff` | Citation for this working paper |

## Authorship and research status

This is Nicholai Chasseau's independently framed secondary-data working paper. OpenAI Codex assisted with implementation, numerical checks, literature organization, and manuscript drafting. Responsibility for evaluating, understanding, and approving the work rests with the named author; final author review is pending in this release. It is not presented as original data collection, a submitted thesis, a peer-reviewed publication, or a validated clinical model.

An initial plan preceded participant-outcome inspection, with the published source results already known. Audit-driven implementation details were recorded during estimation; the additional centring and degrees-of-freedom checks followed inspection of the initial estimates. None of these analyses was independently preregistered.

No general redistribution licence is asserted for the source data. Consult the original repository and investigators for reuse conditions. This repository does not grant rights over their materials. Private application ratings, CVs, interview preparation, correspondence, and personal clinical information are excluded from the public release.

Suggested citation: Chasseau, N. (2026). *Distress coping motives and alcohol use in daily life: A focused secondary analysis and a proposed study of cognitive appraisal* (Version 1.0) [Working paper]. https://github.com/NickChass/distress-coping-alcohol
