'use client'

import { useEffect, useState, useMemo } from 'react'
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query'
import { Search, RefreshCw, ArrowRight } from 'lucide-react'
import api from '@/lib/api'
import { createStompClient, TOPICS } from '@/lib/socket'
import type { Order } from '@/types'
import { OrderStatus } from '@/types'
import OrderDetailModal from '@/components/order-detail-modal'

// ── column config ──────────────────────────────────────────────────────────

const COLUMNS: {
  status: OrderStatus
  label: string
  badgeCls: string
  actionLabel: string | null
  nextStatus: OrderStatus | null
  leftBorder: string | null
  dimmed: boolean
  canCancel: boolean
}[] = [
  {
    status:      OrderStatus.PENDING,
    label:       'Pending',
    badgeCls:    'bg-[#FEF3C7] text-[#92400E]',   // light amber / amber-800
    actionLabel: 'Confirm',
    nextStatus:  OrderStatus.CONFIRMED,
    leftBorder:  null,
    dimmed:      false,
    canCancel:   true,
  },
  {
    status:      OrderStatus.CONFIRMED,
    label:       'Confirmed',
    badgeCls:    'bg-[#FEF3C7] text-[#D97706]',   // light amber / brand amber
    actionLabel: 'Prep',
    nextStatus:  OrderStatus.PREPARING,
    leftBorder:  null,
    dimmed:      false,
    canCancel:   true,
  },
  {
    status:      OrderStatus.PREPARING,
    label:       'Preparing',
    badgeCls:    'bg-[#FEF3C7] text-[#D97706]',   // light amber / brand amber
    actionLabel: 'Ready',
    nextStatus:  OrderStatus.READY,
    leftBorder:  '#D97706',                        // amber left-border (active)
    dimmed:      false,
    canCancel:   false,
  },
  {
    status:      OrderStatus.READY,
    label:       'Ready',
    badgeCls:    'bg-[#FEF3C7] text-[#78350F]',   // light amber / dark amber — most urgent
    actionLabel: 'Serve',
    nextStatus:  OrderStatus.SERVED,
    leftBorder:  '#78350F',                        // dark amber left-border
    dimmed:      false,
    canCancel:   false,
  },
  {
    status:      OrderStatus.SERVED,
    label:       'Served',
    badgeCls:    'bg-[#F3F4F6] text-[#6B7280]',   // grey — order delivered, winding down
    actionLabel: 'Mark Paid',
    nextStatus:  OrderStatus.PAID,
    leftBorder:  '#9CA3AF',                        // grey left-border
    dimmed:      false,
    canCancel:   false,
  },
  {
    status:      OrderStatus.PAID,
    label:       'Paid',
    badgeCls:    'bg-[#F3F4F6] text-[#9CA3AF]',   // light grey — terminal
    actionLabel: null,
    nextStatus:  null,
    leftBorder:  null,
    dimmed:      true,
    canCancel:   false,
  },
]

// ── helpers ────────────────────────────────────────────────────────────────

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime()
  const mins = Math.floor(diff / 60_000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  return `${Math.floor(hrs / 24)}d ago`
}

function isToday(dateStr: string): boolean {
  return new Date(dateStr).toDateString() === new Date().toDateString()
}

function isThisWeek(dateStr: string): boolean {
  const d = new Date(dateStr)
  const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
  return d >= weekAgo && d <= new Date()
}

// ── page ───────────────────────────────────────────────────────────────────

