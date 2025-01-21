BLACKDUCK_PROJECT_NAME=""
BLACKDUCK_PROJECT_VERSION=""
BLACKDUCK_SOURCE_CODE_PATH=""
BLACKDUCK_CLIENT_API_KEY=""
BLACKDUCK_DETECT_PATH_JAR="."
BLACKDUCK_URL=""
BLACKDUCK_DETECT_JAR="synopsys-detect-9.3.0.jar"
BLACKDUCK_DETECTOR_SEARCH_EXCLUSION_DEFAULTS=""
BLACKDUCK_DETECT_EXCLUDE_DIRS=""
BLACKDUCK_DETECTOR_SEARCH_EXCLUSION=""
BLACKDUCK_ADDITIONAL_PARAMS=""

for i in "$@"; do
  if [[ $i == --blackduck.project.name=* ]]; then
    BLACKDUCK_PROJECT_NAME=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --blackduck.project.version=* ]]; then
    BLACKDUCK_PROJECT_VERSION=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --blackduck.source.code.path=* ]]; then
    BLACKDUCK_SOURCE_CODE_PATH=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --blackduck.client.api.key=* ]]; then
    BLACKDUCK_CLIENT_API_KEY=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --blackduck.detect.path.jar=* ]]; then
    BLACKDUCK_DETECT_PATH_JAR=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --detect.detector.search.exclusion.defaults=* ]]; then
    BLACKDUCK_DETECTOR_SEARCH_EXCLUSION_DEFAULTS=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --detect.detector.search.exclusion=* ]]; then
    BLACKDUCK_DETECTOR_SEARCH_EXCLUSION=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --detect.excluded.directories=* ]]; then
    BLACKDUCK_DETECT_EXCLUDE_DIRS=$(cut -d "=" -f2 <<< "$i")
  elif [[ $i == --blackduck.url=* ]]; then
    BLACKDUCK_URL=$(cut -d "=" -f2 <<< "$i")
  elif [[ "$i" == --blackduck.additional.params=* ]]; then
    BLACKDUCK_ADDITIONAL_PARAMS="${i#*=}"
  fi
done


echo "***********************************************"
echo "Environment variables for BlackDuck SCA"
echo "BLACKDUCK_PROJECT_NAME=$BLACKDUCK_PROJECT_NAME"
echo "BLACKDUCK_PROJECT_VERSION=$BLACKDUCK_PROJECT_VERSION"
echo "BLACKDUCK_SOURCE_CODE_PATH=$BLACKDUCK_SOURCE_CODE_PATH"
echo "BLACKDUCK_CLIENT_API_KEY=$BLACKDUCK_CLIENT_API_KEY"
echo "BLACKDUCK_URL=$BLACKDUCK_URL"
echo "BLACKDUCK_DETECT_PATH_JAR=$BLACKDUCK_DETECT_PATH_JAR"
echo "BLACKDUCK_DETECTOR_SEARCH_EXCLUSION_DEFAULTS=$BLACKDUCK_DETECTOR_SEARCH_EXCLUSION_DEFAULTS"
echo "BLACKDUCK_DETECTOR_SEARCH_EXCLUSION=$BLACKDUCK_DETECTOR_SEARCH_EXCLUSION"
echo "BLACKDUCK_DETECT_EXCLUDE_DIRS= $BLACKDUCK_DETECT_EXCLUDE_DIRS"
echo "BLACKDUCK_ADDITIONAL_PARAMS=$BLACKDUCK_ADDITIONAL_PARAMS"
echo "***********************************************"

echo "**************************************************************"
echo "**************Generating Bearer Token for the script**********"
echo "**************************************************************"

curl --location --request POST "$BLACKDUCK_URL/api/tokens/authenticate" --header "Authorization: token $BLACKDUCK_CLIENT_API_KEY" --header 'Accept: application/vnd.blackducksoftware.user-4+json' --insecure > token.txt

if [ "$?" -eq 0 ]; then
    echo "Generate Bearer Token"
    Bearer_Token=$(grep -oP '(?<=":")[^/]+(?=",")' token.txt)
else
    echo " Error: Either Invalid Blackduck URL OR Invalid Blackduck token provided "
    exit 1
fi

echo "*********************** GETTING PROJECT : $BLACKDUCK_PROJECT_NAME*******************"

curl --location "$BLACKDUCK_URL/api/projects?q=name:$BLACKDUCK_PROJECT_NAME" \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header "Authorization: Bearer $Bearer_Token" --insecure > projectid.txt

if grep -q '"totalCount":[1-9][0-9]*' projectid.txt; then
  PROJECT_ID=$(grep -o "\"name\":\"$BLACKDUCK_PROJECT_NAME\",[^}]*" projectid.txt | grep -oP '(?<=/api/projects/)[^/]+(?=/versions)' | uniq)
  echo "Project exists and Retrieving PROJECT_ID:$PROJECT_ID"
else
    echo " Error: Given Blackduck Project $BLACKDUCK_PROJECT_NAME does not exists in Blackduck "
    exit 1
fi



echo "*********************** GETTING PROJECT VERSIONS FROM : $BLACKDUCK_PROJECT_NAME*******************"

echo "Project_id is : $PROJECT_ID"

#BLACKDUCK_PROJECT_VERSION="$(echo -e "$BLACKDUCK_PROJECT_VERSION" | tr -d '[:space:]')"
#echo "BLACKDUCK_PROJECT_VERSION : $BLACKDUCK_PROJECT_VERSION end"
CURL_BLACKDUCK_URL="$BLACKDUCK_URL/api/projects/$PROJECT_ID/versions?q=versionName:$BLACKDUCK_PROJECT_VERSION"
echo "CURL_BLACKDUCK_URL : $CURL_BLACKDUCK_URL end"
curl --location $CURL_BLACKDUCK_URL \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header "Authorization: Bearer $Bearer_Token" --insecure > versions.txt

cat versions.txt

#if [ "?" -eq 0 ]; then

if grep -q '"totalCount":[1-9][0-9]*' versions.txt && grep -qw "$BLACKDUCK_PROJECT_VERSION" versions.txt ; then

  echo "***********************************************"
  echo "Running BlackDuck Software Composition Analysis"
  echo "***********************************************"
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
    echo " Error: Blackduck scan failed with $result" >&2
    exit 1
  fi

else 
  echo " Error: Given Blackduck Version $BLACKDUCK_PROJECT_VERSION does not exists in blackduck or having invalid version name "
  exit 1
fi

bash appsec-scripts/blackduck/compare/compare.sh $BLACKDUCK_URL $BLACKDUCK_CLIENT_API_KEY $BLACKDUCK_PROJECT_NAME $BLACKDUCK_PROJECT_VERSION
result=$? 
  if [ $result -ne 0 ]; then
    echo " Error: Blackduck Compare script failed with $result" >&2
    exit 1
  fi
echo "Removing temporary files"
rm *.txt



