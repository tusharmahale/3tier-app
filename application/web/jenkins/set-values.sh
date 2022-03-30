#!/bin/bash

sed -i "s#IMAGE_TAG#${IMAGE_TAG}#g" ${WORKSPACE}/application/web/Charts/values.yaml
sed -i "s#REGISTRY_ROOT#${REGISTRY_ROOT}#g" ${WORKSPACE}/application/web/Charts/values.yaml
sed -i "s#APPLICATION_NAME#${APPLICATION_NAME}#g" ${WORKSPACE}/application/web/Charts/values.yaml
sed -i "s#GIT_COMMIT_SHORT#${GIT_COMMIT_SHORT}#g" ${WORKSPACE}/application/web/Charts/Chart.yaml
sed -i "s#IMAGE_TAG#${IMAGE_TAG}#g" ${WORKSPACE}/application/web/Charts/values.yaml
aws s3 sync ${WORKSPACE}/application/web/Charts s3://flux-cd-repo-${APPLICATION_NAME}/charts --delete
