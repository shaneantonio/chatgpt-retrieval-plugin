# curl -G localhost:8080 --data-urlencode "query=To whom did the Virgin Mary allegedly appear in 1858 in Lourdes France?" 
# curl -G https://chatgpt-retrieval-plugin-w6ee4nfjga-ts.a.run.app:8080 --data-urlencode "query=To whom did the Virgin Mary allegedly appear in 1858 in Lourdes France?" 


import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
from requests.adapters import HTTPAdapter, Retry
from tqdm.auto import tqdm
import requests

HOST_NAME = "0.0.0.0"
SERVER_PORT = 8080
BATCH_SIZE = 100
BEARER_TOKEN = os.environ.get("BEARER_TOKEN") or "BEARER_TOKEN_HERE"
endpoint_url = os.environ.get("ENDPOINT_URL")
headers = {"Authorization": f"Bearer {BEARER_TOKEN}"}
# we setup a retry strategy to retry on 5xx errors
retries = Retry(
    total=0,  # number of retries before raising error
    backoff_factor=0.1,
    status_forcelist=[500, 502, 503, 504]
)
s = requests.Session()
s.mount('https://', HTTPAdapter(max_retries=retries))

class QueryServer(BaseHTTPRequestHandler):
    """Query Server"""

    def get(self):
        if self.path.startswith("/query?"):
            return self.query() 
        elif self.path.startswith("/upsert?"):
            return self.upsert()
        return f"No mapping found for {self.path}"
         
    def query(self):
        """query"""
        query_components = parse_qs(urlparse(self.path).query)
        if len(query_components) < 1 or len(query_components["query"]) < 1:
            print("No Query")
            return "No Query"

        queries = [{'query': query_components["query"][0]}]
        print(queries)

        res = requests.post(
            f"{endpoint_url}/query",
            headers=headers,
            json={'queries': queries},
            timeout=60
        )
        print(res)

        response = ""
        for query_result in res.json()['results']:
            query = query_result['query']
            answers = []
            scores = []
            for result in query_result['results']:
                answers.append(result['text'])
                scores.append(round(result['score'], 2))
            response += "-"*70+"\n"+query+"\n\n"+"\n".join(
                    [f"{s}: {a}" for a, s in zip(answers, scores)])+"\n"+"-"*70+"\n\n"

        return response
    
    def upsert(self):
        query_components = parse_qs(urlparse(self.path).query)
        documents = [{
                'id': query_components["id"][0],
                'text': query_components["context"][0],
                'metadata': {
                    'title': query_components["title"][0]
                }
        }]
        
        print(documents)
        
        for i in tqdm(range(0, len(documents), BATCH_SIZE)):
            i_end = min(len(documents), i+BATCH_SIZE)
            # make post request that allows up to 5 retries
            res = s.post(
                f"{endpoint_url}/upsert",
                headers=headers,
                json={
                    "documents": documents[i:i_end]
                }
            )
            print (res)
        return "Success"

    def do_GET(self):
        """Do Get - Overrides inherited"""
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(bytes("<html><head><title>Upsert Query</title></head>", "utf-8"))
        self.wfile.write(bytes(f"<p>Request: {self.path}</p>", "utf-8"))
        self.wfile.write(bytes("<body>", "utf-8"))
        self.wfile.write(bytes("<p>" + self.get() + "</p>", "utf-8"))
        self.wfile.write(bytes("</body></html>", "utf-8"))


if __name__ == "__main__":
    print(f"Starting server on http://{HOST_NAME}:{SERVER_PORT}")
    webServer = HTTPServer((HOST_NAME, SERVER_PORT), QueryServer)
    print("Server started")

    try:
        webServer.serve_forever()
    except KeyboardInterrupt:
        pass

    webServer.server_close()
    print("Server stopped.")
