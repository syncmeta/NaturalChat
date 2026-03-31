FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ src/
COPY common_skills/ common_skills/
COPY prompts/ prompts/
COPY config/config.template.yaml config/config.template.yaml
COPY config/secrets.template.yaml config/secrets.template.yaml
COPY main.py manage.py ./

# Volumes for user data (mounted at runtime)
VOLUME ["/app/bots", "/app/config", "/app/workspace", "/app/logs"]

# Web panel + Feishu webhook
EXPOSE 8080 9000

CMD ["python", "main.py"]
