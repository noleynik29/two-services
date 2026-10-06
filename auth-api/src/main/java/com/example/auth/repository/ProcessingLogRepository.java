package com.example.auth.repository;

import java.util.UUID;
import com.example.auth.entity.ProcessingLog;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProcessingLogRepository extends JpaRepository<ProcessingLog, UUID> {}
