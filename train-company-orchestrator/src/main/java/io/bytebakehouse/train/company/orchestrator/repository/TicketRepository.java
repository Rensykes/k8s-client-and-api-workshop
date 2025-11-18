package io.bytebakehouse.train.company.orchestrator.repository;

import io.bytebakehouse.train.company.orchestrator.entity.Ticket;
import io.bytebakehouse.train.company.orchestrator.entity.enums.TicketStatus;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface TicketRepository extends JpaRepository<Ticket, UUID> {
    Optional<Ticket> findByTicketRef(String ticketRef);

    List<Ticket> findByTripId(UUID tripId);

    List<Ticket> findByStatus(TicketStatus status);
}
