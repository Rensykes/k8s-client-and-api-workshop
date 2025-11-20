package io.bytebakehouse.train.company.orchestrator.controller;

import io.bytebakehouse.train.company.orchestrator.service.PodListService;
import io.bytebakehouse.train.company.orchestrator.service.PodRecordService;
import io.bytebakehouse.train.company.orchestrator.service.TicketingReportJobService;
import io.bytebakehouse.train.company.orchestrator.service.ReportStorageService;
import io.bytebakehouse.train.company.orchestrator.service.JobService;
import io.bytebakehouse.train.company.orchestrator.service.JobStatusService;
import io.kubernetes.client.openapi.models.V1PodList;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.DeleteMapping;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.Map;

@RestController
@RequestMapping("/api/k8s")
public class KubeController {

    private final PodListService podListService;
    private final JobService jobService;
    private final PodRecordService podRecordService;
    private final TicketingReportJobService ticketingReportJobService;
    private final ReportStorageService reportStorageService;
    private final JobStatusService jobStatusService;

    public KubeController(PodListService podListService, 
                          JobService jobService, 
                          PodRecordService podRecordService,
                          TicketingReportJobService ticketingReportJobService,
                          ReportStorageService reportStorageService,
                          JobStatusService jobStatusService) {
        this.podListService = podListService;
        this.jobService = jobService;
        this.podRecordService = podRecordService;
        this.ticketingReportJobService = ticketingReportJobService;
        this.reportStorageService = reportStorageService;
        this.jobStatusService = jobStatusService;
    }

    @GetMapping("/pods")
    public ResponseEntity<V1PodList> listPods() {
        try {
            V1PodList pods = podListService.listAllPods();
            return ResponseEntity.ok(pods);
        } catch (Exception e) {
            return ResponseEntity.status(500).build();
        }
    }

    @GetMapping(value = "/pods/raw", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> listPodsRaw() {
        try {
            String json = podListService.listAllPodsRaw();
            return ResponseEntity.ok(json);
        } catch (Exception e) {
            return ResponseEntity.status(500).body("{}");
        }
    }

    @PostMapping("/jobs/sleep")
    public ResponseEntity<?> triggerSleepJob(@RequestParam(name = "seconds", defaultValue = "60") int seconds) {
        try {
            var job = jobService.triggerSleepJob(seconds);
            return ResponseEntity.ok(job.getMetadata());
        } catch (Exception e) {
            return ResponseEntity.status(500).body(e.getMessage());
        }
    }

    @PostMapping("/pods/record")
    public ResponseEntity<?> savePodRecord(@RequestParam String name, @RequestParam String namespace, @RequestParam String status) {
        try {
            var record = podRecordService.savePodRecord(name, namespace, status);
            return ResponseEntity.ok(record);
        } catch (Exception e) {
            return ResponseEntity.status(500).body(e.getMessage());
        }
    }

    @PostMapping("/jobs/ticketing-report")
    public ResponseEntity<?> createTicketingReport(
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate) {
        try {
            var job = (startDate != null && endDate != null)
                    ? ticketingReportJobService.createTicketingReportJob(
                            LocalDate.parse(startDate),
                            LocalDate.parse(endDate))
                    : ticketingReportJobService.createTicketingReportJobForCurrentMonth();
            
            return ResponseEntity.ok(Map.of(
                    "status", "created",
                    "jobName", job.getMetadata().getName(),
                    "namespace", job.getMetadata().getNamespace(),
                    "creationTimestamp", job.getMetadata().getCreationTimestamp()
            ));
        } catch (DateTimeParseException e) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "Invalid date format. Use YYYY-MM-DD format."));
        } catch (Exception e) {
            return ResponseEntity.status(500)
                    .body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/jobs/ticketing-report/current-month")
    public ResponseEntity<?> createTicketingReportForCurrentMonth() {
        try {
            var job = ticketingReportJobService.createTicketingReportJobForCurrentMonth();
            return ResponseEntity.ok(Map.of(
                    "status", "created",
                    "jobName", job.getMetadata().getName(),
                    "namespace", job.getMetadata().getNamespace(),
                    "creationTimestamp", job.getMetadata().getCreationTimestamp(),
                    "period", "current-month"
            ));
        } catch (Exception e) {
            return ResponseEntity.status(500)
                    .body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/jobs/ticketing-report/previous-month")
    public ResponseEntity<?> createTicketingReportForPreviousMonth() {
        try {
            var job = ticketingReportJobService.createTicketingReportJobForPreviousMonth();
            return ResponseEntity.ok(Map.of(
                    "status", "created",
                    "jobName", job.getMetadata().getName(),
                    "namespace", job.getMetadata().getNamespace(),
                    "creationTimestamp", job.getMetadata().getCreationTimestamp(),
                    "period", "previous-month"
            ));
        } catch (Exception e) {
            return ResponseEntity.status(500)
                    .body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/reports")
    public ResponseEntity<?> listReports() {
        try {
            var files = reportStorageService.listReportFiles();
            return ResponseEntity.ok(Map.of(
                    "reports", files,
                    "count", files.size()
            ));
        } catch (Exception e) {
            return ResponseEntity.status(500)
                    .body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/reports/{filename}")
    public ResponseEntity<Resource> downloadReport(@PathVariable String filename) {
        try {
            Resource resource = reportStorageService.downloadReport(filename);
            
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                    .contentType(MediaType.APPLICATION_OCTET_STREAM)
                    .body(resource);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            return ResponseEntity.status(500).build();
        }
    }

    @DeleteMapping("/reports/{filename}")
    public ResponseEntity<?> deleteReport(@PathVariable String filename) {
        try {
            boolean deleted = reportStorageService.deleteReport(filename);
            if (deleted) {
                return ResponseEntity.ok(Map.of(
                        "message", "Report deleted successfully",
                        "filename", filename
                ));
            } else {
                return ResponseEntity.status(404)
                        .body(Map.of("error", "Report not found"));
            }
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(500)
                    .body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/jobs/all")
    public ResponseEntity<?> getAllJobs() {
        try {
            var jobs = jobStatusService.getAllJobs();
            return ResponseEntity.ok(jobs);
        } catch (Exception e) {
            return ResponseEntity.status(500)
                    .body(Map.of("error", e.getMessage()));
        }
    }
}

