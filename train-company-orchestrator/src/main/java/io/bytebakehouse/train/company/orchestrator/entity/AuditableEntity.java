package io.bytebakehouse.train.company.orchestrator.entity;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.PrePersist;
import java.time.OffsetDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * Simple base class that ensures createdAt is always populated before insert.
 */
@Getter
@Setter
@MappedSuperclass
public abstract class AuditableEntity {

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void handleCreationTimestamp() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
    }
}
