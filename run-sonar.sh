#!/usr/bin/env bash
set -e

# Prompt for URL and Token if not set
if [ -z "$SONAR_HOST_URL" ]; then
  read -rp "Enter SonarQube Host URL (e.g. https://sonar.example.com): " SONAR_HOST_URL
fi

if [ -z "$SONAR_TOKEN" ]; then
  read -rsp "Enter SonarQube Token: " SONAR_TOKEN
  echo ""
fi

BRANCH_NAME="devops"

echo "========================================================"
echo " Starting SonarQube baseline scan for branch: ${BRANCH_NAME}"
echo "========================================================"

# Check if sonar-scanner CLI is installed locally, otherwise use Docker
if command -v sonar-scanner &> /dev/null; then
  echo "Using local sonar-scanner CLI..."

  echo "--> Scanning DEV..."
  sonar-scanner \
    -Dsonar.host.url="${SONAR_HOST_URL}" \
    -Dsonar.token="${SONAR_TOKEN}" \
    -Dproject.settings=sonar-project-dev.properties \
    -Dsonar.branch.name="${BRANCH_NAME}"

  echo "--> Scanning PROD..."
  sonar-scanner \
    -Dsonar.host.url="${SONAR_HOST_URL}" \
    -Dsonar.token="${SONAR_TOKEN}" \
    -Dproject.settings=sonar-project-prod.properties \
    -Dsonar.branch.name="${BRANCH_NAME}"

else
  echo "sonar-scanner CLI not found, using Docker container..."

  echo "--> Scanning DEV..."
  docker run --rm \
    -e SONAR_HOST_URL="${SONAR_HOST_URL}" \
    -e SONAR_TOKEN="${SONAR_TOKEN}" \
    -v "$(pwd):/usr/src" \
    sonarsource/sonar-scanner-cli:latest \
    -Dproject.settings=sonar-project-dev.properties \
    -Dsonar.branch.name="${BRANCH_NAME}"

  echo "--> Scanning PROD..."
  docker run --rm \
    -e SONAR_HOST_URL="${SONAR_HOST_URL}" \
    -e SONAR_TOKEN="${SONAR_TOKEN}" \
    -v "$(pwd):/usr/src" \
    sonarsource/sonar-scanner-cli:latest \
    -Dproject.settings=sonar-project-prod.properties \
    -Dsonar.branch.name="${BRANCH_NAME}"
fi

echo "========================================================"
echo " Baseline scans completed successfully!"
echo "========================================================"
