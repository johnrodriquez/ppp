#!/bin/bash

# Based off https://github.com/kind-ci/examples

# standard bash error handling
set -o errexit;
set -o pipefail;
set -o nounset;
# debug commands
set -x;

# cleanup on exit (useful for running locally)
cleanup() {
    kind delete cluster || true
}
trap cleanup EXIT

install_tekton() {
# Sample command, replace with your own command.
  kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
  kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
  kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
  kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/tekton-dashboard-release.yaml    
}

install_local() {
  goenvroot=$(go env GOROOT)
  export GOROOT=${goenvroot}
  export KO_DOCKER_REPO=kind.local
  # TODO: stuff it in image
  OS=Linux VERSION=0.8.3 ARCH=x86_64
  curl -L https://github.com/google/ko/releases/download/v${VERSION}/ko_${VERSION}_${OS}_${ARCH}.tar.gz | tar xzf - ko -C /usr/local/bin
  sleep 100000
  /usr/local/bin/ko resolve -f /workspaces/source/config    
}

main() {
  kind create cluster

  install_tekton
  install_local
}

config() {
  configdir=${1:-""}
  [[ -z ${configdir} ]] && return
  if [[ -d ${configdir} && -e ${configdir}/.dockerconfigjson ]];then
    rm -rf /root/.docker && mkdir -p /root/.docker
    cp -v ${configdir}/.dockerconfigjson /root/.docker/config.json
    chmod 0600 /root/.docker/config.json
  fi
}

config "$@"
main
