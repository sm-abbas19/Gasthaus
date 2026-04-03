'use client'

import { useEffect, useState } from 'react'
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query'
import { UtensilsCrossed, LogOut } from 'lucide-react'
import { useRouter } from 'next/navigation'
import api from '@/lib/api'
import { createStompClient, TOPICS } from '@/lib/socket'
import { clearAuth } from '@/lib/auth'
import { OVERDUE_MS } from '@/lib/constants'
import type { Order } from '@/types'
import { OrderStatus } from '@/types'

// ── constants ──────────────────────────────────────────────────────────────
const MAX_VISIBLE_ITEMS = 3          // show first 3 items, "+ N more" after

// Kitchen only cares about these three statuses
const ACTIVE_STATUSES: OrderStatus[] = [
  OrderStatus.CONFIRMED,
  OrderStatus.PREPARING,
  OrderStatus.READY,
]

// ── helpers ────────────────────────────────────────────────────────────────

function elapsedMs(dateStr: string): number {
  return Date.now() - new Date(dateStr).getTime()
}

function formatTimer(ms: number): string {
  const totalSecs = Math.floor(Math.max(0, ms) / 1000)
  const mins = Math.floor(totalSecs / 60)
  const secs = totalSecs % 60
  return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
}

function formatClock(d: Date): string {
  return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })
}

