'use client'

import { useEffect } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Receipt, Banknote, LayoutGrid, Clock, ArrowRight, AlertTriangle } from 'lucide-react'
import Link from 'next/link'
import api from '@/lib/api'
import { createStompClient, TOPICS } from '@/lib/socket'
import type { Order, RestaurantTable } from '@/types'
import { OrderStatus } from '@/types'

// ── helpers ────────────────────────────────────────────────────────────────

const OVERDUE_MS = 15 * 60 * 1000

function isToday(dateStr: string): boolean {
  const d = new Date(dateStr)
  const now = new Date()
  return (
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate()
  )
}

function isOverdue(order: Order): boolean {
  return (
    order.status === OrderStatus.PREPARING &&
    Date.now() - new Date(order.createdAt).getTime() > OVERDUE_MS
  )
}

const STATUS_STYLES: Record<OrderStatus, string> = {
  [OrderStatus.PENDING]:   'bg-[#FEF3C7] text-[#D97706]',
  [OrderStatus.CONFIRMED]: 'bg-[#DBEAFE] text-[#1D4ED8]',
  [OrderStatus.PREPARING]: 'bg-[#EDE9FE] text-[#6D28D9]',
  [OrderStatus.READY]:     'bg-[#D1FAE5] text-[#059669]',
  [OrderStatus.SERVED]:    'bg-[#E5E7EB] text-[#6B7280]',
  [OrderStatus.COMPLETED]: 'bg-zinc-100 text-[#9CA3AF]',
  [OrderStatus.CANCELLED]: 'bg-red-100 text-red-600',
}

// ── page ───────────────────────────────────────────────────────────────────

export default function DashboardPage() {
  const queryClient = useQueryClient()

  const { data: orders = [] } = useQuery<Order[]>({
    queryKey: ['orders'],
    queryFn: () => api.get<Order[]>('/orders').then((r) => r.data),
  })

  const { data: tables = [] } = useQuery<RestaurantTable[]>({
    queryKey: ['tables'],
    queryFn: () => api.get<RestaurantTable[]>('/tables').then((r) => r.data),
  })

  // STOMP — invalidate React Query caches on order events
  useEffect(() => {
    const client = createStompClient()
    client.onConnect = () => {
      client.subscribe(TOPICS.ORDER_NEW, () => {
        queryClient.invalidateQueries({ queryKey: ['orders'] })
      })
      client.subscribe(TOPICS.ORDER_STATUS, () => {
        queryClient.invalidateQueries({ queryKey: ['orders'] })
        queryClient.invalidateQueries({ queryKey: ['tables'] })
      })
    }
    client.activate()
    return () => { client.deactivate() }
  }, [queryClient])

  // ── derived stats ────────────────────────────────────────────────────────
  const todaysOrders  = orders.filter((o) => isToday(o.createdAt))
  const revenueToday  = todaysOrders.reduce((sum, o) => sum + o.totalAmount, 0)
  const pendingCount  = orders.filter(
    (o) => o.status === OrderStatus.PENDING || o.status === OrderStatus.CONFIRMED,
  ).length
  const overdueCount  = orders.filter(isOverdue).length
  const occupiedCount = tables.filter((t) => t.isOccupied).length

  const liveOrders = [...orders]
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    .slice(0, 6)

  const occupancyPct = tables.length ? Math.round((occupiedCount / tables.length) * 100) : 0

  return (
    <div className="px-8 py-8">

      {/* ── Stat cards ─────────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <StatCard
          icon={<Receipt size={20} className="text-amber-700" />}
          label="Total Orders Today"
          value={todaysOrders.length.toString()}
          badge={{ text: `${orders.length} total`, cls: 'text-emerald-600 bg-emerald-50' }}
        />
        <StatCard
          icon={<Banknote size={20} className="text-amber-700" />}
          label="Revenue Today"
          value={`Rs. ${revenueToday.toLocaleString()}`}
          badge={{ text: 'Today', cls: 'text-emerald-600 bg-emerald-50' }}
        />
        <StatCard
          icon={<LayoutGrid size={20} className="text-amber-700" />}
          label="Active Tables"
          value={`${occupiedCount} / ${tables.length}`}
          badge={{ text: `${tables.length - occupiedCount} free`, cls: 'text-zinc-500' }}
        />
        <StatCard
          icon={<Clock size={20} className={overdueCount > 0 ? 'text-red-600' : 'text-amber-700'} />}
          label="Pending Orders"
          value={pendingCount.toString()}
          badge={
            overdueCount > 0
              ? { text: `${overdueCount} overdue`, cls: 'text-red-600 bg-red-50' }
              : { text: 'Needs attention', cls: 'text-amber-600 bg-amber-50' }
          }
        />
      </div>

      {/* ── Bottom section ──────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 lg:grid-cols-10 gap-8">

        {/* Live Orders — 60% */}
        <div className="lg:col-span-6 bg-white rounded-lg p-8 border border-[#E5E7EB]">
          <div className="flex justify-between items-center mb-6">
            <h4 className="text-base font-semibold text-zinc-900">Live Orders</h4>
            <Link
              href="/orders"
              className="flex items-center gap-1 text-[#D97706] text-xs font-bold uppercase tracking-widest hover:opacity-75 transition-opacity"
            >
              View All <ArrowRight size={12} />
            </Link>
          </div>

          {liveOrders.length === 0 ? (
            <p className="text-sm text-zinc-400 py-8 text-center">No orders yet</p>
          ) : (
            <div className="space-y-3">
              {liveOrders.map((order) => (
                <OrderRow key={order.id} order={order} />
              ))}
            </div>
          )}
        </div>

        {/* Tables mini-map — 40% */}
        <div className="lg:col-span-4 bg-white rounded-lg p-8 border border-[#E5E7EB]">
          <div className="flex justify-between items-center mb-6">
            <h4 className="text-base font-semibold text-zinc-900">Tables</h4>
            <div className="flex gap-4">
              <Legend color="bg-[#D97706]" label="Occupied" />
              <Legend color="bg-zinc-100 border border-[#E5E7EB]" label="Free" />
            </div>
          </div>

          {tables.length === 0 ? (
            <p className="text-sm text-zinc-400 py-8 text-center">No tables configured</p>
          ) : (
            <div className="grid grid-cols-4 gap-3">
              {[...tables]
                .sort((a, b) => a.tableNumber - b.tableNumber)
                .map((table) => (
                  <div
                    key={table.id}
                    className={[
                      'aspect-square rounded-md flex items-center justify-center font-bold text-sm',
                      table.isOccupied
                        ? 'bg-amber-50 border border-amber-200 text-amber-700'
                        : 'bg-zinc-50 border border-[#E5E7EB] text-zinc-400',
                    ].join(' ')}
                  >
                    {table.tableNumber}
                  </div>
                ))}
            </div>
          )}

          {tables.length > 0 && (
            <div className="mt-6 pt-5 border-t border-[#E5E7EB]">
              <div className="flex justify-between items-center text-xs mb-2">
                <span className="text-[#6B7280] font-medium uppercase tracking-wider">
                  Occupancy
                </span>
                <span className="font-bold text-zinc-900">{occupancyPct}%</span>
              </div>
              <div className="w-full bg-zinc-100 h-1.5 rounded-full overflow-hidden">
                <div
                  className="bg-[#D97706] h-full rounded-full transition-all duration-500"
                  style={{ width: `${occupancyPct}%` }}
                />
              </div>
            </div>
          )}
        </div>

      </div>
    </div>
  )
}

