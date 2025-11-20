package io.bytebakehouse.train.company.orchestrator.service;

import com.fasterxml.jackson.annotation.JsonFormat;
import io.kubernetes.client.openapi.ApiClient;
import io.kubernetes.client.openapi.ApiException;
import io.kubernetes.client.openapi.apis.BatchV1Api;
import io.kubernetes.client.openapi.models.V1Job;
import io.kubernetes.client.openapi.models.V1JobList;
import io.kubernetes.client.util.Config;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Service to monitor Kubernetes job status and push updates via WebSocket
 */
@Service
@Slf4j
public class JobStatusService {

    private final SimpMessagingTemplate messagingTemplate;
    private final BatchV1Api batchV1Api;
    private final String namespace;
    
    // Track jobs we're monitoring
    private final Map<String, JobStatus> monitoredJobs = new ConcurrentHashMap<>();

    public JobStatusService(
            SimpMessagingTemplate messagingTemplate,
            @Value("${kubernetes.namespace:train-orchestrator}") String namespace) throws Exception {
        this.messagingTemplate = messagingTemplate;
        this.namespace = namespace;
        
        // Initialize Kubernetes client
        ApiClient client = Config.defaultClient();
        this.batchV1Api = new BatchV1Api(client);
    }

    /**
     * Start monitoring a job
     */
    public void startMonitoring(String jobName) {
        log.info("Starting to monitor job: {}", jobName);
        JobStatus status = new JobStatus();
        status.setJobName(jobName);
        status.setNamespace(namespace);
        status.setStatus("Active");
        status.setMonitoring(true);
        monitoredJobs.put(jobName, status);
        
        // Send initial status
        broadcastJobStatus(status);
    }

    /**
     * Poll Kubernetes for job status updates every 2 seconds
     */
    @Scheduled(fixedRate = 2000)
    public void pollJobStatus() {
        if (monitoredJobs.isEmpty()) {
            return;
        }

        List<String> completedJobs = new ArrayList<>();
        
        for (Map.Entry<String, JobStatus> entry : monitoredJobs.entrySet()) {
            String jobName = entry.getKey();
            JobStatus currentStatus = entry.getValue();
            
            try {
                V1Job job = batchV1Api.readNamespacedJobStatus(jobName, namespace).execute();
                JobStatus newStatus = mapJobStatus(job);
                
                // Always update and broadcast to ensure latest state
                boolean statusChanged = !Objects.equals(currentStatus.getStatus(), newStatus.getStatus()) ||
                    !Objects.equals(currentStatus.getActive(), newStatus.getActive()) ||
                    !Objects.equals(currentStatus.getSucceeded(), newStatus.getSucceeded()) ||
                    !Objects.equals(currentStatus.getFailed(), newStatus.getFailed()) ||
                    !Objects.equals(currentStatus.getCompletionTime(), newStatus.getCompletionTime());
                
                if (statusChanged) {
                    log.info("Job {} status changed: {} (Active: {}, Succeeded: {}, Failed: {})", 
                        jobName, newStatus.getStatus(), newStatus.getActive(), 
                        newStatus.getSucceeded(), newStatus.getFailed());
                    
                    // Update stored status
                    monitoredJobs.put(jobName, newStatus);
                    
                    // Broadcast immediately
                    broadcastJobStatus(newStatus);
                }
                
                // Check if job completed and mark for delayed removal
                if (("Succeeded".equals(newStatus.getStatus()) || "Failed".equals(newStatus.getStatus())) 
                    && currentStatus.isMonitoring()) {
                    // Mark as no longer actively monitoring but keep in map for 30s
                    completedJobs.add(jobName);
                }
                
            } catch (ApiException e) {
                if (e.getCode() == 404) {
                    log.warn("Job {} not found, removing from monitoring", jobName);
                    completedJobs.add(jobName);
                } else {
                    log.error("Error polling job status for {}: {}", jobName, e.getMessage());
                }
            }
        }
        
        // Handle completed jobs - stop active monitoring but keep broadcasting for 30s
        for (String jobName : completedJobs) {
            JobStatus status = monitoredJobs.get(jobName);
            if (status != null && status.isMonitoring()) {
                status.setMonitoring(false);
                log.info("Job {} completed with status: {}. Will continue broadcasting for 30s.", 
                    jobName, status.getStatus());
                
                // Broadcast the completion status
                broadcastJobStatus(status);
                
                // Schedule removal after 30 seconds
                final JobStatus finalStatus = status;
                new Timer().schedule(new TimerTask() {
                    @Override
                    public void run() {
                        monitoredJobs.remove(jobName);
                        log.info("Stopped monitoring job: {} (final status: {})", jobName, finalStatus.getStatus());
                    }
                }, 30000);
            }
        }
    }