function formatDate(d: Date): string {
  return d.toLocaleDateString('en-US', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
}

type CardState = 'new' | 'preparing' | 'overdue' | 'ready'

function getCardState(order: Order): CardState {
  if (order.status === OrderStatus.CONFIRMED) return 'new'
  if (order.status === OrderStatus.READY)     return 'ready'
  // PREPARING — check overdue
  if (elapsedMs(order.createdAt) > OVERDUE_MS) return 'overdue'
  return 'preparing'
}

const STATE_BORDER: Record<CardState, string> = {
  new:       'border-[#D97706]',
  preparing: 'border-[#3B82F6]',
  overdue:   'border-[#EF4444]',
  ready:     'border-[#22C55E]',
}

const STATE_ACCENT: Record<CardState, string> = {
  new:       'bg-[#D97706]',
  preparing: 'bg-[#3B82F6]',
  overdue:   'bg-[#EF4444]',
  ready:     'bg-[#22C55E]',
}

const STATE_TIMER_COLOR: Record<CardState, string> = {
  new:       'text-[#22C55E]',
  preparing: 'text-amber-400',
  overdue:   'text-[#EF4444]',
  ready:     'text-red-400',
}

// ── page ───────────────────────────────────────────────────────────────────

export default function KitchenPage() {
  const queryClient               = useQueryClient()
  const router                    = useRouter()
  const [now, setNow]             = useState(() => new Date())

  function handleLogout() {
    clearAuth()
    router.replace('/login')
  }

  // Tick every second for live timers + clock
  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), 1000)
    return () => clearInterval(id)
  }, [])

  const { data: orders = [] } = useQuery<Order[]>({
    queryKey: ['orders'],
    queryFn:  () => api.get<Order[]>('/orders').then((r) => r.data),
    refetchInterval: 30_000,
  })

  const { mutate: updateStatus } = useMutation({
    mutationFn: ({ id, status }: { id: string; status: OrderStatus }) =>
      api.patch(`/orders/${id}/status`, { status }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['orders'] }),
  })

  // STOMP
  useEffect(() => {
    const client = createStompClient()
    client.onConnect = () => {
      client.subscribe(TOPICS.ORDER_NEW,    () => queryClient.invalidateQueries({ queryKey: ['orders'] }))
      client.subscribe(TOPICS.ORDER_STATUS, () => queryClient.invalidateQueries({ queryKey: ['orders'] }))
    }
    client.activate()
    return () => { client.deactivate() }
  }, [queryClient])

  const activeOrders = orders
    .filter((o) => ACTIVE_STATUSES.includes(o.status))
    .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime())

  const activeCount = activeOrders.filter(
    (o) => o.status === OrderStatus.CONFIRMED || o.status === OrderStatus.PREPARING,
  ).length
  const readyCount = activeOrders.filter((o) => o.status === OrderStatus.READY).length

  return (
    <div className="bg-[#111111] text-white h-screen flex flex-col overflow-hidden">

      {/* ── Top bar ──────────────────────────────────────────────────── */}
      <header className="h-[56px] shrink-0 bg-[#1A1A1A] border-b border-[#2C2C2C] flex justify-between items-center px-8 z-50">
        {/* Brand */}
        <div className="flex items-center gap-3">
          <UtensilsCrossed size={20} className="text-amber-500" />
          <span className="text-white text-[14px] font-semibold tracking-[0.2em] uppercase">
            Gasthaus Kitchen
          </span>
        </div>

        {/* Clock */}
        <div className="flex items-center gap-4">
          <span className="text-white text-[18px] font-medium">{formatClock(now)}</span>
          <span className="text-[#6B7280] text-[13px] border-l border-[#2C2C2C] pl-4">
            {formatDate(now)}
          </span>
        </div>

        {/* Stats + Logout */}
        <div className="flex items-center gap-3">
          <div className="bg-[#2C2C2C] px-3 py-1 rounded-full">
            <span className="text-white text-[12px] font-bold">{activeCount} ACTIVE</span>
          </div>
          <div className="bg-[#052E16] px-3 py-1 rounded-full border border-[#22C55E]/30">
            <span className="text-[#22C55E] text-[12px] font-bold uppercase tracking-wider">
              {readyCount} READY
            </span>
          </div>
          <button
            onClick={handleLogout}
            title="Log out"
            className="ml-2 text-[#6B7280] hover:text-white transition-colors"
          >
            <LogOut size={16} />
          </button>
        </div>
      </header>

      {/* ── Card grid ────────────────────────────────────────────────── */}
      <main className="flex-1 p-4 grid grid-cols-4 auto-rows-fr gap-4 overflow-hidden">
        {activeOrders.length === 0 && (
          <div className="col-span-4 flex items-center justify-center text-[#2C2C2C] text-2xl font-bold uppercase tracking-widest">
            No active orders
          </div>
        )}
        {activeOrders.map((order) => (
          <KitchenCard
            key={order.id}
            order={order}
            now={now}
            onAction={(id, status) => updateStatus({ id, status })}
          />
        ))}
      </main>

      {/* ── Legend footer ────────────────────────────────────────────── */}
      <footer className="h-[36px] shrink-0 bg-[#1A1A1A] border-t border-[#2C2C2C] flex items-center justify-center px-8 relative">
        <div className="flex items-center gap-8">
          <LegendItem color="bg-[#D97706]" label="New Order" />
          <LegendItem color="bg-[#3B82F6]" label="In Progress" />
          <LegendItem color="bg-[#22C55E]" label="Ready to Collect" />
          <LegendItem color="bg-[#EF4444]" label="Overdue" />
        </div>
        <span className="absolute right-8 text-[#6B7280] text-[11px] font-bold tracking-widest uppercase">
          System Status: Operational
        </span>
      </footer>
    </div>
  )
}

// ── KitchenCard ────────────────────────────────────────────────────────────

