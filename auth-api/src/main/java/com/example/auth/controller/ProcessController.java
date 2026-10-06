package com.example.auth.controller;

import com.example.auth.client.DataApiClient;
import com.example.auth.entity.ProcessingLog;
import com.example.auth.repository.ProcessingLogRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api")
public class ProcessController {

    public record ProcessRequest(@NotBlank String text) {}

    private final DataApiClient dataApi;
    private final ProcessingLogRepository logs;

    public ProcessController(DataApiClient dataApi, ProcessingLogRepository logs) {
        this.dataApi = dataApi;
        this.logs = logs;
    }

    @PostMapping("/process")
    public Map<String, String> process(@Valid @RequestBody ProcessRequest req, Authentication auth) {
        UUID userId = (UUID) auth.getPrincipal();
        String result = dataApi.transform(req.text());
        logs.save(new ProcessingLog(userId, req.text(), result));
        return Map.of("result", result);
    }
}
