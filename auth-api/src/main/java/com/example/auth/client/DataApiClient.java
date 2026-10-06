package com.example.auth.client;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.server.ResponseStatusException;
import java.util.Map;

@Component
public class DataApiClient {
    record TransformResponse(String result) {}

    private final RestClient client;

    public DataApiClient(@Value("${app.data-api-url}") String baseUrl,
                         @Value("${app.internal-token}") String internalToken) {
        var factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(3000);
        factory.setReadTimeout(5000);
        this.client = RestClient.builder()
                .baseUrl(baseUrl)
                .requestFactory(factory)
                .defaultHeader("X-Internal-Token", internalToken)
                .build();
    }

    public String transform(String text) {
        try {
            TransformResponse r = client.post()
                    .uri("/api/transform")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of("text", text))
                    .retrieve()
                    .body(TransformResponse.class);
            if (r == null || r.result() == null) {
                throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Empty response from data-api");
            }
            return r.result();
        } catch (RestClientException e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "data-api call failed");
        }
    }
}
