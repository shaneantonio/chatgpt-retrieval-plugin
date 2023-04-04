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
        --set-env-vars BEARER_TOKEN=$BEARER_TOKEN \
        --set-env-vars OPENAPI_API_KEY=$OPENAPI_API_KEY \
        --set-env-vars DATASTORE=$DATASTORE \
        --set-env-vars PINECONE_API_KEY=$PINECONE_API_KEY \
        --set-env-vars PINECONE_ENVIRONMENT=$PINECONE_ENVIRONMENT \
        --set-env-vars PINECONE_INDEX=$PINECONE_INDEX
}

upsert() {
    docker build -t upsert ./upsert
    docker tag upsert $GCR/upsert
    docker push $GCR/upsert
    gcloud beta run jobs create upsert --image $GCR/upsert --project $PROJECT_ID --region $REGION --memory 1024Mi -q \
        --set-env-vars ENDPOINT_URL=$ENDPOINT_URL
    gcloud beta run jobs execute upsert --project $PROJECT_ID --region $REGION
}

# Build, Push and Deploy
bpd() {
    build && push && deploy
}
