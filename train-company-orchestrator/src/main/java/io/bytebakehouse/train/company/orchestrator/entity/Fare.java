package io.bytebakehouse.train.company.orchestrator.entity;

import io.bytebakehouse.train.company.orchestrator.entity.enums.FareRefundPolicy;
import io.bytebakehouse.train.company.orchestrator.entity.enums.SeatClass;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
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
@Table(name = "fares")
@Getter
@Setter
@NoArgsConstructor
public class Fare extends AuditableEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, unique = true)
    private String code;

    private String name;

    private String description;

    @Column(nullable = false)
    private BigDecimal price;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(length = 3)
    private String currency = "EUR";

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "seat_class", columnDefinition = "seat_class")
    private SeatClass seatClass;

    private Boolean refundable = Boolean.FALSE;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "refund_policy", columnDefinition = "fare_refund_policy")
    private FareRefundPolicy refundPolicy = FareRefundPolicy.non_refundable;
    //TODO: Replace with local datetime
    @Column(name = "valid_from")
    private OffsetDateTime validFrom;

    @Column(name = "valid_until")
    private OffsetDateTime validUntil;
}
