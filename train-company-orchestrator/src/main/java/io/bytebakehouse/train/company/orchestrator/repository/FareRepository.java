package io.bytebakehouse.train.company.orchestrator.repository;

import io.bytebakehouse.train.company.orchestrator.entity.Fare;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface FareRepository extends JpaRepository<Fare, UUID> {
    Optional<Fare> findByCode(String code);
}
