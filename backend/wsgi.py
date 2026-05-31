"""gunicorn WSGI 진입점 (Cloud Run).

Dockerfile 의 CMD: `gunicorn -b :$PORT -w 2 -k gthread --threads 4 wsgi:app`
"""
from app import create_app

app = create_app()
