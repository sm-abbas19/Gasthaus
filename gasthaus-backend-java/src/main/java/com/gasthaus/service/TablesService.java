package com.gasthaus.service;

import com.gasthaus.dto.tables.CreateTableRequest;
import com.gasthaus.dto.tables.TableDetailResponse;
import com.gasthaus.dto.tables.TableStatsResponse;
import com.gasthaus.entity.Order;
import com.gasthaus.entity.RestaurantTable;
import com.gasthaus.entity.enums.OrderStatus;
import com.gasthaus.repository.OrderRepository;
import com.gasthaus.repository.RestaurantTableRepository;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.WriterException;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

/**
 * Business logic for restaurant table management.
 *
 * NestJS equivalent: TablesService in src/tables/tables.service.ts
 *
 * Key differences from NestJS:
 *
 * 1. QR code generation:
 *    NestJS: QRCode.toDataURL(qrData) — produces data:image/png;base64,...
 *    Spring: ZXing QRCodeWriter → MatrixToImageWriter → Base64 — same output format
 *
 * 2. Delete with FK violation:
 *    NestJS: catches Prisma P2003 → BadRequestException
 *    Spring: catches DataIntegrityViolationException → ResponseStatusException(400)
 *
 * 3. Table detail with active orders:
 *    NestJS: prisma.restaurantTable.findUnique({ include: { orders: { where: { status: { notIn: [] } } } } })
 *    Spring: fetch table then fetch active orders separately with JOIN FETCH, compose into DTO
 *    (JPA can't filter a JOIN FETCH collection inline — WHERE applies to the entire query)
 */
@Service
@RequiredArgsConstructor
public class TablesService {

    private final RestaurantTableRepository tableRepository;
    private final OrderRepository orderRepository;

    /** Statuses that mean an order is no longer active — excluded from table views. */
    private static final List<OrderStatus> TERMINAL_STATUSES =
            List.of(OrderStatus.COMPLETED, OrderStatus.CANCELLED);

    // ─── Read Tables ──────────────────────────────────────────────

    /**
     * NestJS: prisma.restaurantTable.findMany({ orderBy: { tableNumber: 'asc' }, include: { orders: {...} } })
     *
     * Returns plain tables (isOccupied flag is enough for the floor plan view).
     * Active orders per table can be fetched via getTableById() or the /orders endpoint.
     *
     * Note: RestaurantTable.orders has @JsonIgnore to prevent Order → table → orders cycles.
     * This returns just the table rows, equivalent to the floor plan data the frontend needs.
     */
    @Transactional(readOnly = true)
    public List<RestaurantTable> getAllTables() {
        return tableRepository.findAllByOrderByTableNumberAsc();
    }

    /**
     * NestJS: prisma.restaurantTable.findUnique({ where: { id }, include: { orders: { where: { ... } } } })
     *
     * Returns a TableDetailResponse — a DTO that includes the table AND its active orders
     * with full relations (items, customer). This is the Spring equivalent of Prisma's nested include.
     *
     * The two-step fetch (table + orders) is explicit but correct:
     *   Step 1: find the table (404 if not found)
     *   Step 2: JOIN FETCH active orders for that table in one query
     */
    @Transactional(readOnly = true)
    public TableDetailResponse getTableById(UUID id) {
        RestaurantTable table = findTableOrFail(id);
        List<Order> activeOrders = orderRepository.findActiveByTableIdWithDetails(id, TERMINAL_STATUSES);
        return TableDetailResponse.from(table, activeOrders);
    }

    /**
     * NestJS: prisma.restaurantTable.findUnique({ where: { tableNumber } })
     * Used by the public QR scan endpoint — no orders needed.
     */
    @Transactional(readOnly = true)
    public RestaurantTable getTableByNumber(int tableNumber) {
        return tableRepository.findByTableNumber(tableNumber)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found"));
    }

