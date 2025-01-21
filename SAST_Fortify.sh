#!/bin/bash

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

# Function to handle errors
error_exit() {
    log "Error: $1"
    exit 1
}

# Validate required parameters
validate_params() {
    [ -z "$FORTIFY_APP_NAME" ] && error_exit "FORTIFY_APP_NAME is required"
    [ -z "$FORTIFY_APP_VERSION" ] && error_exit "FORTIFY_APP_VERSION is required"
    [ -z "$FORTIFY_SOURCE_CODE_PATH" ] && error_exit "FORTIFY_SOURCE_CODE_PATH is required"
    [ -z "$FORTIFY_FPR_FILE" ] && error_exit "FORTIFY_FPR_FILE is required"
    [ -z "$FORTIFY_URL" ] && error_exit "FORTIFY_URL is required"
    [ -z "$FORTIFY_REST_API_KEY" ] && error_exit "FORTIFY_REST_API_KEY is required"
    [ -z "$FORTIFY_CLIENT_API_KEY" ] && error_exit "FORTIFY_CLIENT_API_KEY is required"
}

# Parse command line arguments
for i in "$@"; do
    case $i in
        --fortify.app.name=*)
            FORTIFY_APP_NAME="${i#*=}"
            ;;
        --fortify.app.version=*)
            FORTIFY_APP_VERSION="${i#*=}"
            ;;
        --fortify.source.code.path=*)
            FORTIFY_SOURCE_CODE_PATH="${i#*=}"
            ;;
        --fortify.fpr.file=*)
            FORTIFY_FPR_FILE="${i#*=}"
            ;;
        --fortify.url=*)
            FORTIFY_URL="${i#*=}"
            ;;
        --fortify.rest.api.key=*)
            FORTIFY_REST_API_KEY="${i#*=}"
            ;;
        --fortify.client.api.key=*)
            FORTIFY_CLIENT_API_KEY="${i#*=}"
            ;;
        --fortify.client.api.key.download=*)
            FORTIFY_CLIENT_API_KEY_DOWNLOAD="${i#*=}"
            ;;
        --fortify.client.user.token=*)
            USER_TOKEN="${i#*=}"
            ;;
        --fortify.additional.params=*)
            FORTIFY_ADDITIONAL_PARAMS="${i#*=}"
            ;;
        *)
            ;;
    esac
done

validate_params

FORTIFY_FPR_FILE_LATEST=${FORTIFY_FPR_FILE%.fpr}_latest.fpr

log "Environment variables for Fortify SCA"
log "FORTIFY_APP_NAME=$FORTIFY_APP_NAME"
log "FORTIFY_APP_VERSION=$FORTIFY_APP_VERSION"
log "FORTIFY_SOURCE_CODE_PATH=$FORTIFY_SOURCE_CODE_PATH"
log "FORTIFY_FPR_FILE=$FORTIFY_FPR_FILE"
log "FORTIFY_URL=$FORTIFY_URL"
log "FORTIFY_REST_API_KEY=$FORTIFY_REST_API_KEY"
log "FORTIFY_CLIENT_API_KEY=$FORTIFY_CLIENT_API_KEY"
log "FORTIFY_CLIENT_API_KEY_DOWNLOAD=$FORTIFY_CLIENT_API_KEY_DOWNLOAD"
log "USER_TOKEN=$USER_TOKEN"
log "FORTIFY_ADDITIONAL_PARAMS=$FORTIFY_ADDITIONAL_PARAMS"

log "Generating API Token"
response=$(curl --location "$FORTIFY_URL/api/v1/tokens" \
    --header 'Accept: application/json, text/plain, */*' \
    --header 'Cache-Control: no-cache' \
    --header 'Content-Type: application/json;charset=UTF-8' \
    --header "Authorization: token $FORTIFY_REST_API_KEY" --silent)

API_TOKEN=$(echo "$response" | grep -oP '(?<=,"token":")[^"]+(?=",")')

if [ -z "$API_TOKEN" ]; then
    error_exit "Failed to generate API Token"
fi

log "Verifying project exists"
response=$(curl --silent --show-error --request GET --url "$FORTIFY_URL/api/v1/projectVersions?q=project.name:$FORTIFY_APP_NAME" \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "Authorization: FortifyToken $API_TOKEN")

if ! echo "$response" | grep -q "\"name\":\"$FORTIFY_APP_NAME\""; then
    error_exit "Project $FORTIFY_APP_NAME does not exist. Verify API Key, URL, and Project name are correct."
