package io.bytebakehouse.train.company.orchestrator.service;

import io.bytebakehouse.train.company.orchestrator.entity.PodRecord;
import io.bytebakehouse.train.company.orchestrator.repository.PodRecordRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class PodRecordService {

    @Autowired
    private PodRecordRepository podRecordRepository;

    public PodRecord savePodRecord(String name, String namespace, String status) {
        PodRecord record = new PodRecord(name, namespace, status);
        return podRecordRepository.save(record);
    }
}