package com.gasthaus.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import com.gasthaus.dto.menu.CreateCategoryRequest;
import com.gasthaus.dto.menu.CreateItemRequest;
import com.gasthaus.dto.menu.UpdateItemRequest;
import com.gasthaus.entity.MenuCategory;
import com.gasthaus.entity.MenuItem;
import com.gasthaus.repository.MenuCategoryRepository;
import com.gasthaus.repository.MenuItemRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Business logic for menu categories and items.
 *
 * NestJS equivalent: MenuService in src/menu/menu.service.ts
 *
 * Key differences from NestJS:
 *
 * 1. Caching — @Cacheable replaces manual cacheManager.get/set/del:
 *    NestJS: const cached = await this.cacheManager.get(key); if (cached) return cached;
 *    Spring: @Cacheable("menu:categories") — Spring intercepts the call, checks cache first.
 *    @CacheEvict("menu:categories") — Spring removes the cache entry on mutation.
 *    This is declarative caching: the service method itself has no caching code.
 *
 * 2. Cloudinary — Java SDK uses Map-based API instead of method chaining:
 *    NestJS: cloudinary.uploader.upload_stream(...).end(file.buffer)
 *    Spring: cloudinary.uploader().upload(file.getBytes(), options) — synchronous
 *    The Java SDK wraps the HTTP call synchronously, no stream callback needed.
 *
 * 3. Partial updates (PATCH) — JPA requires manual field-by-field update:
 *    NestJS: prisma.menuItem.update({ data: { ...dto } }) — Prisma handles undefined fields
 *    Spring: we check each field for null and set it on the entity manually, then save().
 */
@Service
@RequiredArgsConstructor
public class MenuService {

    private static final Logger log = LoggerFactory.getLogger(MenuService.class);

    private final MenuCategoryRepository categoryRepository;
    private final MenuItemRepository itemRepository;

    /**
     * SimpMessagingTemplate broadcasts STOMP messages to connected clients.
     * NestJS equivalent: this.server.emit('menu:updated', {}) in the Gateway.
     * We send a simple { "event": "updated" } payload to /topic/menu.
     * Flutter subscribes to this topic and calls loadMenu() on receipt.
     */
    private final SimpMessagingTemplate messagingTemplate;

    /**
     * Notifies all connected Flutter clients that the menu has changed.
     * Called after every mutation (create/update/delete/toggle).
     * The payload is minimal — the client just needs a signal to re-fetch,
     * not the full menu data (that would be a large WebSocket message).
     */
    private void broadcastMenuUpdate() {
        long tsMs = System.currentTimeMillis();
        log.info("[MENU-WS] Broadcasting menu update to /topic/menu at {} ms", tsMs);
        messagingTemplate.convertAndSend("/topic/menu", Map.of("event", "updated"));
        log.info("[MENU-WS] Broadcast sent at {} ms", System.currentTimeMillis());
    }

    // ─── Cloudinary setup ─────────────────────────────────────────

    /**
     * @Value reads from application.properties.
     * NestJS equivalent: cloudinary.config({ cloud_name, api_key, api_secret })
     * in the constructor reading from process.env.
     */
    @Value("${app.cloudinary.cloud-name}")
    private String cloudinaryCloudName;

    @Value("${app.cloudinary.api-key}")
    private String cloudinaryApiKey;

    @Value("${app.cloudinary.api-secret}")
    private String cloudinaryApiSecret;

    private Cloudinary cloudinary;

    /**
     * @PostConstruct — runs after Spring injects @Value fields.
     * NestJS equivalent: cloudinary.config({...}) in the constructor.
     * We can't configure Cloudinary in the constructor because @Value
     * fields aren't injected yet when the constructor runs.
     */
    @PostConstruct
    public void initCloudinary() {
        this.cloudinary = new Cloudinary(ObjectUtils.asMap(
                "cloud_name", cloudinaryCloudName,
                "api_key",    cloudinaryApiKey,
                "api_secret", cloudinaryApiSecret,
                "secure",     true                 // always use https:// URLs
        ));
    }

    // ─── Categories ───────────────────────────────────────────────

