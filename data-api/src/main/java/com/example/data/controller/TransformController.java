package com.example.data.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class TransformController {

    public record TransformRequest(@NotNull String text) {}

    @PostMapping("/transform")
    public Map<String, String> transform(@Valid @RequestBody TransformRequest req) {
        String result = new StringBuilder(req.text()).reverse().toString().toUpperCase();
        return Map.of("result", result);
    }
}
