SELECT MAX((CURRENT_TIMESTAMP-lastlogged)/3600000) from health where hostname = 'gpu-st-p4de-24xlarge-6' AND cluster = 'parallelcluster-hpc-1click-big';
