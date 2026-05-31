# Cloud Run 컨테이너 — Python 3.13 slim + gunicorn
FROM python:3.13-slim

WORKDIR /app

# 시스템 의존성 (xgboost·grpc 가 일부 native 라이브러리 요구)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# 의존성 먼저 설치 (Docker 캐시 활용)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 백엔드 코드 복사
COPY *.py ./

# XGBoost 모델 빌드 시 학습 — 이미지에 함께 포함
RUN python train_model.py

# Cloud Run 은 PORT env 주입 (기본 8080)
ENV PORT=8080

# gunicorn — 멀티 워커 (Cloud Run 단일 인스턴스 안에서 처리량 ↑)
# APScheduler 는 제거됐고 스케줄은 Cloud Scheduler 외부 호출로 대체.
CMD exec gunicorn -b :$PORT -w 2 -k gthread --threads 4 --timeout 30 wsgi:app
