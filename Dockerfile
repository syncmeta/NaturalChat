FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ src/
COPY common_skills/ common_skills/
COPY main.py manage.py install.py install.sh ./
COPY *.md ./

# Volumes for user data
VOLUME ["/app/bots", "/app/workspace"]

# Feishu webhook
EXPOSE 9000

CMD ["python", "main.py"]