export default function OrdersPage() {
  const queryClient = useQueryClient()
  const [search, setSearch]       = useState('')
  const [period, setPeriod]       = useState<'today' | 'week'>('today')
  const [spinning, setSpinning]   = useState(false)
  const [selectedId, setSelectedId] = useState<string | null>(null)

  const { data: orders = [], isFetching } = useQuery<Order[]>({
    queryKey: ['orders'],
    queryFn:  () => api.get<Order[]>('/orders').then((r) => r.data),
  })

  useEffect(() => {
    if (!isFetching) setSpinning(false)
  }, [isFetching])

  const { mutate: updateStatus } = useMutation({
    mutationFn: ({ id, status }: { id: string; status: OrderStatus }) =>
      api.patch(`/orders/${id}/status`, { status }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['orders'] }),
  })

  const { mutate: cancelOrder } = useMutation({
    mutationFn: (id: string) =>
      api.patch(`/orders/${id}/status`, { status: OrderStatus.CANCELLED }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['orders'] }),
  })

  // STOMP real-time
  useEffect(() => {
    const client = createStompClient()
    client.onConnect = () => {
      client.subscribe(TOPICS.ORDER_NEW,    () => queryClient.invalidateQueries({ queryKey: ['orders'] }))
      client.subscribe(TOPICS.ORDER_STATUS, () => queryClient.invalidateQueries({ queryKey: ['orders'] }))
    }
    client.activate()
    return () => { client.deactivate() }
  }, [queryClient])

  const filtered = useMemo(() => {
    return orders.filter((o) => {
      if (period === 'today' && !isToday(o.createdAt))     return false
      if (period === 'week'  && !isThisWeek(o.createdAt))  return false
      if (search) {
        const q     = search.toLowerCase()
        const name  = o.customer?.name?.toLowerCase() ?? ''
        const table = o.table?.tableNumber?.toString() ?? ''
        if (!name.includes(q) && !table.includes(q)) return false
      }
      return true
    })
  }, [orders, search, period])

  return (
    <div className="flex flex-col h-[calc(100vh-56px)] overflow-hidden">

      {selectedId && (
        <OrderDetailModal orderId={selectedId} onClose={() => setSelectedId(null)} />
      )}

      {/* ── Filter bar ───────────────────────────────────────────────── */}
      <div className="shrink-0 flex items-center justify-between px-6 py-4 border-b border-[#E5E7EB] bg-[#F9F9F7]">
        <div className="flex items-center gap-3">

          {/* Search */}
          <div className="relative w-56">
            <Search size={13} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#9CA3AF]" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search orders..."
              className="w-full bg-white border border-[#E5E7EB] text-xs pl-8 pr-3 py-2 rounded-lg focus:outline-none focus:ring-1 focus:ring-[#D97706] focus:border-[#D97706] transition-all"
            />
          </div>

          {/* Period toggle */}
          <div className="flex bg-[#E5E7EB]/50 p-1 rounded-lg">
            {(['today', 'week'] as const).map((p) => (
              <button
                key={p}
                onClick={() => setPeriod(p)}
                className={`px-4 py-1 text-[11px] font-semibold rounded-md transition-all ${
                  period === p
                    ? 'bg-[#1C1C1E] text-white shadow-sm'
                    : 'text-[#6B7280] hover:text-[#1C1C1E]'
                }`}
              >
                {p === 'today' ? 'Today' : 'This Week'}
              </button>
            ))}
          </div>

          <div className="h-5 w-px bg-[#E5E7EB]" />

          <button
            onClick={() => {
              setSpinning(true)
              queryClient.invalidateQueries({ queryKey: ['orders'] })
            }}
            className="flex items-center gap-1.5 text-xs font-medium text-[#6B7280] hover:text-[#D97706] transition-colors"
          >
            <RefreshCw size={13} className={spinning ? 'animate-spin' : ''} />
            Refresh
          </button>
        </div>
      </div>

      {/* ── Kanban board ─────────────────────────────────────────────── */}
      <div className="flex-1 overflow-hidden">
        <div className="h-full flex gap-5 overflow-x-auto p-6 pb-4">
          {COLUMNS.map((col) => {
            const colOrders = filtered
              .filter((o) => o.status === col.status)
              .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())

            return (
              <div key={col.status} className="h-full flex flex-col gap-3 shrink-0 w-[280px]">

                {/* Column header */}
                <div className="flex items-center gap-2 px-1 shrink-0">
                  <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold tracking-wider uppercase ${col.badgeCls}`}>
                    {col.label}
                  </span>
                  <span className="w-5 h-5 rounded-full bg-white border border-[#E5E7EB] flex items-center justify-center text-[10px] font-bold text-[#6B7280]">
                    {colOrders.length}
                  </span>
                </div>

                {/* Column body — scrollable */}
                <div className="flex-1 min-h-0 overflow-y-auto bg-[#F3F4F6] rounded-lg p-3 space-y-3">
                  {colOrders.length === 0 && (
                    <p className="text-[11px] text-zinc-400 text-center py-6">No orders</p>
                  )}
                  {colOrders.map((order) => (
                    <OrderCard
                      key={order.id}
                      order={order}
                      leftBorder={col.leftBorder ?? undefined}
                      dimmed={col.dimmed}
                      actionLabel={col.actionLabel ?? undefined}
                      nextStatus={col.nextStatus ?? undefined}
                      canCancel={col.canCancel}
                      onAction={(id, status) => updateStatus({ id, status })}
                      onCancel={(id) => cancelOrder(id)}
                      onCardClick={(id) => setSelectedId(id)}
                    />
                  ))}
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}

// ── OrderCard ──────────────────────────────────────────────────────────────

function OrderCard({
  order,
  leftBorder,
  dimmed,
  actionLabel,
  nextStatus,
  canCancel,
  onAction,
  onCancel,
  onCardClick,
}: {
  order: Order
  leftBorder?: string
  dimmed?: boolean
  actionLabel?: string
  nextStatus?: OrderStatus
  canCancel?: boolean
  onAction: (id: string, status: OrderStatus) => void
  onCancel: (id: string) => void
  onCardClick: (id: string) => void
}) {
  const tableLabel  = order.table?.tableNumber ? `T${order.table.tableNumber}` : '—'
  const name        = order.customer?.name ?? 'Guest'
  const summary     = order.items.slice(0, 2).map((i) => `${i.quantity}× ${i.menuItem.name}`).join(', ')
  const hasMore     = order.items.length > 2
  const notes       = order.notes

  const [confirmingCancel, setConfirmingCancel] = useState(false)

  // Build class string based on dimmed / leftBorder
  const borderCls = dimmed
    ? 'border border-[#E5E7EB]'
    : leftBorder
      ? 'border-y border-r border-[#E5E7EB] border-l-[3px]'
      : 'border border-[#E5E7EB]'

  const bgCls = dimmed ? 'bg-[#FAFAFA] opacity-90' : 'bg-white hover:border-[#D97706]/30'

  return (
    <div
      className={`rounded-lg p-3 transition-all cursor-pointer ${bgCls} ${borderCls}`}
      style={leftBorder ? { borderLeftColor: leftBorder } : undefined}
      onClick={() => onCardClick(order.id)}
    >
      <div className="flex justify-between items-start mb-2">
        <span className="text-[10px] font-bold text-[#9CA3AF] tracking-wider">{tableLabel}</span>
        <span className="text-[10px] text-[#9CA3AF]">{timeAgo(order.createdAt)}</span>
      </div>

      <h4 className={`text-sm font-semibold mb-1 ${dimmed ? 'text-[#6B7280]' : 'text-[#1C1C1E]'}`}>
        {name}
      </h4>

      <p className={`text-[11px] leading-relaxed ${dimmed ? 'text-[#9CA3AF]' : 'text-[#6B7280]'}`}>
        {summary}{hasMore ? ', …' : ''}
      </p>

      {notes && (
        <div className="mt-2 mb-1 px-2 py-1.5 bg-[#FEF3C7] rounded text-[10px] text-[#92400E] leading-relaxed">
          <span className="font-bold">Note: </span>{notes}
        </div>
      )}

      <div className="flex justify-between items-center border-t border-[#F3F4F6] pt-3 mt-3">
        <span className={`text-xs font-bold ${dimmed ? 'text-[#6B7280]' : 'text-[#1C1C1E]'}`}>
          Rs. {order.totalAmount.toLocaleString()}
        </span>

        {actionLabel && nextStatus ? (
          <button
            onClick={(e) => { e.stopPropagation(); onAction(order.id, nextStatus) }}
            className="text-xs font-bold text-[#D97706] hover:opacity-75 transition-opacity flex items-center gap-1"
          >
            {actionLabel} <ArrowRight size={12} />
          </button>
        ) : (
          <span className="text-[10px] font-bold text-[#9CA3AF]">DONE</span>
        )}
      </div>

      {/* Cancel — only on PENDING and CONFIRMED cards, with inline confirmation */}
      {canCancel && (
        <div className="mt-2 pt-2 border-t border-[#F3F4F6]">
          {confirmingCancel ? (
            <div className="flex items-center gap-2" onClick={(e) => e.stopPropagation()}>
              <span className="text-[10px] text-[#6B7280] flex-1">Cancel this order?</span>
              <button
                onClick={(e) => { e.stopPropagation(); setConfirmingCancel(false) }}
                className="text-[10px] font-semibold text-[#6B7280] hover:text-[#1C1C1E] transition-colors"
              >
                No
              </button>
              <button
                onClick={(e) => { e.stopPropagation(); onCancel(order.id); setConfirmingCancel(false) }}
                className="text-[10px] font-semibold text-red-500 hover:text-red-700 transition-colors"
              >
                Yes, cancel
              </button>
            </div>
          ) : (
            <button
              onClick={(e) => { e.stopPropagation(); setConfirmingCancel(true) }}
              className="text-[10px] font-semibold text-red-400 hover:text-red-600 transition-colors"
            >
              Cancel order
            </button>
          )}
        </div>
      )}
    </div>
  )
}
