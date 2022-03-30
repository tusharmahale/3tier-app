#!/bin/bash

get_aws_credentials(){
    unset VAULT_TOKEN
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN

    get_vault_token=$(echo "vault write ${VAULT_LOGIN_PATH} role_id=$VAULT_ROLE_ID secret_id=$VAULT_SECRET_ID")
    vault_token_response=$(eval "$get_vault_token")
    sleep 3
    export VAULT_TOKEN=$(echo "${vault_token_response}" | jq -r ".auth.client_token")

    [[ -z $VAULT_TOKEN ]] && { echo "Invalid Vault token"; exit 1; } || { echo "Vault token generated .."; }

    x=0
    while [[ $x -le 10  ]]
    do
    	vault_path=$(echo "vault read $VAULT_SECRET_PATH")
    	AWS_CREDENTIALS=$(eval "$vault_path")
    	AWS_ACCESS_KEY_ID=$(echo "${AWS_CREDENTIALS}" | jq -r ".data.access_key")
    	if [[ -n ${AWS_ACCESS_KEY_ID} ]]; then
    		# echo $AWS_CREDENTIALS										
    		break
    	fi
    	sleep 5
    	x=$(( $x + 1 ))
    done

    CREDS_FILE=${WORKSPACE}/temp-credentials-securityportal-${BUILD_NUMBER}-${BRANCH_NAME}
    rm -f ${CREDS_FILE} > /dev/null 2>&1

    # echo $AWS_CREDENTIALS > ${CREDS_FILE}-aws
    export AWS_ACCESS_KEY_ID=$(echo "${AWS_CREDENTIALS}" | jq -r ".data.access_key") 
    export AWS_SECRET_ACCESS_KEY=$(echo "${AWS_CREDENTIALS}" | jq -r ".data.secret_key") 
    export AWS_SESSION_TOKEN=$(echo "${AWS_CREDENTIALS}" | jq -r ".data.security_token")

    [[ -z $AWS_ACCESS_KEY_ID ]] && { echo "ERROR - Variable AWS_ACCESS_KEY_ID not found."; exit 1; }
    [[ -z $AWS_SECRET_ACCESS_KEY ]] && { echo "ERROR - Variable AWS_SECRET_ACCESS_KEY not found."; exit 1; }
    [[ -z $AWS_SESSION_TOKEN ]] && { echo "ERROR - Variable AWS_SESSION_TOKEN not found."; exit 1; }


    echo AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID >> ${CREDS_FILE}
    echo AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY >> ${CREDS_FILE}
    echo AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN >> ${CREDS_FILE}

}

main(){
    get_aws_credentials
}

main $@
