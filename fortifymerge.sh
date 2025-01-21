#!/bin/bash

# Initialize variables
FORTIFY_SOURCE_APP_NAME=""
FORTIFY_SOURCE_APP_VERSION=""
FORTIFY_DEST_APP_NAME=""
FORTIFY_DEST_APP_VERSION=""
FORTIFY_FPR_FILE_DEV=""
FORTIFY_URL=""
FORTIFY_CLIENT_API_KEY=""
FORTIFY_CLIENT_API_KEY_DOWNLOAD=""

# Parse input parameters
for i in "$@"; do
  case $i in
    --fortify.source.app.name=*)
      FORTIFY_SOURCE_APP_NAME="${i#*=}"
      ;;
    --fortify.source.app.version=*)
      FORTIFY_SOURCE_APP_VERSION="${i#*=}"
      ;;
    --fortify.dest.app.name=*)
      FORTIFY_DEST_APP_NAME="${i#*=}"
      ;;
    --fortify.dest.app.version=*)
      FORTIFY_DEST_APP_VERSION="${i#*=}"
      ;;
    --fortify.client.api.key=*)
      FORTIFY_CLIENT_API_KEY="${i#*=}"
      ;;
    --fortify.client.api.key.download=*)
      FORTIFY_CLIENT_API_KEY_DOWNLOAD="${i#*=}"
      ;;
    --fortify.fpr.file=*)
      FORTIFY_FPR_FILE_DEV="${i#*=}"
      ;;
    --fortify.url=*)
      FORTIFY_URL="${i#*=}"
      ;;
    *)
      echo "Unknown option $i"
      exit 1
      ;;
  esac
done

# Validate inputs
if [ -z "$FORTIFY_SOURCE_APP_NAME" ] || [ -z "$FORTIFY_SOURCE_APP_VERSION" ] || [ -z "$FORTIFY_DEST_APP_NAME" ] || [ -z "$FORTIFY_DEST_APP_VERSION" ] || [ -z "$FORTIFY_FPR_FILE_DEV" ] || [ -z "$FORTIFY_URL" ] || [ -z "$FORTIFY_CLIENT_API_KEY" ] || [ -z "$FORTIFY_CLIENT_API_KEY_DOWNLOAD" ]; then
  echo "Error: Missing required parameters."
  exit 1
fi

# Display environment variables
echo "***********************************************"
echo "Environment variables for Fortify SCA"
echo "FORTIFY_SOURCE_APP_NAME=$FORTIFY_SOURCE_APP_NAME"
echo "FORTIFY_SOURCE_APP_VERSION=$FORTIFY_SOURCE_APP_VERSION"
echo "FORTIFY_DEST_APP_NAME=$FORTIFY_DEST_APP_NAME"
echo "FORTIFY_DEST_APP_VERSION=$FORTIFY_DEST_APP_VERSION"
echo "FORTIFY_FPR_FILE=$FORTIFY_FPR_FILE_DEV"
echo "FORTIFY_URL=$FORTIFY_URL"
echo "FORTIFY_CLIENT_API_KEY=$FORTIFY_CLIENT_API_KEY"
echo "FORTIFY_CLIENT_API_KEY_DOWNLOAD=$FORTIFY_CLIENT_API_KEY_DOWNLOAD"
echo "***********************************************"

# Download FPR
echo "INFO: Downloading FPR..."
fortifyclient downloadFPR \
  -file "$FORTIFY_FPR_FILE_DEV" \
  -application "$FORTIFY_SOURCE_APP_NAME" \
  -applicationVersion "$FORTIFY_SOURCE_APP_VERSION" \
  -url "$FORTIFY_URL" \
  -authtoken "$FORTIFY_CLIENT_API_KEY_DOWNLOAD"

# Check download result
result=$?
if [ $result -ne 0 ]; then
  echo "Error: Fortify Download FPR Failed with exit code $result" >&2
  exit 1
fi

# Upload scan
echo "INFO: Uploading FPR..."
fortifyclient uploadFPR \
  -file "$FORTIFY_FPR_FILE_DEV" \
  -application "$FORTIFY_DEST_APP_NAME" \
  -applicationVersion "$FORTIFY_DEST_APP_VERSION" \
  -url "$FORTIFY_URL" \
  -authtoken "$FORTIFY_CLIENT_API_KEY"

# Check upload result
result=$?
if [ $result -ne 0 ]; then
  echo "Error: Fortify upload FPR failed with exit code $result" >&2
  exit 1
fi

echo "INFO: Fortify merge completed successfully."
exit 0
