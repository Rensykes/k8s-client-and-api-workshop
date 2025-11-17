package io.bytebakehouse.train.company.orchestrator.service;

import io.kubernetes.client.openapi.ApiClient;
import io.kubernetes.client.openapi.Configuration;
import io.kubernetes.client.openapi.apis.CoreV1Api;
import io.kubernetes.client.openapi.models.V1PodList;
import io.kubernetes.client.util.Config;
import org.springframework.stereotype.Service;

import java.io.IOException;
import okhttp3.Call;
import okhttp3.Response;
import okhttp3.ResponseBody;
import okhttp3.Request;

@Service
public class PodListService {

    private final CoreV1Api coreV1Api;

    public PodListService() throws IOException {
        ApiClient client = Config.defaultClient();
        Configuration.setDefaultApiClient(client);
        this.coreV1Api = new CoreV1Api();
    }

    public V1PodList listAllPods() throws Exception {
        return coreV1Api.listPodForAllNamespaces().execute();
    }

    public String listAllPodsRaw() throws IOException {
        ApiClient client = Configuration.getDefaultApiClient();
        String url = client.getBasePath() + "/api/v1/pods";
        Request request = new Request.Builder().url(url).get().build();
        Call call = client.getHttpClient().newCall(request);
        Response resp = call.execute();
        ResponseBody body = resp.body();
        if (body == null) return "";
        return body.string();
    }
}
