# Run server locally
. np.env
export each variable in np.env
sh -c "uvicorn server.main:app --host 0.0.0.0 --port 8080"

# Docker build
docker build -t server .

# Run in docker
docker run --env-file np.env -p 8080 server


# URLs
https://app.pinecone.io/organizations/-NS91kCwTna3apApFzdN/projects/us-east4-gcp:1f1089d/indexes/first-index