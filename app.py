from flask import Flask, jsonify, Response
import os, time, random
import psycopg2
from prometheus_client import Counter, generate_latest

app = Flask(__name__)
FAULT_MODE = os.environ.get("FAULT_MODE", "off")

REQUEST_COUNT = Counter('app_requests_total', 'Total requests')
ERROR_COUNT = Counter('app_errors_total', 'Total errors')

leak_storage = []

def get_db_connection():
    return psycopg2.connect(
        host="demo-db-postgresql.demo.svc.cluster.local",
        database="demodb",
        user="postgres",
        password="demo123",
        connect_timeout=3
    )

@app.route("/health")
def health():
    return jsonify(status="ok"), 200

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype="text/plain")

@app.route("/")
def index():
    REQUEST_COUNT.inc()

    if FAULT_MODE == "latency":
        time.sleep(random.uniform(3, 6))

    elif FAULT_MODE == "errors":
        if random.random() < 0.4:
            ERROR_COUNT.inc()
            return jsonify(error="internal error"), 500

    elif FAULT_MODE == "memory_leak":
        leak_storage.append("x" * 10_000_000)  # ~10MB per request, never freed

    elif FAULT_MODE == "crash_loop":
        if random.random() < 0.1:
            os._exit(1)

    elif FAULT_MODE == "downstream_db_slow":
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("SELECT pg_sleep(3);")  # artificial slow query
            cur.fetchall()
            conn.close()
        except Exception as e:
            ERROR_COUNT.inc()
            return jsonify(error=f"db error: {str(e)}"), 500

    else:
        # clean path still hits the DB, just fast
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("SELECT 1;")
            cur.fetchall()
            conn.close()
        except Exception as e:
            ERROR_COUNT.inc()
            return jsonify(error=f"db error: {str(e)}"), 500

    return jsonify(message="v1 response", fault_mode=FAULT_MODE), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)