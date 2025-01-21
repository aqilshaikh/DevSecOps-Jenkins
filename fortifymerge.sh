FORTIFY_SOURCE_APP_NAME=""
FORTIFY_SOURCE_APP_VERSION=""
FORTIFY_DEST_APP_NAME=""
FORTIFY_DEST_APP_VERSION=""
FORTIFY_FPR_FILE_DEV=""
FORTIFY_URL=""
FORTIFY_CLIENT_API_KEY=""
FORTIFY_CLIENT_API_KEY_DOWNLOAD=""

for i in $*; do
  if [[ $i == --fortify.source.app.name=* ]]; then
    FORTIFY_SOURCE_APP_NAME=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --fortify.source.app.version=* ]]; then
    FORTIFY_SOURCE_APP_VERSION=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --fortify.dest.app.name=* ]]; then
    FORTIFY_DEST_APP_NAME=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --fortify.dest.app.version=* ]]; then
    FORTIFY_DEST_APP_VERSION=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --fortify.client.api.key=* ]]; then
    FORTIFY_CLIENT_API_KEY=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --fortify.client.api.key.download=* ]]; then
    FORTIFY_CLIENT_API_KEY_DOWNLOAD=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --fortify.fpr.file=* ]]; then
    FORTIFY_FPR_FILE_DEV=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --fortify.url=* ]]; then
    FORTIFY_URL=$(cut -d "=" -f2 <<< "$i")
  fi
done

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

echo "INFO: Download FPR"

fortifyclient downloadFPR \
-file "$FORTIFY_FPR_FILE_DEV" \
-application "$FORTIFY_SOURCE_APP_NAME" \
-applicationVersion "$FORTIFY_SOURCE_APP_VERSION" \
-url "$FORTIFY_URL" \
-authtoken "$FORTIFY_CLIENT_API_KEY_DOWNLOAD"

result=$? 
if [ $result -ne 0 ]; then
    echo " Error: Fortify Download FPR Failed $result" >&2
    exit 1
fi

echo "INFO: Upload scan"

fortifyclient uploadFPR \
-file "$FORTIFY_FPR_FILE_DEV" \
-application "$FORTIFY_DEST_APP_NAME" \
-applicationVersion "$FORTIFY_DEST_APP_VERSION" \
-url "$FORTIFY_URL" \
-authtoken "$FORTIFY_CLIENT_API_KEY"

result=$? 
if [ $result -ne 0 ]; then
    echo " Error: Fortify upload FPR failed $result" >&2
    exit 1
fi

exit 0