    /**
     * Get all jobs in the namespace
     */
    public List<JobStatus> getAllJobs() {
        List<JobStatus> jobs = new ArrayList<>();
        try {
            V1JobList jobList = batchV1Api.listNamespacedJob(namespace).execute();
            for (V1Job job : jobList.getItems()) {
                // Filter for ticketing report jobs
                if (job.getMetadata() != null && 
                    job.getMetadata().getName() != null &&
                    job.getMetadata().getName().startsWith("ticketing-report")) {
                    jobs.add(mapJobStatus(job));
                }
            }
        } catch (ApiException e) {
            log.error("Error listing jobs: {}", e.getMessage());
        }
        return jobs;
    }

    /**
     * Map Kubernetes V1Job to JobStatus DTO
     */
    private JobStatus mapJobStatus(V1Job job) {
        JobStatus status = new JobStatus();
        status.setJobName(job.getMetadata().getName());
        status.setNamespace(job.getMetadata().getNamespace());
        status.setCreationTimestamp(job.getMetadata().getCreationTimestamp());
        
        if (job.getStatus() != null) {
            status.setActive(job.getStatus().getActive() != null ? job.getStatus().getActive() : 0);
            status.setSucceeded(job.getStatus().getSucceeded() != null ? job.getStatus().getSucceeded() : 0);
            status.setFailed(job.getStatus().getFailed() != null ? job.getStatus().getFailed() : 0);
            status.setCompletionTime(job.getStatus().getCompletionTime());
            status.setStartTime(job.getStatus().getStartTime());
            
            // Determine overall status
            if (status.getSucceeded() > 0) {
                status.setStatus("Succeeded");
            } else if (status.getFailed() > 0) {
                status.setStatus("Failed");
            } else if (status.getActive() > 0) {
                status.setStatus("Running");
            } else {
                status.setStatus("Pending");
            }
        }
        
        // Extract date range from labels if available
        if (job.getMetadata().getLabels() != null) {
            status.setStartDate(job.getMetadata().getLabels().get("start-date"));
            status.setEndDate(job.getMetadata().getLabels().get("end-date"));
        }
        
        status.setMonitoring(monitoredJobs.containsKey(status.getJobName()));
        return status;
    }

    /**
     * Broadcast job status to WebSocket subscribers
     */
    private void broadcastJobStatus(JobStatus status) {
        try {
            messagingTemplate.convertAndSend("/topic/job-status", status);
            log.debug("Broadcast job status: {} - {}", status.getJobName(), status.getStatus());
        } catch (Exception e) {
            log.error("Error broadcasting job status for {}: {}", status.getJobName(), e.getMessage());
        }
    }

    /**
     * DTO for job status
     */
    @Data
    public static class JobStatus {
        private String jobName;
        private String namespace;
        private String status;
        private Integer active;
        private Integer succeeded;
        private Integer failed;
        
        @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss'Z'")
        private OffsetDateTime creationTimestamp;
        
        @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss'Z'")
        private OffsetDateTime startTime;
        
        @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss'Z'")
        private OffsetDateTime completionTime;
        
        private String startDate;
        private String endDate;
        private boolean monitoring;
        
        // Calculated fields
        public long getDurationSeconds() {
            if (startTime == null) return 0;
            OffsetDateTime endTime = completionTime != null ? completionTime : OffsetDateTime.now();
            return java.time.Duration.between(startTime, endTime).getSeconds();
        }
    }
}
