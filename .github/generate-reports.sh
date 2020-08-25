#!/bin/bash

# Copyright 2020 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

echo "Extracting reports from sonobuoy"
SONOBUOY_REPORTS=/tmp/reports

INGRESS_CONTROLLER=${INGRESS_CONTROLLER:-'N/A'}
CONTROLLER_VERSION=${CONTROLLER_VERSION:-'N/A'}

TEMP_CONTENT=$(mktemp -d)

docker run \
  -e BUILD="$(date -u +'%Y%m%d%H%M')" \
  -e INPUT_DIRECTORY=/input \
  -e OUTPUT_DIRECTORY=/output \
  -e INGRESS_CONTROLLER="${INGRESS_CONTROLLER}" \
  -e CONTROLLER_VERSION="${CONTROLLER_VERSION}" \
  -v "${SONOBUOY_REPORTS}":/input:ro \
  -v "${TEMP_CONTENT}":/output \
  -u "$(id -u):$(id -g)" \
  aledbf/reports-builder:0.1
  # replace image with staging from gcr after https://github.com/kubernetes/test-infra/pull/18874

pushd "${TEMP_WORKTREE}" > /dev/null

# remove old content
git rm -r .

# copy new content
cp -a "${TEMP_CONTENT}/." "${TEMP_WORKTREE}/"

# cleanup HTML
for html_file in *.html;do
  tidy -q --break-before-br no --tidy-mark no --show-warnings no --wrap 0 -indent -m "$html_file" || true
done

# configure git
git config --global user.email "action@github.com"
git config --global user.name "GitHub Action"
# commit changes
git add .
git commit -m "Publish conformance test report"
git push --force --quiet > /dev/null 2>&1

popd > /dev/null
