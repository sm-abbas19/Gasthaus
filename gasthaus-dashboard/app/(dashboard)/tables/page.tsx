'use client'

import { useState, useMemo } from 'react'
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query'
import { LayoutGrid, Users, CheckCircle, Clock, Plus, X, Trash2 } from 'lucide-react'
import api from '@/lib/api'
import type { RestaurantTable, Order } from '@/types'
import { OrderStatus } from '@/types'

// ── helpers ────────────────────────────────────────────────────────────────

const ACTIVE_ORDER_STATUSES: OrderStatus[] = [
  OrderStatus.CONFIRMED,
  OrderStatus.PREPARING,
  OrderStatus.READY,
  OrderStatus.PENDING,
]

const ORDER_STATUS_STYLES: Partial<Record<OrderStatus, string>> = {
  [OrderStatus.PENDING]:   'bg-[#FEF3C7] text-[#D97706]',
  [OrderStatus.CONFIRMED]: 'bg-[#DBEAFE] text-[#1D4ED8]',
  [OrderStatus.PREPARING]: 'bg-[#EDE9FE] text-[#6D28D9]',
  [OrderStatus.READY]:     'bg-[#D1FAE5] text-[#059669]',
  [OrderStatus.SERVED]:    'bg-[#E5E7EB] text-[#6B7280]',
}

function seatedDuration(dateStr: string): string {
  const mins = Math.floor((Date.now() - new Date(dateStr).getTime()) / 60_000)
  if (mins < 60) return `${mins}m`
  return `${Math.floor(mins / 60)}h ${mins % 60}m`
}

function seatedSince(dateStr: string): string {
  return new Date(dateStr).toLocaleTimeString('en-US', {
    hour: 'numeric', minute: '2-digit', hour12: true,
  })
}

// ── page ───────────────────────────────────────────────────────────────────

