#!/usr/bin/env bash

IMAGE=chatgpt-retrieval-plugin
GCR=asia.gcr.io/$PROJECT_ID
REGION=australia-southeast1
GIT_HOME=~/git
GIT_REPO=https://github.com/shaneantonio/chatgpt-retrieval-plugin.git

# Once Off
onceOff() {
    #gcloud services enable containerregistry.googleapis.com
    gcloud services enable run.googleapis.com
}

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
    docker buildx build --platform linux/amd64 -t $IMAGE .
}

# Push to GCP (Google Container Registry)
push () {
    docker tag $IMAGE $GCR/$IMAGE
    docker push $GCR/$IMAGE
}

# Deploy
deploy() {
    gcloud run deploy $IMAGE --image $GCR/$IMAGE --project $PROJECT_ID --region $REGION --memory 1024Mi -q \
        --set-env-vars DATASTORE=example_datastore \
        --set-env-vars BEARER_TOKEN=example_bearer_token
}

# Build, Push and Deploy
bpd() {
    build && push && deploy
}
