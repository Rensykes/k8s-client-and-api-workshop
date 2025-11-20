package io.bytebakehouse.train.company.orchestrator.service;

import io.kubernetes.client.Copy;
import io.kubernetes.client.Exec;
import io.kubernetes.client.openapi.ApiClient;
import io.kubernetes.client.openapi.Configuration;
import io.kubernetes.client.openapi.apis.CoreV1Api;
import io.kubernetes.client.util.Config;

import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

@Service
public class ReportStorageService {

    private final CoreV1Api coreV1Api;
    private final String namespace = "train-orchestrator";
    private static final String REPORTS_PATH = "/reports";

    public ReportStorageService() throws IOException {
        ApiClient client = Configuration.getDefaultApiClient();
        if (client == null) {
            client = Config.defaultClient();
            Configuration.setDefaultApiClient(client);
        }
        this.coreV1Api = new CoreV1Api(client);
    }

    /**
     * List all report files by finding a ticketing-report job pod
     */
    public List<String> listReportFiles() throws Exception {
        // First try to list files directly from the mounted PVC
        try {
            Path reportsDir = Path.of(REPORTS_PATH);
            if (Files.exists(reportsDir) && Files.isDirectory(reportsDir)) {
                return Files.list(reportsDir)
                        .filter(Files::isRegularFile)
                        .map(Path::getFileName)
                        .map(Path::toString)
                        .filter(name -> name.endsWith(".xlsx"))
                        .sorted()
                        .toList();
            }
        } catch (Exception e) {
            // If direct access fails, fall through to pod-based approach
        }
        
        // Fallback: Find any running or recently completed ticketing-report job pod
        String podName = findReportJobPod();
        
        if (podName == null) {
            // No pod found, return empty list
            return new ArrayList<>();
        }
        
        try {
            // Execute ls command to list files
            String output = execInPod(podName, new String[]{"ls", "-1", REPORTS_PATH});
            
            List<String> files = new ArrayList<>();
            if (output != null && !output.trim().isEmpty()) {
                for (String line : output.split("\n")) {
                    String trimmed = line.trim();
                    if (!trimmed.isEmpty() && trimmed.endsWith(".xlsx")) {
                        files.add(trimmed);
                    }
                }
            }
            return files;
        } catch (Exception e) {
            // If execution fails, return empty list
            return new ArrayList<>();
        }
    }

    /**
     * Download a specific report file using kubectl cp API
     */
    public Resource downloadReport(String filename) throws Exception {
        // Validate filename to prevent path traversal
        if (filename.contains("..") || filename.contains("/") || filename.contains("\\")) {
            throw new IllegalArgumentException("Invalid filename");
        }
        
        // First try to read directly from the mounted PVC
        try {
            Path reportFile = Path.of(REPORTS_PATH, filename);
            if (Files.exists(reportFile) && Files.isRegularFile(reportFile)) {
                byte[] content = Files.readAllBytes(reportFile);
                return new ByteArrayResource(content);
            }
        } catch (Exception e) {
            // If direct access fails, fall through to pod-based approach
        }
        
        // Fallback: Find a ticketing-report job pod
        String podName = findReportJobPod();
        
        if (podName == null) {
            throw new RuntimeException("No ticketing-report pod found. Please create a report job first.");
        }
        
        // Use Copy API to download the file (static helper methods used below)
        
        // Create temporary file to hold the download
        Path tempFile = Files.createTempFile("report-", ".xlsx");
        
        try {
            // Copy from pod to local temp file (static method)
            Copy.copyFileFromPod(namespace, podName, REPORTS_PATH + "/" + filename, tempFile);
            
            // Read the file content
            byte[] content = Files.readAllBytes(tempFile);
            
            return new ByteArrayResource(content);
        } finally {
            // Clean up temp file
            Files.deleteIfExists(tempFile);
        }
    }

    /**
     * Delete a specific report file
     */
    public boolean deleteReport(String filename) throws Exception {
        // Validate filename to prevent path traversal
        if (filename.contains("..") || filename.contains("/") || filename.contains("\\")) {
            throw new IllegalArgumentException("Invalid filename");
        }
        
        // Try to delete directly from the mounted PVC
        try {
            Path reportFile = Path.of(REPORTS_PATH, filename);
            if (Files.exists(reportFile) && Files.isRegularFile(reportFile)) {
                Files.delete(reportFile);
                return true;
            }
        } catch (Exception e) {
            // If direct access fails, fall through to pod-based approach
        }
        
        // Fallback: Find a ticketing-report job pod and exec rm command
        String podName = findReportJobPod();
        
        if (podName == null) {
            throw new RuntimeException("No ticketing-report pod found and cannot access file system directly.");
        }
        
        try {
            execInPod(podName, new String[]{"rm", "-f", REPORTS_PATH + "/" + filename});
            return true;
        } catch (Exception e) {
            throw new RuntimeException("Failed to delete report: " + e.getMessage(), e);
        }
    }

    /**
     * Find any running or completed ticketing-report job pod with PVC mounted
     */
    private String findReportJobPod() throws Exception {
        try {
            var pods = coreV1Api.listNamespacedPod(namespace)
                    .labelSelector("app=ticketing-report")
                    .execute();

            if (pods.getItems().isEmpty()) {
                return null;
            }

            // Prefer running pods, fall back to succeeded/completed ones
            for (var pod : pods.getItems()) {
                String phase = pod.getStatus() != null && pod.getStatus().getPhase() != null
                        ? pod.getStatus().getPhase()
                        : "";

                if ("Running".equals(phase) || "Succeeded".equals(phase)) {
                    return pod.getMetadata().getName();
                }
            }

            // If no running/succeeded pod, use the first one
            return pods.getItems().get(0).getMetadata().getName();
        } catch (Exception e) {
            // Some clusters add fields that the client models don't recognize (e.g. observedGeneration).
            // Fall back to calling kubectl and parsing JSON with a tolerant ObjectMapper.
            try {
                ProcessBuilder pb = new ProcessBuilder("kubectl", "get", "pods", "-n", namespace, "-l", "app=ticketing-report", "-o", "json");
                pb.redirectErrorStream(true);
                Process p = pb.start();
                java.io.InputStream is = p.getInputStream();
                String output;
                try (java.util.Scanner s = new java.util.Scanner(is).useDelimiter("\\A")) {
                    output = s.hasNext() ? s.next() : "";
                }
                p.waitFor();

                if (output.isBlank()) {
                    return null;
                }

                ObjectMapper mapper = new ObjectMapper();
                mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
                JsonNode root = mapper.readTree(output);
                JsonNode items = root.path("items");
                if (!items.isArray() || items.size() == 0) {
                    return null;
                }

                // Prefer Running or Succeeded
                for (JsonNode item : items) {
                    String phase = item.path("status").path("phase").asText("");
                    if ("Running".equals(phase) || "Succeeded".equals(phase)) {
                        return item.path("metadata").path("name").asText(null);
                    }
                }

                // Fallback to first item
                return items.get(0).path("metadata").path("name").asText(null);
            } catch (Exception ex) {
                // Give up and propagate original exception
                throw e;
            }
        }
    }

    private String execInPod(String podName, String[] command) throws Exception {
        Exec exec = new Exec();
        
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Process process = exec.exec(namespace, podName, command, false, false);
            
            // Read output
            java.io.InputStream inputStream = process.getInputStream();
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = inputStream.read(buffer)) != -1) {
                out.write(buffer, 0, bytesRead);
            }
            
            process.waitFor();
            return out.toString();
        }
    }
}
