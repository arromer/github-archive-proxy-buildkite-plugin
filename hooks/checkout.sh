#!/usr/bin/env bash

set -euo pipefail

# Checks if an env var is set
# Arguments:
# $1: var name
check_set() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "ERROR: ${name} not set"
    exit 1
  fi
}

print_secret() {
  aws secretsmanager get-secret-value \
    --secret "$1" \
    --query "SecretString" --output text
}

# Prints org/repo from a github url string
# e.g. for git@github.com:org/repo.git prints org/repo
print_org_repo() {
  echo "${BUILDKITE_REPO##*@github.com?}" | awk -F[.] '{print $1}'
}

main() {
  check_set BUILDKITE_PLUGIN_GITHUB_ARCHIVE_PROXY_TOKEN_SECRET
  check_set BUILDKITE_PLUGIN_GITHUB_ARCHIVE_PROXY_PROXY_URL
  check_set BUILDKITE_COMMIT
  check_set BUILDKITE_BUILD_CHECKOUT_PATH
  check_set BUILDKITE_REPO

  cd "${BUILDKITE_BUILD_CHECKOUT_PATH}/.."

  local github_api_token
  github_api_token=$(print_secret "${BUILDKITE_PLUGIN_GITHUB_ARCHIVE_PROXY_TOKEN_SECRET}")

  local repo_file
  repo_file="${PWD}/${BUILDKITE_COMMIT}.zip"

  local org_repo
  org_repo=$(print_org_repo)

  curl -H "Authorization: token ${GITHUB_API_TOKEN}" \
    -H "Accept: application/json" \
    "http://${BUILDKITE_PLUGIN_GITHUB_ARCHIVE_PROXY_PROXY_URL}/repos/${org_repo}/tarball/${BUILDKITE_COMMIT}" \
    --output "${repo_file}"

  tar -zxf "${repo_file}"
  rm "${repo_file}"

  rm -rf "${BUILDKITE_BUILD_CHECKOUT_PATH}"

  # directory will have the form repo-org-commit, move it to BUILDKITE_BUILD_CHECKOUT_PATH
  mv "${org_repo//\//-}-${BUILDKITE_COMMIT}" "${BUILDKITE_BUILD_CHECKOUT_PATH}"

  cd "${BUILDKITE_BUILD_CHECKOUT_PATH}"
}

main "$@"
