FORTIFY_APP_NAME=""
FORTIFY_APP_VERSION=""
FORTIFY_SOURCE_CODE_PATH=""
FORTIFY_FPR_FILE=""
FORTIFY_URL=""
FORTIFY_REST_API_KEY=""
FORTIFY_CLIENT_API_KEY=""
FORTIFY_CLIENT_API_KEY_DOWNLOAD=""
FORTIFY_SOURCE_APP_NAME=""
FORTIFY_SOURCE_VERSION_NAME=""
FORTIFY_ADDITIONAL_PARAMS=""
DEVFIND="_DEV"
LATEST="latest"

for i in "$@"; do
  if [[ $i == --fortify.app.name=* ]]; then
    FORTIFY_APP_NAME=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --fortify.app.version=* ]]; then
    FORTIFY_APP_VERSION=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --fortify.source.code.path=* ]]; then
    FORTIFY_SOURCE_CODE_PATH=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --fortify.fpr.file=* ]]; then
    FORTIFY_FPR_FILE=$(cut -d "=" -f2 <<< "$i")
   elif [[ $i == --fortify.url=* ]]; then
    FORTIFY_URL=$(cut -d "=" -f2 <<< "$i") 
  elif [[ $i == --fortify.rest.api.key=* ]]; then
    FORTIFY_REST_API_KEY=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --fortify.client.api.key=* ]]; then
    FORTIFY_CLIENT_API_KEY=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --fortify.client.api.key.download=* ]]; then
    FORTIFY_CLIENT_API_KEY_DOWNLOAD=$(cut -d "=" -f2 <<< "$i")
 elif [[ $i == --fortify.client.user.token=* ]]; then
   USER_TOKEN=$(cut -d "=" -f2- <<< "$i")
  elif [[ "$i" == --fortify.additional.params=* ]]; then
    FORTIFY_ADDITIONAL_PARAMS="${i#*=}"
  fi
done
FORTIFY_FPR_FILE_LATEST=${FORTIFY_FPR_FILE%.fpr}_latest.fpr
#FORTIFY_FPR_FILE_CURRENT="$FORTIFY_FPR_FILE"
echo "***********************************************"
echo "Environment variables for Fortify SCA"
echo "FORTIFY_APP_NAME=$FORTIFY_APP_NAME"
echo "FORTIFY_APP_VERSION=$FORTIFY_APP_VERSION"
echo "FORTIFY_SOURCE_CODE_PATH=$FORTIFY_SOURCE_CODE_PATH"
echo "FORTIFY_FPR_FILE=$FORTIFY_FPR_FILE"
echo "FORTIFY_URL=$FORTIFY_URL"
echo "FORTIFY_REST_API_KEY=$FORTIFY_REST_API_KEY"
echo "FORTIFY_CLIENT_API_KEY=$FORTIFY_CLIENT_API_KEY"
echo "FORTIFY_CLIENT_API_KEY_DOWNLOAD=$FORTIFY_CLIENT_API_KEY_DOWNLOAD"
echo "USER_TOKEN=$USER_TOKEN"
echo "FORTIFY_ADDITIONAL_PARAMS=$FORTIFY_ADDITIONAL_PARAMS"
echo "***********************************************"

curl --location "$FORTIFY_URL/api/v1/tokens" --header 'Accept: application/json, text/plain, */*' --header 'Cache-Control: no-cache' --header 'Content-Type: application/json;charset=UTF-8' --header "Authorization: Basic $USER_TOKEN" --data '{"type": "UnifiedLoginToken"}'  > API_token.txt
API_TOKEN=$(grep -oP '(?<=,"token":")[^"]+(?=",")' API_token.txt | uniq)

echo "****Verifying Project exists****"

curl -k --silent --show-error --request GET --url "$FORTIFY_URL/api/v1/projectVersions?q=project.name:$FORTIFY_APP_NAME" \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header "Authorization: FortifyToken $API_TOKEN"  > project.txt

if grep -q "\"name\":\"$FORTIFY_APP_NAME\"" project.txt; then
  echo "Project exists and can Proceed for scan"
else
  echo "Error in Retrieving Project "$FORTIFY_APP_NAME".Verify API Key , $FORTIFY_URL and Projectname provided is correct." $(cat project.txt)   
  exit 1
fi


curl -k --silent --show-error --request GET --url "$FORTIFY_URL/api/v1/projectVersions?q=name:$FORTIFY_APP_VERSION" \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header "Authorization: FortifyToken $API_TOKEN" > version.txt

if grep -q "\"name\":\"$FORTIFY_APP_VERSION *\"" version.txt; then
  echo "Projectversion exists and can Proceed for scan"
else
    echo "Error in Retrieving Projectversion "$FORTIFY_APP_VERSION".Verify API Key,$FORTIFY_URL and Version provided is correct " $(cat version.txt) 
    exit 1
fi

bash appsec-scripts/fortify/fortify-rulepack-update.sh
result=$? 
if [ $result -ne 0 ]; then
    echo " Error: Fortify Rulepack update failed.Check for error details $result" >&2
fi


