#!/usr/bin/env bash

IMAGE=chatgpt-retrieval-plugin
GCR=asia.gcr.io/$PROJECT_ID
REGION=australia-southeast1
GIT_HOME=~/git
GIT_REPO=https://github.com/shaneantonio/chatgpt-retrieval-plugin.git

# Clone
clone() {
    mkdir -p $GIT_HOME
    cd $GIT_HOME
    git clone $GIT_REPO
    . $GIT_HOME/chatgpt-retrieval-plugin/gcp.profile
}

# Git Pull
gitPull() {
    cd $GIT_HOME/chatgpt-retrieval-plugin
    git pull
    . $GIT_HOME/chatgpt-retrieval-plugin/gcp.profile
}

# Build
build() {
    cd $GIT_HOME/chatgpt-retrieval-plugin
    docker build . -t $IMAGE
}

# Push to GCP (Google Container Registry)
push () {
    docker tag $IMAGE $GCR/$IMAGE
    docker push $GCR/$IMAGE
}

# Deploy
deploy() {
    gcloud run deploy $IMAGE --image $GCR/$IMAGE --project $PROJECT_ID --region $REGION --memory 1024Mi -q
}

# Build, Push and Deploy
bpd() {
    build && push && deploy
}
