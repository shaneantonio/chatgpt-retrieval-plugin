FROM python:3.10

WORKDIR /code

RUN pip install --no-cache-dir --upgrade -qU datasets pandas tqdm

RUN curl -X GET "https://datasets-server.huggingface.co/first-rows?dataset=squad&config=plain_text&split=train" > squad

COPY . /code/

CMD ["python", "upsert.py"]
