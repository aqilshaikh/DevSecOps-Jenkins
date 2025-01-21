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
    [ -z "$BLACKDUCK_PROJECT_NAME" ] && error_exit "BLACKDUCK_PROJECT_NAME is required"
    [ -z "$BLACKDUCK_PROJECT_VERSION" ] && error_exit "BLACKDUCK_PROJECT_VERSION is required"
    [ -z "$BLACKDUCK_SOURCE_CODE_PATH" ] && error_exit "BLACKDUCK_SOURCE_CODE_PATH is required"
    [ -z "$BLACKDUCK_CLIENT_API_KEY" ] && error_exit "BLACKDUCK_CLIENT_API_KEY is required"
    [ -z "$BLACKDUCK_URL" ] && error_exit "BLACKDUCK_URL is required"
}

# Parse command line arguments
for i in "$@"; do
    case $i in
        --blackduck.project.name=*)
            BLACKDUCK_PROJECT_NAME="${i#*=}"
            ;;
        --blackduck.project.version=*)
            BLACKDUCK_PROJECT_VERSION="${i#*=}"
            ;;
        --blackduck.source.code.path=*)
            BLACKDUCK_SOURCE_CODE_PATH="${i#*=}"
            ;;
        --blackduck.client.api.key=*)
            BLACKDUCK_CLIENT_API_KEY="${i#*=}"
            ;;
        --blackduck.detect.path.jar=*)
            BLACKDUCK_DETECT_PATH_JAR="${i#*=}"
            ;;
        --detect.detector.search.exclusion.defaults=*)
            BLACKDUCK_DETECTOR_SEARCH_EXCLUSION_DEFAULTS="${i#*=}"
            ;;
        --detect.detector.search.exclusion=*)
            BLACKDUCK_DETECTOR_SEARCH_EXCLUSION="${i#*=}"
            ;;
        --detect.excluded.directories=*)
            BLACKDUCK_DETECT_EXCLUDE_DIRS="${i#*=}"
            ;;
        --blackduck.url=*)
            BLACKDUCK_URL="${i#*=}"
            ;;
        --blackduck.additional.params=*)
            BLACKDUCK_ADDITIONAL_PARAMS="${i#*=}"
            ;;
        *)
            ;;
    esac
done

validate_params

log "Setting environment variables for BlackDuck SCA"
log "BLACKDUCK_PROJECT_NAME=$BLACKDUCK_PROJECT_NAME"
log "BLACKDUCK_PROJECT_VERSION=$BLACKDUCK_PROJECT_VERSION"
log "BLACKDUCK_SOURCE_CODE_PATH=$BLACKDUCK_SOURCE_CODE_PATH"
log "BLACKDUCK_CLIENT_API_KEY=****"
log "BLACKDUCK_URL=$BLACKDUCK_URL"
log "BLACKDUCK_DETECT_PATH_JAR=$BLACKDUCK_DETECT_PATH_JAR"
log "BLACKDUCK_DETECTOR_SEARCH_EXCLUSION_DEFAULTS=$BLACKDUCK_DETECTOR_SEARCH_EXCLUSION_DEFAULTS"
log "BLACKDUCK_DETECTOR_SEARCH_EXCLUSION=$BLACKDUCK_DETECTOR_SEARCH_EXCLUSION"
log "BLACKDUCK_DETECT_EXCLUDE_DIRS=$BLACKDUCK_DETECT_EXCLUDE_DIRS"
log "BLACKDUCK_ADDITIONAL_PARAMS=$BLACKDUCK_ADDITIONAL_PARAMS"

log "Generating Bearer Token for the script"
response=$(curl --location --request POST "$BLACKDUCK_URL/api/tokens/authenticate" \
    --header "Authorization: token $BLACKDUCK_CLIENT_API_KEY" \
    --header 'Accept: application/vnd.blackducksoftware.user-4+json' --silent)

if [ $? -eq 0 ]; then
    Bearer_Token=$(echo $response | grep -oP '(?<="bearerToken":")[^"]+')
    [ -z "$Bearer_Token" ] && error_exit "Failed to generate Bearer Token"
else
    error_exit "Either Invalid Blackduck URL OR Invalid Blackduck token provided"
fi

log "Getting project: $BLACKDUCK_PROJECT_NAME"
response=$(curl --location "$BLACKDUCK_URL/api/projects?q=name:$BLACKDUCK_PROJECT_NAME" \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "Authorization: Bearer $Bearer_Token" --insecure --silent)

if echo "$response" | grep -q '"totalCount":[1-9][0-9]*'; then
    PROJECT_ID=$(echo "$response" | grep -oP '(?<=/api/projects/)[^/]+(?=/versions)' | uniq)
    log "Project exists and retrieving PROJECT_ID: $PROJECT_ID"
else
    error_exit "Given Blackduck Project $BLACKDUCK_PROJECT_NAME does not exist in Blackduck"
fi

log "Getting project versions from: $BLACKDUCK_PROJECT_NAME"
CURL_BLACKDUCK_URL="$BLACKDUCK_URL/api/projects/$PROJECT_ID/versions?q=versionName:$BLACKDUCK_PROJECT_VERSION"
response=$(curl --location "$CURL_BLACKDUCK_URL" \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    --header "Authorization: Bearer $Bearer_Token" --insecure --silent)

if echo "$response" | grep -q '"totalCount":[1-9][0-9]*' && echo "$response" | grep -qw "$BLACKDUCK_PROJECT_VERSION"; then
    log "Running BlackDuck Software Composition Analysis"
    java -jar "$BLACKDUCK_DETECT_PATH_JAR/$BLACKDUCK_DETECT_JAR" \
        --detect.source.path="$BLACKDUCK_SOURCE_CODE_PATH" \
        --blackduck.url="$BLACKDUCK_URL" \
        --blackduck.trust.cert=true \
        --blackduck.api.token="$BLACKDUCK_CLIENT_API_KEY" \
        --detect.policy.check.fail.on.severities=CRITICAL \
        --detect.project.name="$BLACKDUCK_PROJECT_NAME" \
        --detect.project.version.name="$BLACKDUCK_PROJECT_VERSION" \
        --detect.code.location.name="$BLACKDUCK_PROJECT_VERSION" \
        --detect.detector.search.exclusion.defaults="$BLACKDUCK_DETECTOR_SEARCH_EXCLUSION_DEFAULTS" \
        --detect.detector.search.exclusion="$BLACKDUCK_DETECTOR_SEARCH_EXCLUSION" \
        --detect.excluded.directories="$BLACKDUCK_DETECT_EXCLUDE_DIRS" \
        $BLACKDUCK_ADDITIONAL_PARAMS
    
    result=$? 
    if [ $result -ne 0 ]; then
        error_exit "Blackduck scan failed with exit code $result"
    fi
else 
    error_exit "Given Blackduck Version $BLACKDUCK_PROJECT_VERSION does not exist in Blackduck or has an invalid version name"
fi

log "Removing temporary files"
rm *.txt
