FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    curl \
    cron \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN dos2unix /app/bookcourt.sh /app/entrypoint.sh && \
    chmod +x /app/bookcourt.sh /app/entrypoint.sh

# Create an empty data file so the app starts cleanly if no volume is mounted
RUN touch /app/padelito.data

EXPOSE 80

ENTRYPOINT ["/app/entrypoint.sh"]
