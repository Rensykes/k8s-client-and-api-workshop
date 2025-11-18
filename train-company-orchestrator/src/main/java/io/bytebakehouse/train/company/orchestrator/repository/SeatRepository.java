package io.bytebakehouse.train.company.orchestrator.repository;

import io.bytebakehouse.train.company.orchestrator.entity.Seat;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SeatRepository extends JpaRepository<Seat, UUID> {
    List<Seat> findByCarriageId(UUID carriageId);

    Optional<Seat> findByCarriageIdAndSeatNumber(UUID carriageId, String seatNumber);
}