// ── sub-components ─────────────────────────────────────────────────────────

function StatCard({
  icon,
  label,
  value,
  badge,
}: {
  icon: React.ReactNode
  label: string
  value: string
  badge: { text: string; cls: string }
}) {
  return (
    <div className="bg-white p-6 rounded-lg border border-[#E5E7EB]">
      <div className="flex justify-between items-start mb-4">
        <div className="w-10 h-10 bg-amber-50 flex items-center justify-center rounded-md">
          {icon}
        </div>
        <span className={`text-[10px] font-bold px-2 py-1 rounded uppercase tracking-wide ${badge.cls}`}>
          {badge.text}
        </span>
      </div>
      <p className="text-[10px] font-bold text-[#6B7280] uppercase tracking-widest">{label}</p>
      <h3 className="text-2xl font-bold mt-1 text-zinc-900">{value}</h3>
    </div>
  )
}

function OrderRow({ order }: { order: Order }) {
  const time = new Date(order.createdAt).toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  })
  const tableLabel = order.table?.tableNumber ? `T${order.table.tableNumber}` : '—'
  const name       = order.customer?.name ?? 'Guest'
  const overdue    = isOverdue(order)

  return (
    <div className={`flex items-center justify-between p-4 rounded-md border ${
      overdue
        ? 'bg-red-50 border-l-[3px] border-l-red-500 border-y-red-200 border-r-red-200'
        : 'bg-zinc-50 border-[#E5E7EB]'
    }`}>
      <div className="flex items-center gap-4">
        <div className={`w-10 h-10 rounded-md flex items-center justify-center font-bold text-xs shrink-0 ${
          overdue ? 'bg-red-200 text-red-700' : 'bg-zinc-200 text-zinc-600'
        }`}>
          {tableLabel}
        </div>
        <div>
          <div className="flex items-center gap-2">
            <p className="font-semibold text-zinc-900 text-sm">{name}</p>
            {overdue && (
              <span className="flex items-center gap-1 text-[10px] font-bold text-red-600 uppercase tracking-wider">
                <AlertTriangle size={10} /> Overdue
              </span>
            )}
          </div>
          <p className="text-xs text-[#6B7280]">
            {order.items.length} item{order.items.length !== 1 ? 's' : ''} • {time}
          </p>
        </div>
      </div>
      <div className="flex items-center gap-5">
        <p className="font-bold text-zinc-900 text-sm">
          Rs. {order.totalAmount.toLocaleString()}
        </p>
        <span
          className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider ${STATUS_STYLES[order.status] ?? 'bg-zinc-100 text-zinc-500'}`}
        >
          {order.status}
        </span>
      </div>
    </div>
  )
}

function Legend({ color, label }: { color: string; label: string }) {
  return (
    <div className="flex items-center gap-1.5">
      <div className={`w-2 h-2 rounded-full ${color}`} />
      <span className="text-[10px] uppercase font-semibold text-[#6B7280]">{label}</span>
    </div>
  )
}