    /**
     * NestJS:
     *   async getCategories() {
     *     const cached = await this.cacheManager.get('menu:categories');
     *     if (cached) return cached;
     *     const categories = await prisma.menuCategory.findMany({
     *       include: { items: { where: { isAvailable: true }, orderBy: { name: 'asc' } } },
     *       orderBy: { name: 'asc' }
     *     });
     *     await this.cacheManager.set('menu:categories', categories, 300000);
     *     return categories;
     *   }
     *
     * Spring equivalent with declarative caching:
     *
     * @Cacheable("menu:categories") — Spring's cache proxy intercepts this call.
     *   On first call: executes the method, stores result under key "menu:categories".
     *   On subsequent calls: returns cached value WITHOUT executing the method body.
     *
     * This is fundamentally the same as NestJS's manual get/set, just declarative.
     * TTL: the simple cache provider has no TTL — entries live until explicitly evicted.
     * To add TTL, switch to Caffeine: spring.cache.type=caffeine + caffeine config.
     *
     * The JOIN FETCH query in the repository handles the "include + filter" Prisma does.
     */
    @Cacheable("menu:categories")
    public List<MenuCategory> getCategories() {
        return categoryRepository.findAllWithAvailableItemsOrderedByName();
    }

    public List<MenuCategory> getCategoriesWithAllItems() {
        return categoryRepository.findAllWithAllItemsOrderedByName();
    }

    /**
     * NestJS: prisma.menuCategory.create({ data: dto })
     *
     * @CacheEvict — invalidates the cached category list after a new category is created.
     * NestJS equivalent: await this.cacheManager.del('menu:categories')
     * allEntries = false (default) — only evicts the entry with the matching key.
     */
    @CacheEvict(value = "menu:categories", allEntries = true)
    public MenuCategory createCategory(CreateCategoryRequest dto) {
        MenuCategory category = MenuCategory.builder()
                .name(dto.getName())
                .icon(dto.getIcon())
                .build();
        MenuCategory saved = categoryRepository.save(category);
        broadcastMenuUpdate();
        return saved;
    }

    /**
     * NestJS:
     *   await this.findCategoryOrFail(id);
     *   return this.prisma.menuCategory.delete({ where: { id } });
     */
    @CacheEvict(value = "menu:categories", allEntries = true)
    public void deleteCategory(UUID id) {
        findCategoryOrFail(id);
        categoryRepository.deleteById(id);
        broadcastMenuUpdate();
    }

    // ─── Items ────────────────────────────────────────────────────

    /**
     * NestJS: prisma.menuItem.findMany({ include: { category: true }, orderBy: { createdAt: 'desc' } })
     *
     * findAllByOrderByCreatedAtDesc() returns items without category loaded (LAZY).
     * We use findAllByOrderByCreatedAtDesc() from the repository and iterate — but
     * that would N+1. Instead we rely on the fact that this is an admin endpoint
     * and use a JOIN FETCH via a custom @Query.
     *
     * Actually — for the admin items list, we need category info. The simplest approach
     * without adding yet another @Query is to let the service load items and accept
     * that category is available via LAZY loading within the same transaction.
     * Spring's @Transactional would keep the session open for lazy loads.
     *
     * For now: items are loaded with lazy category. The controller serializes the
     * entity — Jackson will trigger lazy load for `category` field per item.
     * This is N+1 in the worst case for this specific admin endpoint.
     * A production fix: add findAllWithCategoryOrderByCreatedAtDesc @Query to the repo.
     * We keep it simple here to focus on the Phase 4 flow.
     */
    public List<MenuItem> getItems() {
        return itemRepository.findAllByOrderByCreatedAtDesc();
    }

