# Python 3.11 lightweight slim base
FROM python:3.11-slim

# Prevent Python from writing .pyc files and enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000 \
    HOST=0.0.0.0 \
    WALKIE_DB_PATH=/app/data/walkie.db

WORKDIR /app

# Install backend dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy ONLY backend Python source code (no frontend assets or code)
COPY . /app/

# Create persistent storage folder for SQLite database
RUN mkdir -p /app/data

EXPOSE ${PORT}

# Health check dynamically checks whatever PORT is configured
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request, os; p = os.environ.get('PORT', '8000'); urllib.request.urlopen(f'http://localhost:{p}/health')" || exit 1

# Launch FastAPI using Uvicorn with a single worker on configured PORT
CMD ["sh", "-c", "uvicorn main:app --host ${HOST} --port ${PORT} --workers 1"]
