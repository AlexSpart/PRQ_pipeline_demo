#!/bin/sh
export GMT_DOCKER_COMPOSE_URL="https://github.com/radon-h2020/radon-gmt/blob/project/radon/docker-compose.yml"
export GMT_HTTP_PORT="18080"
export PARTICLES_URL="https://github.com/radon-h2020/radon-particles.git"
export PARTICLES_BRANCH="master"
export PARTICLES_DIR="${WORKSPACE}/radon-particles"
export CTT_DOCKER_NAME="RadonCTT"
export CTT_SERVER_DOCKER="radonconsortium/radon-ctt"
export CTT_VOLUME="${WORKSPACE}/RadonCTT"
export CTT_PORT="18080"
export CTT_EXT_PORT="7999"
export CTT_ENDPOINT="http://localhost:${CTT_EXT_PORT}/RadonCTT"
export CTT_RESULT_FILE="${WORKSPACE}/result.zip"
export REPO_DEMO_URL="https://github.com/AlexSpart/PRQ_pipeline_demo.git"
export REPO_DEMO_BRANCH="master"
export REPO_DEMO_DIR="${WORKSPACE}/repo-demo-dir"
export SUT_CSAR_FN="sut.csar"
export SUT_CSAR="${WORKSPACE}/${SUT_CSAR_FN}"
export TI_CSAR_FN="ti.csar"
export TI_CSAR="${WORKSPACE}/${TI_CSAR_FN}"
    

export NAME="CTT-master"
export CTT_SERVER_DOCKER_TAG="latest"
export SUT_EXPORT_URL="http://127.0.0.1:${GMT_HTTP_PORT}/winery/servicetemplates/radon.blueprints/SockShopTestingExample/?yaml&csar"
export SUT_DEPLOYMENT_PORT="80"
export SUT_DEPLOYMENT_URL="http://localhost:${SUT_DEPLOYMENT_PORT}"
export TI_EXPORT_URL="http://127.0.0.1:${GMT_HTTP_PORT}/winery/servicetemplates/radon.blueprints.testing/JMeterMasterOnly/?yaml&csar"
export TI_DEPLOYMENT_PORT="5000"
export TI_DEPLOYMENT_URL="http://localhost:${TI_DEPLOYMENT_PORT}"

#Install requirements
python3 -m pip install -r requirements.txt
python3 -m pip install docker-compose docker jq ansible --user
export PATH=/home/jenkins/.local/bin:$PATH
echo $PATH

set -e
# Pull Winery
docker-compose pull
# Clone Particles
git clone --single-branch --branch "${PARTICLES_BRANCH}" "${PARTICLES_URL}" "${PARTICLES_DIR}" 
chmod -R a+rwx "${PARTICLES_DIR}"
# Start Winery
docker-compose up -d
# Start CTT server
mkdir ${CTT_VOLUME} 
# Remove docker 'RadonCTT' from previous build
docker rm -f ${CTT_DOCKER_NAME} || true

# Pull latest docker 'RadonCTT' image
docker pull radonconsortium/radon-ctt:latest
docker run --name "${CTT_DOCKER_NAME}" -d -p "127.0.0.1:${CTT_EXT_PORT}:${CTT_PORT}" -v /var/run/docker.sock:/var/run/docker.sock -v "${CTT_VOLUME}:${WORKSPACE}/RadonCTT" "${CTT_SERVER_DOCKER}:${CTT_SERVER_DOCKER_TAG}"
  
# clone REPO_DEMO (PRQ_pipeline_demo)
git clone --single-branch --branch "${REPO_DEMO_BRANCH}" "${REPO_DEMO_URL}" "${REPO_DEMO_DIR}"

# Obtain SUT CSAR
curl -H "Accept: application/xml" -o "${SUT_CSAR}" "${SUT_EXPORT_URL}"
echo "${SUT_CSAR} available at: `curl -F "file=@${SUT_CSAR}" "https://file.io/?expires=1w" | jq -e ".link" `"

# Obtain TI CSAR
curl -H 'Accept: application/xml' -o "${TI_CSAR}" "${TI_EXPORT_URL}"
echo "${TI_CSAR} available at: `curl -F "file=@${TI_CSAR}" "https://file.io/?expires=1w" | jq -e '.link' `"

# Shutdown Winery
docker-compose rm -fsv