    /**
     * NestJS: prisma.menuItem.findUnique({ where: { id }, include: { category: true, reviews: {...} } })
     *
     * findByIdWithCategory() JOIN FETCHes the category in one query.
     * Reviews are loaded separately (not needed here for a single item response).
     */
    public MenuItem getItemById(UUID id) {
        return itemRepository.findByIdWithCategory(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Menu item not found"));
    }

    /**
     * NestJS:
     *   await this.findCategoryOrFail(dto.categoryId);
     *   let imageUrl = undefined;
     *   if (imageFile) imageUrl = await this.uploadImage(imageFile);
     *   return prisma.menuItem.create({ data: { ...dto, imageUrl }, include: { category: true } });
     *
     * @param image — nullable; Spring's MultipartFile wraps the uploaded bytes.
     *   isEmpty() returns true when no file was sent (equivalent to NestJS's imageFile being undefined).
     */
    @CacheEvict(value = "menu:categories", allEntries = true)
    public MenuItem createItem(CreateItemRequest dto, MultipartFile image) {
        MenuCategory category = findCategoryOrFail(dto.getCategoryId());

        String imageUrl = null;
        if (image != null && !image.isEmpty()) {
            imageUrl = uploadToCloudinary(image);
        }

        MenuItem item = MenuItem.builder()
                .name(dto.getName())
                .description(dto.getDescription())
                .price(dto.getPrice())
                .category(category)
                .imageUrl(imageUrl)
                .isAvailable(dto.getIsAvailable() != null ? dto.getIsAvailable() : true)
                .build();

        MenuItem saved = itemRepository.save(item);
        broadcastMenuUpdate();
        return saved;
    }

    /**
     * NestJS:
     *   await this.findItemOrFail(id);
     *   if (dto.categoryId) await this.findCategoryOrFail(dto.categoryId);
     *   return prisma.menuItem.update({ where: { id }, data: { ...dto, ...(imageUrl && { imageUrl }) } })
     *
     * JPA doesn't have Prisma's spread-update — we must apply each field manually.
     * Only non-null fields are updated (mirrors UpdateItemDto's @IsOptional fields).
     */
    @CacheEvict(value = "menu:categories", allEntries = true)
    public MenuItem updateItem(UUID id, UpdateItemRequest dto, MultipartFile image) {
        MenuItem item = findItemOrFail(id);

        if (dto.getCategoryId() != null) {
            MenuCategory category = findCategoryOrFail(dto.getCategoryId());
            item.setCategory(category);
        }
        if (dto.getName() != null)        item.setName(dto.getName());
        if (dto.getDescription() != null)  item.setDescription(dto.getDescription());
        if (dto.getPrice() != null)        item.setPrice(dto.getPrice());
        if (dto.getIsAvailable() != null)  item.setIsAvailable(dto.getIsAvailable());

        if (image != null && !image.isEmpty()) {
            item.setImageUrl(uploadToCloudinary(image));
        }

        MenuItem saved = itemRepository.save(item);
        broadcastMenuUpdate();
        return saved;
    }

    /**
     * NestJS:
     *   await this.findItemOrFail(id);
     *   return prisma.menuItem.delete({ where: { id } });
     */
    @CacheEvict(value = "menu:categories", allEntries = true)
    public void deleteItem(UUID id) {
        findItemOrFail(id);
        itemRepository.deleteById(id);
        broadcastMenuUpdate();
    }

    /**
     * NestJS:
     *   const item = await this.findItemOrFail(id);
     *   return prisma.menuItem.update({ where: { id }, data: { isAvailable: !item.isAvailable } })
     */
    @CacheEvict(value = "menu:categories", allEntries = true)
    public MenuItem toggleAvailability(UUID id) {
        MenuItem item = findItemOrFail(id);
        boolean newValue = !item.getIsAvailable();
        log.info("[MENU-TOGGLE] Item '{}' (id={}) toggled: isAvailable {} -> {}",
                item.getName(), id, item.getIsAvailable(), newValue);
        item.setIsAvailable(newValue);
        MenuItem saved = itemRepository.save(item);
        log.info("[MENU-TOGGLE] DB save complete. Saved isAvailable={}", saved.getIsAvailable());
        broadcastMenuUpdate();
        return saved;
    }

    // ─── Helpers ──────────────────────────────────────────────────

    /**
     * NestJS: private findCategoryOrFail(id) → throws NotFoundException if null
     * Spring: throws ResponseStatusException(404) — same effect, no Passport/NestJS dep.
     */
    private MenuCategory findCategoryOrFail(UUID id) {
        return categoryRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Category not found"));
    }

    private MenuItem findItemOrFail(UUID id) {
        return itemRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Menu item not found"));
    }

    /**
     * NestJS:
     *   private uploadImage(file): Promise<string> {
     *     return new Promise((resolve, reject) => {
     *       cloudinary.uploader.upload_stream({ folder: 'gasthaus/menu' }, (err, result) => {
     *         resolve(result.secure_url);
     *       }).end(file.buffer);
     *     });
     *   }
     *
     * Java Cloudinary SDK is synchronous — no callback/Promise needed.
     * upload() takes a byte array and a Map of options, returns a Map of results.
     * result.get("secure_url") is the HTTPS URL of the uploaded image.
     *
     * IOException from getBytes() is checked — we wrap it in a 500 RuntimeException.
     */
    @SuppressWarnings("unchecked")
    private String uploadToCloudinary(MultipartFile file) {
        try {
            Map<String, Object> result = cloudinary.uploader().upload(
                    file.getBytes(),
                    ObjectUtils.asMap("folder", "gasthaus/menu")
            );
            return (String) result.get("secure_url");
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR,
                    "Image upload failed. Please try again.");
        }
    }
}
