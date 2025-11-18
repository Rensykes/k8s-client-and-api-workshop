FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY train_company_ticketing_report/ ./train_company_ticketing_report/
COPY main.py .

# Create output directory for reports
RUN mkdir -p /reports

# Set the default command
ENTRYPOINT ["python", "main.py"]
CMD ["--output", "/reports/ticketing-report.xlsx"]
