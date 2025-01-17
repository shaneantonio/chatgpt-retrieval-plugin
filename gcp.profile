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
    gcloud run deploy $IMAGE --image $GCR/$IMAGE --project $PROJECT_ID --region $REGION \
        --allow-unauthenticated \
        --memory 1024Mi -q \
        --set-env-vars BEARER_TOKEN=$BEARER_TOKEN \
        --set-env-vars OPENAI_API_KEY=$OPENAI_API_KEY \
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
        --set-env-vars ENDPOINT_URL=$ENDPOINT_URL \
        --set-env-vars BEARER_TOKEN=$BEARER_TOKEN
    gcloud beta run jobs execute upsert --project $PROJECT_ID --region $REGION
}

# Build, Push and Deploy
bpd() {
    gitPull && . gcp.profile && build && push && deploy
}

logs() {
    /workspaces/bin/google-cloud-sdk/bin/gcloud logging read --limit 100 --order desc --format "value(textPayload)" --freshness 1h '
    resource.type = "cloud_run_revision"
    resource.labels.service_name = "upsert"
    resource.labels.location = "australia-southeast1"
    severity>=DEFAULT' | tac
}

tail() {
    /workspaces/bin/google-cloud-sdk/bin/gcloud beta logging tail --format "value(textPayload)" '
    resource.type = "cloud_run_revision"
    resource.labels.service_name = "upsert"
    resource.labels.location = "australia-southeast1"
    severity>=DEFAULT'
}

set_env() {
    . np.env
    export BEARER_TOKEN
}

query() {
    set_env
    curl -H "Authorization: Bearer $BEARER_TOKEN" -G localhost:8080/query --data-urlencode "query=$1" 
}

testQuery() {
    query "whom did the Virgin Mary allegedly appear in 1858 in Lourdes France?"
}

completion() {
    set_env
    curl -H "Authorization: Bearer $BEARER_TOKEN" -G localhost:8080/completion --data-urlencode "message=$1" 
}

upsertText() {
    #  upsertText aaaa01 "Shane has 5 fingers"
    set_env
    curl -H "Authorization: Bearer $BEARER_TOKEN" -G localhost:8080/upsert --data-urlencode "id=$1" --data-urlencode "title=ShanesData" --data-urlencode "context=$2"
}