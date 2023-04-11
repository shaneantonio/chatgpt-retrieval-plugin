# curl -G localhost:8080 --data-urlencode "query=To whom did the Virgin Mary allegedly appear in 1858 in Lourdes France?" 

import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
from requests.adapters import HTTPAdapter, Retry
import requests

HOST_NAME = "localhost"
SERVER_PORT = 8080

BEARER_TOKEN = os.environ.get("BEARER_TOKEN") or "BEARER_TOKEN_HERE"
headers = {
    "Authorization": f"Bearer {BEARER_TOKEN}"
}

endpoint_url = os.environ.get("ENDPOINT_URL")
# we setup a retry strategy to retry on 5xx errors
retries = Retry(
    total=0,  # number of retries before raising error
    backoff_factor=0.1,
    status_forcelist=[500, 502, 503, 504]
)
s = requests.Session()
s.mount('https://', HTTPAdapter(max_retries=retries))

class MyServer(BaseHTTPRequestHandler):
    def query(self):
        query_components = parse_qs(urlparse(self.path).query)
        queries = [{'query': query_components["query"][0]}]

        print(queries)

        res = requests.post(
            f"{endpoint_url}/query",
            headers=headers,
            json={
                'queries': queries
            }
        )
        print(res)

        response = "res"

        for query_result in res.json()['results']:
            query = query_result['query']
            answers = []
            scores = []
            for result in query_result['results']:
                answers.append(result['text'])
                scores.append(round(result['score'], 2))
            response += "-"*70+"\n"+query+"\n\n"+"\n".join([f"{s}: {a}" for a, s in zip(answers, scores)])+"\n"+"-"*70+"\n\n"

        return response

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(bytes("<html><head><title>Upsert Query</title></head>", "utf-8"))
        self.wfile.write(bytes(f"<p>Request: {self.path}</p>", "utf-8"))
        self.wfile.write(bytes("<body>", "utf-8"))
        self.wfile.write(bytes("<p>x" + self.query() + "</p>", "utf-8"))
        self.wfile.write(bytes("</body></html>", "utf-8"))


if __name__ == "__main__":
    webServer = HTTPServer((HOST_NAME, SERVER_PORT), MyServer)
    print(f"Server started http://{HOST_NAME}:{SERVER_PORT}")

    try:
        webServer.serve_forever()
    except KeyboardInterrupt:
        pass

    webServer.server_close()
    print("Server stopped.")
