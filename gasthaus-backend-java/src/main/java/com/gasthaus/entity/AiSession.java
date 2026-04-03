package com.gasthaus.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Maps to the Prisma "model AiSession".
 *
 * Stores the conversation history between a customer and the AI
 * recommendation engine (FastAPI service). Each session belongs
 * to one user and holds a JSON array of message objects.
 *
 * The Prisma "messages Json" field is stored as PostgreSQL JSONB,
 * which allows indexed queries inside JSON. We use Hibernate 6's
 * native @JdbcTypeCode(SqlTypes.JSON) to handle the mapping.
 */
@Entity
@Table(name = "ai_sessions")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(of = "id")
@ToString(exclude = "user")
public class AiSession {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    /**
     * Stores the chat history as a JSONB column.
     *
     * In Hibernate 6 (Spring Boot 3.x), @JdbcTypeCode(SqlTypes.JSON)
     * tells Hibernate to serialize/deserialize this field as JSON.
     * We use String here for simplicity — the service layer will
     * parse/build the JSON string using Jackson's ObjectMapper.
     *
     * Prisma equivalent: messages Json
     * PostgreSQL column type: jsonb (binary JSON — fast for queries)
     *
     * Example stored value:
     * [{"role":"user","content":"What do you recommend?"},
     *  {"role":"assistant","content":"Try the Margherita!"}]
     */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(nullable = false, columnDefinition = "jsonb")
    private String messages;

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    // ──────────────────────────────────────────────────────────
    // RELATIONSHIP
    // ──────────────────────────────────────────────────────────

    /**
     * Many AiSessions → One User.
     * A user can have at most one active session (enforced in service logic),
     * but the schema allows multiple historical sessions per user.
     */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
}
