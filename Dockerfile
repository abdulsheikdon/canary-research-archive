FROM python:3.11-slim
RUN pip install flask prometheus_client psycopg2-binary
COPY app.py .
CMD ["python", "app.py"]