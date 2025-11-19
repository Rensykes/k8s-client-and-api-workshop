package io.bytebakehouse.train.company.orchestrator.service;

import io.kubernetes.client.custom.Quantity;
import io.kubernetes.client.openapi.ApiClient;
import io.kubernetes.client.openapi.Configuration;
import io.kubernetes.client.openapi.apis.BatchV1Api;
import io.kubernetes.client.openapi.models.*;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

@Service
public class TicketingReportJobService {

    private final BatchV1Api batchV1Api;
    private final String namespace = "train-orchestrator";
    private static final String IMAGE = "train-company-ticketing-report:latest";

    public TicketingReportJobService() throws IOException {
        ApiClient client = Configuration.getDefaultApiClient();
        if (client == null) {
            client = io.kubernetes.client.util.Config.defaultClient();
            Configuration.setDefaultApiClient(client);
        }
        this.batchV1Api = new BatchV1Api();
    }

    public V1Job createTicketingReportJob(LocalDate startDate, LocalDate endDate) throws Exception {
        String timestamp = String.valueOf(System.currentTimeMillis() % 100000);
        String name = "ticketing-report-" + timestamp;
        
        DateTimeFormatter formatter = DateTimeFormatter.ISO_LOCAL_DATE;
        String startDateStr = startDate.format(formatter);
        String endDateStr = endDate.format(formatter);

        // Environment variables
        V1EnvVar dbHost = new V1EnvVar().name("DB_HOST").value("postgres");
        V1EnvVar dbPort = new V1EnvVar().name("DB_PORT").value("5432");
        V1EnvVar dbName = new V1EnvVar().name("DB_NAME").value("traindb");
        
        // DB credentials from secret (if available)
        V1EnvVar dbUser = new V1EnvVar()
                .name("DB_USER")
                .valueFrom(new V1EnvVarSource()
                        .secretKeyRef(new V1SecretKeySelector()
                                .name("postgres-secret")
                                .key("username")
                                .optional(true)));
        
        V1EnvVar dbPassword = new V1EnvVar()
                .name("DB_PASSWORD")
                .valueFrom(new V1EnvVarSource()
                        .secretKeyRef(new V1SecretKeySelector()
                                .name("postgres-secret")
                                .key("password")
                                .optional(true)));

        // Container configuration
        V1Container container = new V1Container()
                .name("report-generator")
                .image(IMAGE)
                .imagePullPolicy("IfNotPresent")
                .env(Arrays.asList(dbHost, dbPort, dbName, dbUser, dbPassword))
                .args(Arrays.asList(
                        "--start-date", startDateStr,
                        "--end-date", endDateStr,
                        "--output", "/reports/ticketing-report.xlsx"
                ))
                .volumeMounts(Arrays.asList(
                        new V1VolumeMount()
                                .name("report-output")
                                .mountPath("/reports")
                ))
                .resources(new V1ResourceRequirements()
                        .requests(Map.of(
                                "memory", new Quantity("256Mi"),
                                "cpu", new Quantity("100m")
                        ))
                        .limits(Map.of(
                                "memory", new Quantity("512Mi"),
                                "cpu", new Quantity("500m")
                        ))
                );

        // Volume
        V1Volume volume = new V1Volume()
                .name("report-output")
                .emptyDir(new V1EmptyDirVolumeSource());

        // Pod specification
        V1PodSpec podSpec = new V1PodSpec()
                .containers(Arrays.asList(container))
                .volumes(Arrays.asList(volume))
                .restartPolicy("OnFailure");

        // Pod template
        V1PodTemplateSpec template = new V1PodTemplateSpec()
                .metadata(new V1ObjectMeta()
                        .labels(Map.of("app", "ticketing-report")))
                .spec(podSpec);

        // Job specification
        V1JobSpec jobSpec = new V1JobSpec()
                .template(template)
                .backoffLimit(3)
                .ttlSecondsAfterFinished(86400); // Clean up after 1 day

        // Job
        V1Job job = new V1Job()
                .apiVersion("batch/v1")
                .kind("Job")
                .metadata(new V1ObjectMeta()
                        .name(name)
                        .labels(Map.of("app", "ticketing-report")))
                .spec(jobSpec);

        // Create the Job in the namespace
        return batchV1Api.createNamespacedJob(namespace, job).execute();
    }

    public V1Job createTicketingReportJobForCurrentMonth() throws Exception {
        LocalDate today = LocalDate.now();
        LocalDate startDate = today.withDayOfMonth(1);
        LocalDate endDate = today;
        return createTicketingReportJob(startDate, endDate);
    }

    public V1Job createTicketingReportJobForPreviousMonth() throws Exception {
        LocalDate today = LocalDate.now();
        LocalDate firstDayOfCurrentMonth = today.withDayOfMonth(1);
        LocalDate lastDayOfPreviousMonth = firstDayOfCurrentMonth.minusDays(1);
        LocalDate firstDayOfPreviousMonth = lastDayOfPreviousMonth.withDayOfMonth(1);
        return createTicketingReportJob(firstDayOfPreviousMonth, lastDayOfPreviousMonth);
    }
}
