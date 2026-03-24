package com.gasthaus.entity;

import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Maps to the Prisma "model MenuCategory".
 *
 * This is the simpler side of the Category ↔ MenuItem relationship.
 * It holds no foreign key — the foreign key (category_id) lives on
 * the MenuItem table, making MenuItem the "owning side."
 *
 * In JPA terminology:
 *   - Owning side    = the entity that holds the @JoinColumn (foreign key)
 *   - Inverse side   = the entity that declares mappedBy
 * MenuCategory is the INVERSE side of the Category ↔ MenuItem relation.
 */
@Entity
@Table(name = "menu_categories")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EqualsAndHashCode(of = "id")
@ToString(exclude = "items")
public class MenuCategory {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(updatable = false, nullable = false)
    private UUID id;

    @Column(nullable = false)
    private String name;

    /**
     * Nullable — Prisma: icon String?
     * No @Column(nullable = false) here, so the column allows NULL.
     * Stores an icon identifier, e.g., "pizza", "coffee".
     */
    private String icon;

    /**
     * One Category → Many MenuItems.
     * The foreign key column (category_id) is declared on MenuItem.
     * mappedBy = "category" points to the MenuItem.category field.
     */
    @OneToMany(mappedBy = "category", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<MenuItem> items = new ArrayList<>();
}
