package io.bytebakehouse.train.company.orchestrator.repository;

import io.bytebakehouse.train.company.orchestrator.entity.TicketRefund;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface TicketRefundRepository extends JpaRepository<TicketRefund, UUID> {
    List<TicketRefund> findByTicketId(UUID ticketId);
}
