#!/bin/bash

sed -i "s#IMAGE_TAG#${IMAGE_TAG}#g" ${WORKSPACE}/application/api/Charts/values.yaml
sed -i "s#REGISTRY_ROOT#${REGISTRY_ROOT}#g" ${WORKSPACE}/application/api/Charts/values.yaml
sed -i "s#APPLICATION_NAME#${APPLICATION_NAME}#g" ${WORKSPACE}/application/api/Charts/values.yaml
sed -i "s#GIT_COMMIT_SHORT#${GIT_COMMIT_SHORT}#g" ${WORKSPACE}/application/api/Charts/Chart.yaml
sed -i "s#IMAGE_TAG#${IMAGE_TAG}#g" ${WORKSPACE}/application/web/Charts/values.yaml
sed -i "s#DBUSER#${DBUSER}#g" ${WORKSPACE}/application/api/Charts/values.yaml
sed -i "s#DBPASS#${DBPASS}#g" ${WORKSPACE}/application/api/Charts/values.yaml
sed -i "s#DBHOST#${DBHOST}#g" ${WORKSPACE}/application/api/Charts/values.yaml
sed -i "s#DBPORT#${DBPORT}#g" ${WORKSPACE}/application/api/Charts/values.yaml
sed -i "s#DBNAME#${DBNAME}#g" ${WORKSPACE}/application/api/Charts/values.yaml
aws s3 sync ${WORKSPACE}/application/api/Charts s3://flux-cd-repo-${APPLICATION_NAME}/charts --delete