echo "INFO: sourceanalyzer version"
sourceanalyzer -version
echo "INFO: Cleaning previous scan artifacts"
sourceanalyzer -b "$FORTIFY_APP_NAME" -clean
echo "INFO: Translating files"
echo "sourceanalyzer -b "$FORTIFY_APP_NAME" "$FORTIFY_SOURCE_CODE_PATH" $FORTIFY_ADDITIONAL_PARAMS"
sourceanalyzer -b "$FORTIFY_APP_NAME" "$FORTIFY_SOURCE_CODE_PATH" $FORTIFY_ADDITIONAL_PARAMS
result=$? 
if [ $result -ne 0 ]; then
    echo " Error: Fortify Translation failed.Check for error detailsh $result" >&2
    exit 1
fi
echo "INFO: Starting scan"
#sourceanalyzer -b "$FORTIFY_APP_NAME" -scan -f "$FORTIFY_FPR_FILE" $FORTIFY_ADDITIONAL_PARAMS
sourceanalyzer -b "$FORTIFY_APP_NAME" -scan -f "$FORTIFY_FPR_FILE"

result=$? 
if [ $result -ne 0 ]; then
    echo " Error: Fortify Scan failed.Check for error details $result" >&2
    exit 1
fi
if [[ $FORTIFY_APP_NAME == *"_DEV"* ]]; then
  FORTIFY_SOURCE_APP_NAME=${FORTIFY_APP_NAME%_DEV} 
  FORTIFY_SOURCE_VERSION_NAME=${FORTIFY_APP_VERSION%_DEV}_latest
  
  echo " Running Purge Script......."
 
  bash appsec-scripts/fortify/purge/fortifypurge.sh $FORTIFY_URL $USER_TOKEN $FORTIFY_APP_NAME $FORTIFY_APP_VERSION
  result=$? 
  if [ $result -ne 0 ]; then
    echo " Error: Fortify Purge failed.Check for error details $result" >&2
  fi
  
  echo "FORTIFY_SOURCE_APP_NAME=$FORTIFY_SOURCE_APP_NAME"
  echo "FORTIFY_SOURCE_APP_VERSION=$FORTIFY_SOURCE_VERSION_NAME"
 
  echo "Running merge script........"
  ls
  bash appsec-scripts/fortify/fortifymerge.sh \
                --fortify.source.app.name="${FORTIFY_SOURCE_APP_NAME}" \
                --fortify.source.app.version="${FORTIFY_SOURCE_VERSION_NAME}" \
                --fortify.dest.app.name="${FORTIFY_APP_NAME}" \
                --fortify.dest.app.version="${FORTIFY_APP_VERSION}" \
                --fortify.url="${FORTIFY_URL}" \
                --fortify.fpr.file="${FORTIFY_FPR_FILE_LATEST}" \
                --fortify.client.api.key="${FORTIFY_CLIENT_API_KEY}" \
                --fortify.client.api.key.download="${FORTIFY_CLIENT_API_KEY_DOWNLOAD}"
  result=$? 
  if [ $result -ne 0 ]; then
    echo " Error: Fortify Merge failed.Check for error details $result" >&2
   
  fi
                
fi

echo "INFO: Upload scan"
fortifyclient uploadFPR \
-file "$FORTIFY_FPR_FILE" \
-application "$FORTIFY_APP_NAME" \
-applicationVersion "$FORTIFY_APP_VERSION" \
-url "$FORTIFY_URL" \
-authtoken "$FORTIFY_CLIENT_API_KEY"
result=$? 
if [ $result -ne 0 ]; then
    echo " Error: FPR Upload failed.Check for error details $result" >&2
    exit 1
fi

echo "INFO: Download FPR"
fortifyclient downloadFPR \
-file "FORTIFY_FPR_FILE_LATEST.fpr" \
-application "$FORTIFY_APP_NAME" \
-applicationVersion "$FORTIFY_APP_VERSION" \
-url "$FORTIFY_URL" \
-authtoken "$FORTIFY_CLIENT_API_KEY_DOWNLOAD"
result=$? 
if [ $result -ne 0 ]; then
    echo " Error: Download FPR failed with $result" >&2
    exit 1
fi

echo "INFO: Get SAST Critical"
SAST_CRITICAL=$(FPRUtility -information -categoryIssueCounts -project "FORTIFY_FPR_FILE_LATEST.fpr" -search -query "[fortify priority order]:critical")
echo "Critical=$SAST_CRITICAL"
echo "INFO: Get SAST High"
SAST_HIGH=$(FPRUtility -information -categoryIssueCounts -project "FORTIFY_FPR_FILE_LATEST.fpr" -search -query "[fortify priority order]:high")
echo "High=$SAST_HIGH"
echo "INFO: Get SAST Medium"
SAST_MEDIUM=$(FPRUtility -information -categoryIssueCounts -project "FORTIFY_FPR_FILE_LATEST.fpr" -search -query "[fortify priority order]:medium")
echo "Medium=$SAST_MEDIUM"
echo "INFO: Get SAST Low"
SAST_LOW=$(FPRUtility -information -categoryIssueCounts -project "FORTIFY_FPR_FILE_LATEST.fpr" -search -query "[fortify priority order]:low")
echo "Low=$SAST_LOW"
exit 0
