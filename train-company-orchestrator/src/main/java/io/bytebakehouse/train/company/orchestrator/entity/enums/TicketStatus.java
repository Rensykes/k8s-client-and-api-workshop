package io.bytebakehouse.train.company.orchestrator.entity.enums;

/**
 * Enum constants deliberately kept lowercase to match PostgreSQL enum values.
 */
public enum TicketStatus {
    reserved,
    issued,
    checked_in,
    cancelled,
    refunded
}
