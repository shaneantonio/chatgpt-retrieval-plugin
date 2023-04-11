#!/bin/bash
python -m http.server 8080 &
python upsert.py
echo entrypoint.sh complete