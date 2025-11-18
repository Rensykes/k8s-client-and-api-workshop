package io.bytebakehouse.train.company.orchestrator.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "ticket_refunds")
@Getter
@Setter
@NoArgsConstructor
public class TicketRefund {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ticket_id", nullable = false)
    private Ticket ticket;

    @Column(name = "refunded_amount", nullable = false)
    private BigDecimal refundedAmount;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(length = 3)
    private String currency = "EUR";

    @Column(name = "processed_at", nullable = false)
    private OffsetDateTime processedAt;

    private String reason;

    @PrePersist
    protected void applyProcessedAt() {
        if (processedAt == null) {
            processedAt = OffsetDateTime.now();
        }
    }
}
