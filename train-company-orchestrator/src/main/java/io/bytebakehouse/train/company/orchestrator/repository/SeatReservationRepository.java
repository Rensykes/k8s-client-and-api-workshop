package io.bytebakehouse.train.company.orchestrator.repository;

import io.bytebakehouse.train.company.orchestrator.entity.SeatReservation;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SeatReservationRepository extends JpaRepository<SeatReservation, UUID> {
    Optional<SeatReservation> findByTripIdAndSeatId(UUID tripId, UUID seatId);

    List<SeatReservation> findByTripId(UUID tripId);
}
