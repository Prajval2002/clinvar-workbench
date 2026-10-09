
## ClinVar Workbench Development Run



Tested on an HG002 development region: GRCh38 chr1:900000-1100000 (200 kb).



### Post-processing

After the filtered VCF, VEP VCF and ClinVar reference are available, run:



```bash

bash scripts/run_postprocessing.sh

```



Outputs are written to $HOME/clinngs-work/results/HG002_dev_chr1/annotation/.



This is a research prototype, not a clinically validated diagnostic pipeline.

Missing ClinVar evidence does not imply benignity.
