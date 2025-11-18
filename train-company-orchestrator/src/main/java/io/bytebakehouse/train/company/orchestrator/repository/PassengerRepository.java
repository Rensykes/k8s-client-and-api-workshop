package io.bytebakehouse.train.company.orchestrator.repository;

import io.bytebakehouse.train.company.orchestrator.entity.Passenger;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PassengerRepository extends JpaRepository<Passenger, UUID> {
    List<Passenger> findByUserId(UUID userId);
}