export default function TablesPage() {
  const queryClient                     = useQueryClient()
  const [selectedId, setSelectedId]     = useState<string | null>(null)
  const [addingTable, setAddingTable]   = useState(false)
  const [newTableNum, setNewTableNum]   = useState('')

  const { data: tables = [] } = useQuery<RestaurantTable[]>({
    queryKey: ['tables'],
    queryFn:  () => api.get<RestaurantTable[]>('/tables').then((r) => r.data),
  })

  const { data: orders = [] } = useQuery<Order[]>({
    queryKey: ['orders'],
    queryFn:  () => api.get<Order[]>('/orders').then((r) => r.data),
  })

  // Build tableId → active order map
  const activeOrderByTableId = useMemo(() => {
    const map = new Map<string, Order>()
    orders.forEach((o) => {
      const tableId = o.tableId ?? o.table?.id
      if (tableId && ACTIVE_ORDER_STATUSES.includes(o.status)) {
        // Keep the most recent active order per table
        const existing = map.get(tableId)
        if (!existing || new Date(o.createdAt) > new Date(existing.createdAt)) {
          map.set(tableId, o)
        }
      }
    })
    return map
  }, [orders])

  const sorted = [...tables].sort((a, b) => a.tableNumber - b.tableNumber)
  const selectedTable = sorted.find((t) => t.id === selectedId) ?? null
  const selectedOrder = selectedTable ? activeOrderByTableId.get(selectedTable.id) : null

  const occupiedCount  = tables.filter((t) => t.isOccupied).length
  const availableCount = tables.length - occupiedCount

  // ── mutations ──────────────────────────────────────────────────────────

  const { mutate: toggleTable } = useMutation({
    mutationFn: (id: string) => api.patch(`/tables/${id}/toggle`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['tables'] }),
  })

  const { mutate: addTable, isPending: addingPending } = useMutation({
    mutationFn: (tableNumber: number) => api.post('/tables', { tableNumber }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tables'] })
      setAddingTable(false)
      setNewTableNum('')
    },
  })

  const { mutate: deleteTable } = useMutation({
    mutationFn: (id: string) => api.delete(`/tables/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tables'] })
      if (selectedId) setSelectedId(null)
    },
  })

  return (
    <div className="flex h-[calc(100vh-56px)] overflow-hidden">

      {/* ── Left: floor plan ───────────────────────────────────────── */}
      <div className="flex-1 overflow-y-auto bg-[#F9F9F7] p-8">

        {/* Stats + Add Table row */}
        <div className="flex items-start justify-between mb-8 gap-6">
          <div className="grid grid-cols-4 gap-4 flex-1">
            <StatCard
              icon={<LayoutGrid size={18} className="text-[#D97706]" />}
              iconBg="bg-[#FEF3C7]"
              label="Total Tables"
              value={tables.length}
            />
            <StatCard
              icon={<Users size={18} className="text-red-500" />}
              iconBg="bg-[#FEE2E2]"
              label="Occupied"
              value={occupiedCount}
              valueColor="text-red-600"
            />
            <StatCard
              icon={<CheckCircle size={18} className="text-emerald-600" />}
              iconBg="bg-[#D1FAE5]"
              label="Available"
              value={availableCount}
              valueColor="text-emerald-600"
            />
            <StatCard
              icon={<Clock size={18} className="text-[#D97706]" />}
              iconBg="bg-[#FEF3C7]"
              label="Avg Duration"
              value="—"
            />
          </div>

          {/* Add Table button */}
          <button
            onClick={() => setAddingTable(true)}
            className="flex items-center gap-2 bg-[#D97706] text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-[#B45309] transition-colors shrink-0"
          >
            <Plus size={15} /> Add Table
          </button>
        </div>

        {/* Add Table inline modal */}
        {addingTable && (
          <div className="mb-6 bg-white border border-[#E5E7EB] rounded-lg p-5 flex items-center gap-4 max-w-sm">
            <div className="flex-1">
              <label className="block text-[10px] font-bold text-[#6B7280] uppercase tracking-widest mb-1.5">
                Table Number
              </label>
              <input
                autoFocus
                type="number"
                value={newTableNum}
                onChange={(e) => setNewTableNum(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && Number(newTableNum) > 0) addTable(Number(newTableNum))
                  if (e.key === 'Escape') { setAddingTable(false); setNewTableNum('') }
                }}
                placeholder="e.g. 13"
                className="w-full border border-[#E5E7EB] rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-[#D97706]"
              />
            </div>
            <div className="flex gap-2 pt-5">
              <button
                onClick={() => Number(newTableNum) > 0 && addTable(Number(newTableNum))}
                disabled={addingPending || Number(newTableNum) <= 0}
                className="bg-[#D97706] text-white px-4 py-2 rounded-lg text-sm font-bold hover:bg-[#B45309] disabled:opacity-50 transition-colors"
              >
                Add
              </button>
              <button
                onClick={() => { setAddingTable(false); setNewTableNum('') }}
                className="border border-[#E5E7EB] text-[#6B7280] px-3 py-2 rounded-lg text-sm hover:bg-[#F9F9F7] transition-colors"
              >
                <X size={14} />
              </button>
            </div>
          </div>
        )}

        {/* Floor plan */}
        <div
          className="rounded-xl p-10 relative overflow-hidden min-h-[500px]"
          style={{
            backgroundColor: '#FAFAFA',
            backgroundImage: 'radial-gradient(#E5E7EB 1px, transparent 1px)',
            backgroundSize: '20px 20px',
          }}
        >
          {tables.length === 0 ? (
            <div className="flex items-center justify-center h-64 text-[#9CA3AF] text-sm">
              No tables configured — add one above
            </div>
          ) : (
            <div className="grid grid-cols-4 gap-8 justify-items-center">
              {sorted.map((table) => {
                const order = activeOrderByTableId.get(table.id)
                const isSelected = table.id === selectedId
                return (
                  <TableTile
                    key={table.id}
                    table={table}
                    order={order}
                    selected={isSelected}
                    onClick={() => setSelectedId(isSelected ? null : table.id)}
                  />
                )
              })}
            </div>
          )}
        </div>
      </div>

      {/* ── Right: detail panel ────────────────────────────────────── */}
      <aside className="w-80 shrink-0 bg-white border-l border-[#E5E7EB] flex flex-col overflow-y-auto">
        {selectedTable ? (
          <div className="p-8">
            {/* Table number + status */}
            <div className="flex items-center justify-between mb-8">
              <h2 className="text-4xl font-extrabold tracking-tight text-zinc-900">
                T{selectedTable.tableNumber}
              </h2>
              <span
                className={`px-3 py-1 text-[10px] font-bold uppercase tracking-wider rounded ${
                  selectedTable.isOccupied
                    ? 'bg-red-100 text-red-600'
                    : 'bg-emerald-100 text-emerald-600'
                }`}
              >
                {selectedTable.isOccupied ? 'Occupied' : 'Available'}
              </span>
            </div>

            {selectedOrder ? (
              <div className="space-y-6">
                <DetailRow label="Customer">
                  <p className="text-lg font-semibold text-zinc-900">
                    {selectedOrder.customer?.name ?? 'Guest'}
                  </p>
                </DetailRow>

                <DetailRow label="Seated Duration">
                  <p className="text-lg font-bold text-red-600">
                    {seatedDuration(selectedOrder.createdAt)}
                  </p>
                </DetailRow>

                <DetailRow label="Current Amount">
                  <p className="text-2xl font-bold text-zinc-900">
                    Rs. {selectedOrder.totalAmount.toLocaleString()}
                  </p>
                </DetailRow>

                <DetailRow label="Order Status">
                  <span
                    className={`inline-block px-3 py-1 text-[10px] font-bold uppercase tracking-widest rounded-full ${
                      ORDER_STATUS_STYLES[selectedOrder.status] ?? 'bg-zinc-100 text-zinc-500'
                    }`}
                  >
                    {selectedOrder.status}
                  </span>
                </DetailRow>

                <div className="pt-4 border-t border-[#F4F4F2]">
                  <p className="text-sm text-[#6B7280]">
                    Table since {seatedSince(selectedOrder.createdAt)}
                  </p>
                </div>
              </div>
            ) : (
              <p className="text-sm text-[#9CA3AF]">No active order at this table.</p>
            )}

            {/* Actions */}
            <div className="mt-10 space-y-3">
              <button
                onClick={() => toggleTable(selectedTable.id)}
                className={`w-full py-3.5 text-xs font-bold uppercase tracking-widest rounded transition-colors ${
                  selectedTable.isOccupied
                    ? 'border border-red-200 text-red-600 hover:bg-red-50'
                    : 'bg-[#1C1C1E] text-white hover:bg-black'
                }`}
              >
                {selectedTable.isOccupied ? 'Mark as Available' : 'Mark as Occupied'}
              </button>

              <button
                onClick={() => {
                  if (confirm(`Delete Table ${selectedTable.tableNumber}?`)) {
                    deleteTable(selectedTable.id)
                  }
                }}
                className="w-full flex items-center justify-center gap-2 py-3.5 text-[11px] font-bold uppercase tracking-widest text-red-400 hover:text-red-600 hover:underline transition-colors"
              >
                <Trash2 size={13} /> Delete Table
              </button>
            </div>
          </div>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center text-[#9CA3AF] p-8 text-center">
            <LayoutGrid size={32} className="mb-3 opacity-30" />
            <p className="text-sm">Select a table<br />to view details</p>
          </div>
        )}
      </aside>
    </div>
  )
}

// ── TableTile ──────────────────────────────────────────────────────────────

function TableTile({
  table,
  order,
  selected,
  onClick,
}: {
  table: RestaurantTable
  order: Order | undefined
  selected: boolean
  onClick: () => void
}) {
  if (table.isOccupied) {
    return (
      <div
        onClick={onClick}
        className={`w-[100px] h-[100px] bg-white rounded-lg flex flex-col justify-between overflow-hidden cursor-pointer transition-all ${
          selected ? 'ring-2 ring-[#D97706]' : 'hover:ring-1 hover:ring-[#D97706]/40'
        }`}
      >
        <div className="p-2 flex-1">
          <div className="flex justify-between items-start">
            <span className="text-xs font-bold text-zinc-900">T{table.tableNumber}</span>
            <span className="w-2 h-2 rounded-full bg-red-500 shrink-0" />
          </div>
          {order && (
            <>
              <p className="text-[10px] text-[#6B7280] truncate mt-1">
                {order.customer?.name ?? 'Guest'}
              </p>
              <p className="text-[10px] font-bold text-zinc-900">
                Rs. {order.totalAmount.toLocaleString()}
              </p>
            </>
          )}
        </div>
        <div className="h-1 bg-red-500 w-full shrink-0" />
      </div>
    )
  }

  // Available
  return (
    <div
      onClick={onClick}
      className={`w-[100px] h-[100px] rounded-lg flex flex-col items-center justify-center cursor-pointer transition-all border border-dashed ${
        selected
          ? 'ring-2 ring-[#D97706] border-[#D97706]/40 bg-amber-50'
          : 'border-[#D1D5DB] bg-[#FAFAFA] hover:border-[#D97706]/40'
      }`}
    >
      <span className="w-2 h-2 rounded-full bg-emerald-500 mb-1.5" />
      <span className="text-sm font-bold text-[#9CA3AF]">T{table.tableNumber}</span>
    </div>
  )
}

// ── StatCard ───────────────────────────────────────────────────────────────

function StatCard({
  icon,
  iconBg,
  label,
  value,
  valueColor = 'text-zinc-900',
}: {
  icon: React.ReactNode
  iconBg: string
  label: string
  value: number | string
  valueColor?: string
}) {
  return (
    <div className="bg-white p-5 flex items-center gap-4 rounded-lg border border-[#E5E7EB]">
      <div className={`w-9 h-9 flex items-center justify-center rounded-lg shrink-0 ${iconBg}`}>
        {icon}
      </div>
      <div>
        <p className="text-xs text-[#6B7280] font-medium">{label}</p>
        <p className={`text-2xl font-bold ${valueColor}`}>{value}</p>
      </div>
    </div>
  )
}

// ── DetailRow ──────────────────────────────────────────────────────────────

function DetailRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="text-[10px] text-[#6B7280] font-medium uppercase tracking-widest mb-1">{label}</p>
      {children}
    </div>
  )
}