function KitchenCard({
  order,
  now,
  onAction,
}: {
  order: Order
  now: Date
  onAction: (id: string, status: OrderStatus) => void
}) {
  const state       = getCardState(order)
  const elapsed     = now.getTime() - new Date(order.createdAt).getTime()
  const timerStr    = formatTimer(elapsed)
  const tableLabel  = order.table?.tableNumber ? `T${order.table.tableNumber}` : '—'
  const orderId     = order.id.slice(-3).toUpperCase()

  const visibleItems = order.items.slice(0, MAX_VISIBLE_ITEMS)
  const extraCount   = order.items.length - MAX_VISIBLE_ITEMS

  const isOverdue = state === 'overdue'

  return (
    <div className={`bg-[#1A1A1A] border-2 rounded-lg flex flex-col overflow-hidden ${STATE_BORDER[state]}`}>
      {/* Top accent bar */}
      <div className={`h-1 w-full ${STATE_ACCENT[state]} ${isOverdue ? 'animate-pulse' : ''}`} />

      <div className="p-4 flex flex-col h-full">
        {/* Table + timer row */}
        <div className="flex justify-between items-start mb-3">
          <span className="text-[44px] font-extrabold text-white leading-none">{tableLabel}</span>
          <div className="flex flex-col items-end">
            <span className={`font-bold text-xl ${isOverdue ? 'animate-pulse' : ''} ${STATE_TIMER_COLOR[state]}`}>
              {timerStr}
            </span>
            <span className="text-[10px] text-neutral-400 tracking-tighter uppercase mt-0.5">
              #{orderId}
            </span>
          </div>
        </div>

        {/* Items */}
        <div className="flex-1 space-y-2.5 overflow-hidden">
          {visibleItems.map((item) => (
            <div key={item.id} className="flex gap-3 items-baseline">
              <span className="text-white font-bold text-[18px] shrink-0">{item.quantity}x</span>
              <span className="text-[#9CA3AF] font-normal text-[16px] leading-tight truncate">
                {item.menuItem.name}
              </span>
            </div>
          ))}
          {extraCount > 0 && (
            <p className="text-neutral-400 font-semibold uppercase text-[10px] tracking-widest pt-1">
              +{extraCount} more item{extraCount > 1 ? 's' : ''}
            </p>
          )}
        </div>

        {/* Special instructions */}
        {order.notes && (
          <div className="mt-2 px-2 py-1.5 bg-amber-950/40 border border-amber-500/30 rounded text-[11px] text-amber-400 leading-relaxed">
            <span className="font-bold">Note: </span>{order.notes}
          </div>
        )}

        {/* Action button */}
        <div className="mt-3">
          <ActionButton state={state} orderId={order.id} onAction={onAction} />
        </div>
      </div>
    </div>
  )
}

// ── ActionButton ───────────────────────────────────────────────────────────

function ActionButton({
  state,
  orderId,
  onAction,
}: {
  state: CardState
  orderId: string
  onAction: (id: string, status: OrderStatus) => void
}) {
  if (state === 'ready') {
    return (
      <button
        disabled
        className="w-full h-[44px] bg-[#1C1C1E] border border-[#2C2C2C] text-[#6B7280] font-bold rounded uppercase tracking-widest text-sm flex items-center justify-center gap-2 cursor-default"
      >
        Collected ✓
      </button>
    )
  }

  if (state === 'new') {
    return (
      <button
        onClick={() => onAction(orderId, OrderStatus.PREPARING)}
        className="w-full h-[44px] bg-[#D97706] text-white font-bold rounded hover:bg-[#B45309] active:scale-[0.98] transition-all uppercase tracking-widest text-sm"
      >
        Start Preparing
      </button>
    )
  }

  // preparing or overdue
  return (
    <button
      onClick={() => onAction(orderId, OrderStatus.READY)}
      className="w-full h-[44px] bg-[#3B82F6] text-white font-bold rounded hover:bg-[#2563EB] active:scale-[0.98] transition-all uppercase tracking-widest text-sm"
    >
      Mark Ready
    </button>
  )
}

// ── LegendItem ─────────────────────────────────────────────────────────────

function LegendItem({ color, label }: { color: string; label: string }) {
  return (
    <div className="flex items-center gap-2">
      <span className={`w-2.5 h-2.5 rounded-full ${color}`} />
      <span className="text-[#9CA3AF] text-[11px] font-semibold tracking-widest uppercase">{label}</span>
    </div>
  )
}
