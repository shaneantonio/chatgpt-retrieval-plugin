#pip install -qU datasets pandas tqdm

from datasets import load_dataset

data = load_dataset("squad", split="train")
print(data)

data = data.to_pandas()
print(data.head())

data = data.drop_duplicates(subset=["context"])
print(len(data))
print(data.head())

import os

BEARER_TOKEN = os.environ.get("BEARER_TOKEN") or "BEARER_TOKEN_HERE"
headers = {
    "Authorization": f"Bearer {BEARER_TOKEN}"
}

from tqdm.auto import tqdm
import requests
from requests.adapters import HTTPAdapter, Retry

batch_size = 100
endpoint_url = "http://localhost:8000"
s = requests.Session()

# we setup a retry strategy to retry on 5xx errors
retries = Retry(
    total=5,  # number of retries before raising error
    backoff_factor=0.1,
    status_forcelist=[500, 502, 503, 504]
)
s.mount('http://', HTTPAdapter(max_retries=retries))

for i in tqdm(range(0, len(documents), batch_size)):
    i_end = min(len(documents), i+batch_size)
    # make post request that allows up to 5 retries
    res = s.post(
        f"{endpoint_url}/upsert",
        headers=headers,
        json={
            "documents": documents[i:i_end]
        }
    )
    
queries = data['question'].tolist()
# format into the structure needed by the /query endpoint
queries = [{'query': queries[i]} for i in range(len(queries))]
print(len(queries))

print(queries[:3])

res = requests.post(
    "http://0.0.0.0:8000/query",
    headers=headers,
    json={
        'queries': queries[:3]
    }
)
print(res)

for query_result in res.json()['results']:
    query = query_result['query']
    answers = []
    scores = []
    for result in query_result['results']:
        answers.append(result['text'])
        scores.append(round(result['score'], 2))
    print("-"*70+"\n"+query+"\n\n"+"\n".join([f"{s}: {a}" for a, s in zip(answers, scores)])+"\n"+"-"*70+"\n\n")
