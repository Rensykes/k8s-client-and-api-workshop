#!/bin/bash

# Build and deploy the ticketing report container image

echo "Building ticketing report Docker image..."

# Build the Docker image
docker build -t train-company-ticketing-report:latest ./train-company-ticketing-report

if [ $? -ne 0 ]; then
    echo "Docker build failed!"
    exit 1
fi

echo "Docker image built successfully!"

# Optional: Tag for registry (uncomment and modify for your registry)
# docker tag train-company-ticketing-report:latest your-registry/train-company-ticketing-report:latest
# docker push your-registry/train-company-ticketing-report:latest

cat <<EOF

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
EOF