    /**
     * NestJS:
     *   const tables = await prisma.restaurantTable.findMany();
     *   const total = tables.length;
     *   const occupied = tables.filter(t => t.isOccupied).length;
     *   return { total, occupied, available: total - occupied };
     *
     * We replicate the same approach: fetch all, count in Java.
     * Alternative: two COUNT() queries — but for typical restaurant sizes (< 100 tables)
     * this in-memory approach is fine and matches the NestJS implementation exactly.
     */
    @Transactional(readOnly = true)
    public TableStatsResponse getTableStats() {
        List<RestaurantTable> tables = tableRepository.findAll();
        long total    = tables.size();
        long occupied = tables.stream().filter(RestaurantTable::getIsOccupied).count();
        long available = total - occupied;
        return new TableStatsResponse(total, occupied, available);
    }

    // ─── Create / Delete / Toggle ──────────────────────────────────

    /**
     * NestJS:
     *   const existing = await prisma.restaurantTable.findUnique({ where: { tableNumber } });
     *   if (existing) throw ConflictException
     *   const qrCode = await QRCode.toDataURL(`${baseUrl}/table/${tableNumber}`);
     *   return prisma.restaurantTable.create({ data: { tableNumber, qrCode } });
     *
     * @param baseUrl — extracted from the HTTP request in the controller.
     *   NestJS: const baseUrl = `${req.protocol}://${req.get('host')}`
     *   Spring: HttpServletRequest gives us the same info.
     */
    @Transactional
    public RestaurantTable createTable(CreateTableRequest dto, String baseUrl) {
        // Duplicate check
        if (tableRepository.findByTableNumber(dto.getTableNumber()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Table " + dto.getTableNumber() + " already exists");
        }

        String qrData = baseUrl + "/table/" + dto.getTableNumber();
        String qrCode = generateQrCode(qrData);

        RestaurantTable table = RestaurantTable.builder()
                .tableNumber(dto.getTableNumber())
                .qrCode(qrCode)
                .build();

        return tableRepository.save(table);
    }

    /**
     * NestJS:
     *   await this.findTableOrFail(id);
     *   try { return await prisma.restaurantTable.delete({ where: { id } }); }
     *   catch (error) { if (error.code === 'P2003') throw BadRequestException }
     *
     * Spring's equivalent of Prisma's P2003 (foreign key violation) is
     * DataIntegrityViolationException from spring-tx. We catch it and convert to 400.
     */
    @Transactional
    public void deleteTable(UUID id) {
        findTableOrFail(id);
        try {
            tableRepository.deleteById(id);
            tableRepository.flush(); // force the DELETE SQL to execute within the transaction
        } catch (DataIntegrityViolationException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Cannot delete table with existing orders. Complete or cancel all orders first.");
        }
    }

    /**
     * NestJS:
     *   const table = await this.findTableOrFail(id);
     *   return prisma.restaurantTable.update({ where: { id }, data: { isOccupied: !table.isOccupied } });
     */
    @Transactional
    public RestaurantTable toggleOccupied(UUID id) {
        RestaurantTable table = findTableOrFail(id);
        table.setIsOccupied(!table.getIsOccupied());
        return tableRepository.save(table);
    }

    // ─── Helpers ──────────────────────────────────────────────────

    private RestaurantTable findTableOrFail(UUID id) {
        return tableRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found"));
    }

    /**
     * Generates a QR code and returns it as a base64 data URL.
     *
     * NestJS: await QRCode.toDataURL(qrData)
     *         → "data:image/png;base64,iVBOR..."
     *
     * ZXing (Java):
     *   1. QRCodeWriter.encode(text, format, width, height) → BitMatrix (pixel grid)
     *   2. MatrixToImageWriter.writeToStream(bitMatrix, "PNG", stream) → PNG bytes
     *   3. Base64.encode(bytes) → base64 string
     *   4. Prepend "data:image/png;base64," to match browser <img src="..."> format
     *
     * The output is identical to NestJS's QRCode.toDataURL() — a PNG data URL
     * that can be rendered directly in an <img> tag.
     */
    private String generateQrCode(String data) {
        try {
            QRCodeWriter writer = new QRCodeWriter();
            BitMatrix matrix = writer.encode(data, BarcodeFormat.QR_CODE, 200, 200);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            MatrixToImageWriter.writeToStream(matrix, "PNG", out);
            String base64 = Base64.getEncoder().encodeToString(out.toByteArray());
            return "data:image/png;base64," + base64;
        } catch (WriterException | IOException e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR,
                    "Failed to generate QR code: " + e.getMessage());
        }
    }
}
