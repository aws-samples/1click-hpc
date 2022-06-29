#!/bin/bash

aws s3 cp --quiet "${post_install_base}/enginframe/splash.html" /fsx/nice/enginframe/conf/tomcat/webapps/ROOT/index.html --region "${cfn_region}" || exit 1