# CTT: Create Project
export CTT_PROJECT_UUID=$(./curl_uuid.sh "${CTT_ENDPOINT}/project"  "{\"name\":\"REPO_DEMO\",\"repository_url\":\"${REPO_DEMO_URL}\"}")
echo "CTT_PROJECT_UUID: ${CTT_PROJECT_UUID}"

# Copy CSARs into project
mkdir -p ${CTT_VOLUME}/project/${CTT_PROJECT_UUID}/radon-ctt
cp "${SUT_CSAR}" "${TI_CSAR}" "${CTT_VOLUME}/project/${CTT_PROJECT_UUID}/radon-ctt" #copy the 2 downloaded test csars from workspace to project dir
echo "ls  ${CTT_VOLUME}/project/${CTT_PROJECT_UUID}/radon-ctt ..............."
ls ${CTT_VOLUME}/project/${CTT_PROJECT_UUID}/radon-ctt
pwd
echo "ls $pwd"
ls 

# CTT: Create Test-Artifact
export CTT_TESTARTIFACT_UUID=$(./curl_uuid.sh  "${CTT_ENDPOINT}/testartifact"  "{\"project_uuid\":\"${CTT_PROJECT_UUID}\",\"sut_tosca_path\":\"radon-ctt/${SUT_CSAR_FN}\",\"ti_tosca_path\":\"radon-ctt/${TI_CSAR_FN}\"}")
#export CTT_TESTARTIFACT_UUID=$(./curl_uuid.sh  "${CTT_ENDPOINT}/testartifact"  "{\"project_uuid\":\"${CTT_PROJECT_UUID}\",\"sut_tosca_path\":\"${CTT_VOLUME}/project/${CTT_PROJECT_UUID}/radon-ctt/${SUT_CSAR_FN}\",\"ti_tosca_path\":\"${CTT_VOLUME}/project/${CTT_PROJECT_UUID}/radon-ctt/${TI_CSAR_FN}\"}")
echo "CTT_TESTARTIFACT_UUID: ${CTT_TESTARTIFACT_UUID}"

# CTT: Create Deployment
export CTT_DEPLOYMENT_UUID=$(./curl_uuid.sh  "${CTT_ENDPOINT}/deployment" "{\"testartifact_uuid\":\"${CTT_TESTARTIFACT_UUID}\"}")

# Give deployments some time to succeed.
sleep 60
echo "CTT_DEPLOYMENT_UUID: ${CTT_DEPLOYMENT_UUID}"

# Check SUT Deployment
export SUT_DEPLOYMENT_HTTP=$(curl -o /dev/null -s -w "%{http_code}" "${SUT_DEPLOYMENT_URL}")
export TI_DEPLOYMENT_HTTP=$(curl -o /dev/null -s -w "%{http_code}" "${TI_DEPLOYMENT_URL}")
echo HTTP Codes: SUT ${SUT_DEPLOYMENT_HTTP}, TI ${TI_DEPLOYMENT_HTTP}

# CTT: Trigger Execution
export CTT_EXECUTION_UUID=$(./curl_uuid.sh "${CTT_ENDPOINT}/execution" "{\"deployment_uuid\":\"${CTT_DEPLOYMENT_UUID}\"}")
echo "CTT_EXECUTION_UUID: ${CTT_EXECUTION_UUID}"
sleep 30

# CTT: Create Result
export CTT_RESULT_UUID=$(./curl_uuid.sh "${CTT_ENDPOINT}/result" "{\"execution_uuid\":\"${CTT_EXECUTION_UUID}\"}")
echo "CTT_RESULT_UUID: ${CTT_RESULT_UUID}"

# CTT: Obtain Result
wget "${CTT_ENDPOINT}/result/${CTT_RESULT_UUID}/download" -O "${CTT_RESULT_FILE}" 
echo "CTT result file available at: `curl -F "file=@${CTT_RESULT_FILE}" "https://file.io/?expires=1w" | jq -e ".link" `"
unzip -q "${CTT_RESULT_FILE}" -d result
ls -al result
set +e

docker logs "${CTT_DOCKER_NAME}" | tee ctt_docker.log
echo "CTT logs available at: `curl -F "file=@ctt_docker.log" "https://file.io/?expires=1w" | jq -e ".link" `"
