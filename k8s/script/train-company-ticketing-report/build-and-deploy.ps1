#!/usr/bin/env pwsh

# Build and deploy the ticketing report container image

Write-Host "Building ticketing report Docker image..." -ForegroundColor Cyan

# Build the Docker image
docker build -t train-company-ticketing-report:latest ./train-company-ticketing-report

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Docker image built successfully!" -ForegroundColor Green

# Optional: Tag for registry (uncomment and modify for your registry)
# docker tag train-company-ticketing-report:latest your-registry/train-company-ticketing-report:latest
# docker push your-registry/train-company-ticketing-report:latest

Write-Host @"

Next steps:
1. If using a remote registry, tag and push the image:
   docker tag train-company-ticketing-report:latest your-registry/train-company-ticketing-report:latest
   docker push your-registry/train-company-ticketing-report:latest

2. Update k8s/ticketing-report-job.yaml with your registry URL if needed

3. Create the Kubernetes Job:
   kubectl apply -f k8s/ticketing-report-job.yaml

4. Check job status:
   kubectl get jobs -n train-orchestrator
   kubectl logs -n train-orchestrator job/ticketing-report-job

5. For scheduled reports, the CronJob is also included in the manifest
"@ -ForegroundColor Yellow