fi

log "Verifying project version exists"
response=$(curl --silent --show-error --request GET --url "$FORTIFY_URL/api/v1/projectVersions?q=name:$FORTIFY_APP_VERSION" \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "Authorization: FortifyToken $API_TOKEN")

if ! echo "$response" | grep -q "\"name\":\"$FORTIFY_APP_VERSION\""; then
    error_exit "Project version $FORTIFY_APP_VERSION does not exist. Verify API Key, URL, and Version are correct."
fi

log "Updating Fortify Rulepack"
bash DevSecOps-Jenkins/fortify/fortify-rulepack-update.sh
result=$?
if [ $result -ne 0 ]; then
    error_exit "Fortify Rulepack update failed with exit code $result"
fi

log "Cleaning previous scan artifacts"
sourceanalyzer -b "$FORTIFY_APP_NAME" -clean

log "Translating files"
sourceanalyzer -b "$FORTIFY_APP_NAME" "$FORTIFY_SOURCE_CODE_PATH" $FORTIFY_ADDITIONAL_PARAMS
result=$?
if [ $result -ne 0 ]; then
    error_exit "Fortify Translation failed with exit code $result"
fi

log "Starting scan"
sourceanalyzer -b "$FORTIFY_APP_NAME" -scan -f "$FORTIFY_FPR_FILE"
result=$?
if [ $result -ne 0 ]; then
    error_exit "Fortify Scan failed with exit code $result"
fi

log "Running merge script"
bash DevSecOps-Jenkins/fortify/fortifymerge.sh \
    --fortify.source.app.name="${FORTIFY_APP_NAME}" \
    --fortify.source.app.version="${FORTIFY_APP_VERSION}_latest" \
    --fortify.dest.app.name="${FORTIFY_APP_NAME}" \
    --fortify.dest.app.version="${FORTIFY_APP_VERSION}" \
    --fortify.url="${FORTIFY_URL}" \
    --fortify.fpr.file="${FORTIFY_FPR_FILE_LATEST}" \
    --fortify.client.api.key="${FORTIFY_CLIENT_API_KEY}" \
    --fortify.client.api.key.download="${FORTIFY_CLIENT_API_KEY_DOWNLOAD}"
result=$?
if [ $result -ne 0 ]; then
    error_exit "Fortify Merge failed with exit code $result"
fi

log "Uploading scan"
fortifyclient uploadFPR \
    -file "$FORTIFY_FPR_FILE" \
    -application "$FORTIFY_APP_NAME" \
    -applicationVersion "$FORTIFY_APP_VERSION" \
    -url "$FORTIFY_URL" \
    -authtoken "$FORTIFY_CLIENT_API_KEY"
result=$?
if [ $result -ne 0 ]; then
    error_exit "FPR Upload failed with exit code $result"
fi

log "Downloading FPR"
fortifyclient downloadFPR \
    -file "$FORTIFY_FPR_FILE_LATEST" \
    -application "$FORTIFY_APP_NAME" \
    -applicationVersion "$FORTIFY_APP_VERSION" \
    -url "$FORTIFY_URL" \
    -authtoken "$FORTIFY_CLIENT_API_KEY_DOWNLOAD"
result=$?
if [ $result -ne 0 ]; then
    error_exit "Download FPR failed with exit code $result"
fi

log "Getting SAST Critical issues"
SAST_CRITICAL=$(FPRUtility -information -categoryIssueCounts -project "$FORTIFY_FPR_FILE_LATEST" -search -query "[fortify priority order]:critical")
log "Critical=$SAST_CRITICAL"

log "Getting SAST High issues"
SAST_HIGH=$(FPRUtility -information -categoryIssueCounts -project "$FORTIFY_FPR_FILE_LATEST" -search -query "[fortify priority order]:high")
log "High=$SAST_HIGH"

log "Getting SAST Medium issues"
SAST_MEDIUM=$(FPRUtility -information -categoryIssueCounts -project "$FORTIFY_FPR_FILE_LATEST" -search -query "[fortify priority order]:medium")
log "Medium=$SAST_MEDIUM"

log "Getting SAST Low issues"
SAST_LOW=$(FPRUtility -information -categoryIssueCounts -project "$FORTIFY_FPR_FILE_LATEST" -search -query "[fortify priority order]:low")
log "Low=$SAST_LOW"

exit 0
