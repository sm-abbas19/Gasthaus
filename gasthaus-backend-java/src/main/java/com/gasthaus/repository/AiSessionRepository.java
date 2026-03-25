package com.gasthaus.repository;

import com.gasthaus.entity.AiSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

/**
 * Repository for AiSession.
 *
 * Context: In the NestJS backend, the AiService does NOT query the AiSession
 * table directly — it proxies all AI calls to the FastAPI service, which manages
 * session state internally. The AiSession entity exists in the schema (and thus
 * in the JPA entities) but the NestJS service layer bypasses the DB entirely for AI.
 *
 * For the Spring Boot port, we keep this repository for completeness and for any
 * future use (e.g., persisting session history in our own DB). If the Spring
 * service follows the same proxy approach, this repository may not be called.
 *
 * NestJS equivalent: would be prisma.aiSession.findFirst / create / delete
 * if it were used — but it isn't in the current NestJS implementation.
 */
@Repository
public interface AiSessionRepository extends JpaRepository<AiSession, UUID> {

    /**
     * Prisma: prisma.aiSession.findFirst({ where: { userId } })
     *
     * The AiSession entity comment says "a user can have at most one active session
     * (enforced in service logic)". So this returns Optional to get the current session.
     *
     * Spring Data resolves: user.id → User_Id
     */
    Optional<AiSession> findByUser_Id(UUID userId);

    /**
     * Deletes all sessions for a user.
     *
     * NestJS equivalent: DELETE /ai/session calls FastAPI to clear session,
     * but if we wanted to clear local DB sessions: prisma.aiSession.deleteMany({ where: { userId } })
     */
    void deleteByUser_Id(UUID userId);
}
