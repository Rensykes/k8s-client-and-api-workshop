package io.bytebakehouse.train.company.orchestrator.service;

import io.kubernetes.client.openapi.ApiClient;
import io.kubernetes.client.openapi.Configuration;
import io.kubernetes.client.openapi.apis.BatchV1Api;
import io.kubernetes.client.openapi.models.V1Container;
import io.kubernetes.client.openapi.models.V1Job;
import io.kubernetes.client.openapi.models.V1JobSpec;
import io.kubernetes.client.openapi.models.V1ObjectMeta;
import io.kubernetes.client.openapi.models.V1PodSpec;
import io.kubernetes.client.openapi.models.V1PodTemplateSpec;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.Arrays;

@Service
public class JobService {

    private final BatchV1Api batchV1Api;
    private final String namespace = "train-orchestrator";

    public JobService() throws IOException {
        ApiClient client = Configuration.getDefaultApiClient();
        if (client == null) {
            client = io.kubernetes.client.util.Config.defaultClient();
            Configuration.setDefaultApiClient(client);
        }
        this.batchV1Api = new BatchV1Api();
    }

    public V1Job triggerSleepJob(int seconds) throws Exception {
        String name = "sleep-job-" + System.currentTimeMillis() % 100000;

        V1Container container = new V1Container()
                .name("sleep")
                .image("busybox:1.36")
                .command(Arrays.asList("sh", "-c", "sleep " + seconds));

        V1PodSpec podSpec = new V1PodSpec()
                .containers(Arrays.asList(container))
                .restartPolicy("Never");

        V1PodTemplateSpec template = new V1PodTemplateSpec()
                .metadata(new V1ObjectMeta())
                .spec(podSpec);

        V1JobSpec jobSpec = new V1JobSpec()
                .template(template)
                .backoffLimit(0)
                .activeDeadlineSeconds((long) seconds);

        V1Job job = new V1Job()
                .apiVersion("batch/v1")
                .kind("Job")
                .metadata(new V1ObjectMeta().name(name))
                .spec(jobSpec);

                // Create the Job in the namespace (request builder -> execute to perform call)
                return batchV1Api.createNamespacedJob(namespace, job).execute();
    }
}
