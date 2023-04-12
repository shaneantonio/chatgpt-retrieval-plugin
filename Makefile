ENV=np
WORKSPACE = /workspaces/chatgpt-retrieval-plugin
IMAGE = chatgpt-retrieval-plugin
PROJECT = shane-${ENV}
GCR = asia.gcr.io/${PROJECT}
REGION = australia-southeast1
GIT_HOME = ~/git
GIT_REPO = https://github.com/shaneantonio/chatgpt-retrieval-plugin.git
GCLOUD = /workspaces/bin/google-cloud-sdk/bin/gcloud

include ${WORKSPACE}/${ENV}.env

login:
	${GCLOUD} auth login
	${GCLOUD} config set project ${PROJECT}


once-off: login
    #gcloud services enable containerregistry.googleapis.com
	${GCLOUD} services enable run.googleapis.com
	curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-425.0.0-linux-x86_64.tar.gz


clone:
	mkdir -p ${GIT_HOME}
	cd ${GIT_HOME}
	git clone $GIT_REPO
	. ${GIT_HOME}/chatgpt-retrieval-plugin/gcp.profile


git-pull:
	cd ${GIT_HOME}/chatgpt-retrieval-plugin
	git pull
	. ${GIT_HOME}/chatgpt-retrieval-plugin/gcp.profile


build:
	cd ${WORKSPACE}
	docker buildx build --platform linux/amd64 -t ${IMAGE} .


docker-auth:
	${GCLOUD} auth configure-docker gcr.io
	${GCLOUD} auth print-access-token | docker login -u oauth2accesstoken --password-stdin https://asia.gcr.io


push: docker-auth
	cd ${WORKSPACE}
	docker tag ${IMAGE} ${GCR}/${IMAGE}
	docker push ${GCR}/${IMAGE}


deploy_web_cloud:
	${GCLOUD} run deploy ${IMAGE} --image ${GCR}/${IMAGE} --project ${PROJECT} --region ${REGION} \
		--allow-unauthenticated \
		--memory 1024Mi -q \
		--set-env-vars BEARER_TOKEN=${BEARER_TOKEN} \
		--set-env-vars OPENAI_API_KEY=${OPENAI_API_KEY} \
		--set-env-vars DATASTORE=${DATASTORE} \
		--set-env-vars PINECONE_API_KEY=${PINECONE_API_KEY} \
		--set-env-vars PINECONE_ENVIRONMENT=${PINECONE_ENVIRONMENT} \
		--set-env-vars PINECONE_INDEX=${PINECONE_INDEX}


server_bpd: build push deploy


build_push_upsert: docker-auth
	cd ${WORKSPACE}
	docker build -t upsert ./upsert
	docker tag upsert ${GCR}/upsert
	docker push ${GCR}/upsert


run_upsert_cloud: build_push_upsert
	${GCLOUD} run services delete upsert --project ${PROJECT} --region ${REGION} -q
	${GCLOUD} run deploy upsert --image ${GCR}/upsert --project ${PROJECT} --region ${REGION} \
		--no-cpu-throttling --min-instances 1 --max-instances 1 --allow-unauthenticated \
		--set-env-vars ENDPOINT_URL=${ENDPOINT_URL} \
		--set-env-vars BEARER_TOKEN=${BEARER_TOKEN}


run_server_locally:
	docker run --env-file np.env -p 8080 server


run_upsert_locally:
	cd ${WORKSPACE}/upsert && \
		export ENDPOINT_URL=${ENDPOINT_URL} && \
		export BEARER_TOKEN=${BEARER_TOKEN} && \
		sh entrypoint.sh


run_query_server_locally:
	cd ${WORKSPACE}/upsert && \
		export ENDPOINT_URL=${ENDPOINT_URL} && \
		export BEARER_TOKEN=${BEARER_TOKEN} && \
		python query_server.py
