package io.bytebakehouse.train.company.orchestrator.repository;

import io.bytebakehouse.train.company.orchestrator.entity.PodRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PodRecordRepository extends JpaRepository<PodRecord, Long> {
}