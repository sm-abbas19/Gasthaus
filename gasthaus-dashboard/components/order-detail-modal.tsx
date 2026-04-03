'use client'

import { useEffect, useState } from 'react'
import { X } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import api from '@/lib/api'
import type { Order } from '@/types'
import { OrderStatus } from '@/types'

const CANCELLABLE = new Set([OrderStatus.PENDING, OrderStatus.CONFIRMED])

// Status label map — same values used elsewhere in the app
const STATUS_LABEL: Record<OrderStatus, string> = {
  [OrderStatus.PENDING]:   'Pending',
  [OrderStatus.CONFIRMED]: 'Confirmed',
  [OrderStatus.PREPARING]: 'Preparing',
  [OrderStatus.READY]:     'Ready',
  [OrderStatus.SERVED]:    'Served',
  [OrderStatus.PAID]:      'Paid',
  [OrderStatus.COMPLETED]: 'Completed',
  [OrderStatus.CANCELLED]: 'Cancelled',
}

const STATUS_DOT: Record<OrderStatus, string> = {
  [OrderStatus.PENDING]:   'bg-amber-400',
  [OrderStatus.CONFIRMED]: 'bg-blue-400',
  [OrderStatus.PREPARING]: 'bg-purple-400',
  [OrderStatus.READY]:     'bg-emerald-400',
  [OrderStatus.SERVED]:    'bg-blue-300',
  [OrderStatus.PAID]:      'bg-zinc-400',
  [OrderStatus.COMPLETED]: 'bg-zinc-400',
  [OrderStatus.CANCELLED]: 'bg-red-400',
}

function formatDateTime(iso: string) {
  const d = new Date(iso)
  return d.toLocaleString('en-US', {
    month: 'short', day: 'numeric', year: 'numeric',
    hour: 'numeric', minute: '2-digit', hour12: true,
  })
}

function formatTime(iso: string) {
  return new Date(iso).toLocaleTimeString('en-US', {
    hour: 'numeric', minute: '2-digit', second: '2-digit', hour12: true,
  })
}

export default function OrderDetailModal({
  orderId,
  onClose,
}: {
  orderId: string
  onClose: () => void
}) {
  const queryClient = useQueryClient()
  const [order, setOrder] = useState<Order | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [cancelConfirming, setCancelConfirming] = useState(false)
  const [cancelError, setCancelError] = useState<string | null>(null)

  useEffect(() => {
    api.get<Order>(`/orders/${orderId}`)
      .then((r) => setOrder(r.data))
      .catch(() => setError('Failed to load order details.'))
      .finally(() => setLoading(false))
  }, [orderId])

  async function handleCancel() {
    setCancelError(null)
    try {
      await api.patch(`/orders/${orderId}/status`, { status: OrderStatus.CANCELLED })
      queryClient.invalidateQueries({ queryKey: ['orders'] })
      onClose()
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Failed to cancel order.'
      setCancelError(msg)
      setCancelConfirming(false)
    }
  }

  // Close on backdrop click
  function handleBackdrop(e: React.MouseEvent<HTMLDivElement>) {
    if (e.target === e.currentTarget) onClose()
  }

  // Close on Escape
  useEffect(() => {
    function onKey(e: KeyboardEvent) { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-[2px]"
      onClick={handleBackdrop}
    >
      <div className="relative bg-white rounded-xl shadow-xl w-full max-w-lg mx-4 max-h-[90vh] flex flex-col">

        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-[#E5E7EB] shrink-0">
          <div>
            <p className="text-[10px] font-bold text-[#9CA3AF] uppercase tracking-widest">Order Details</p>
            <h2 className="text-base font-bold text-[#1C1C1E] mt-0.5 font-mono tracking-wide">
              {loading ? '…' : (order?.orderNumber ? `#${order.orderNumber}` : `#${order?.id.replace(/-/g, '').slice(0, 8).toUpperCase()}`)}
            </h2>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center rounded-full hover:bg-zinc-100 transition-colors"
          >
            <X size={16} className="text-[#6B7280]" />
          </button>
        </div>

        {/* Body — scrollable */}
        <div className="overflow-y-auto flex-1 px-6 py-5 space-y-6">

          {loading && (
            <div className="flex items-center justify-center py-16">
              <div className="w-6 h-6 border-2 border-[#D97706] border-t-transparent rounded-full animate-spin" />
            </div>
          )}

          {error && (
            <p className="text-sm text-red-500 text-center py-8">{error}</p>
          )}

          {order && (
            <>
              {/* Meta row */}
              <div className="grid grid-cols-3 gap-4">
                <MetaCell label="Table" value={order.table?.tableNumber ? `Table ${order.table.tableNumber}` : '—'} />
                <MetaCell label="Customer" value={order.customer?.name ?? 'Guest'} />
                <MetaCell label="Placed" value={formatDateTime(order.createdAt)} small />
              </div>

              {/* Special instructions */}
              {order.notes && (
                <div className="px-4 py-3 bg-[#FEF3C7] rounded-lg border border-amber-200">
                  <p className="text-[10px] font-bold text-[#92400E] uppercase tracking-widest mb-1">Special Instructions</p>
                  <p className="text-sm text-[#92400E]">{order.notes}</p>
                </div>
              )}

              {/* Items */}
              <section>
                <p className="text-[10px] font-bold text-[#9CA3AF] uppercase tracking-widest mb-3">Items</p>
                <div className="border border-[#E5E7EB] rounded-lg overflow-hidden">
                  {order.items.map((item, i) => (
                    <div key={item.id}>
                      {i > 0 && <div className="border-t border-[#F3F4F6]" />}
                      <div className="px-4 py-3">
                        <div className="flex justify-between items-start">
                          <div className="flex items-center gap-2">
                            <span className="text-[11px] font-bold text-[#D97706] bg-amber-50 px-1.5 py-0.5 rounded">
                              ×{item.quantity}
                            </span>
                            <span className="text-sm font-medium text-[#1C1C1E]">{item.menuItem.name}</span>
                          </div>
                          <span className="text-sm font-bold text-[#1C1C1E]">
                            Rs. {(item.unitPrice * item.quantity).toLocaleString()}
                          </span>
                        </div>
                        {item.notes && (
                          <p className="mt-1.5 text-[11px] text-[#92400E] bg-[#FEF3C7] px-2 py-1 rounded">
                            Note: {item.notes}
                          </p>
                        )}
                      </div>
                    </div>
                  ))}
                  <div className="border-t border-[#E5E7EB] bg-zinc-50 px-4 py-3 flex justify-between items-center">
                    <span className="text-sm font-bold text-[#1C1C1E]">Total</span>
                    <span className="text-base font-bold text-[#D97706]">
                      Rs. {order.totalAmount.toLocaleString()}
                    </span>
                  </div>
                </div>
              </section>

              {/* Status timeline */}
              <section>
                <p className="text-[10px] font-bold text-[#9CA3AF] uppercase tracking-widest mb-3">Status History</p>
                {order.statusHistory && order.statusHistory.length > 0 ? (
                  <div className="space-y-0">
                    {order.statusHistory.map((h, i) => {
                      const isLast = i === order.statusHistory!.length - 1
                      return (
                        <div key={h.id} className="flex gap-3">
                          {/* Dot + line */}
                          <div className="flex flex-col items-center">
                            <div className={`w-2.5 h-2.5 rounded-full mt-1 shrink-0 ${STATUS_DOT[h.status] ?? 'bg-zinc-300'}`} />
                            {!isLast && <div className="w-px flex-1 bg-[#E5E7EB] mt-1" />}
                          </div>
                          {/* Label */}
                          <div className={`pb-4 ${isLast ? 'pb-0' : ''}`}>
                            <p className="text-sm font-semibold text-[#1C1C1E]">{STATUS_LABEL[h.status]}</p>
                            <p className="text-[11px] text-[#9CA3AF]">{formatTime(h.changedAt)}</p>
                          </div>
                        </div>
                      )
                    })}
                  </div>
                ) : (
                  <p className="text-xs text-[#9CA3AF]">No history recorded (pre-dates this feature).</p>
                )}
              </section>

              {/* Cancel section */}
              <section className="border-t border-[#E5E7EB] pt-4">
                {CANCELLABLE.has(order.status) ? (
                  cancelConfirming ? (
                    <div className="space-y-3">
                      <p className="text-sm text-[#1C1C1E]">Are you sure you want to cancel this order?</p>
                      {cancelError && (
                        <p className="text-xs text-red-500">{cancelError}</p>
                      )}
                      <div className="flex gap-2">
                        <button
                          onClick={() => setCancelConfirming(false)}
                          className="flex-1 px-4 py-2 text-xs font-semibold rounded-lg border border-[#E5E7EB] text-[#6B7280] hover:bg-zinc-50 transition-colors"
                        >
                          Keep order
                        </button>
                        <button
                          onClick={handleCancel}
                          className="flex-1 px-4 py-2 text-xs font-semibold rounded-lg bg-red-50 border border-red-200 text-red-600 hover:bg-red-100 transition-colors"
                        >
                          Yes, cancel
                        </button>
                      </div>
                    </div>
                  ) : (
                    <button
                      onClick={() => setCancelConfirming(true)}
                      className="text-xs font-semibold text-red-400 hover:text-red-600 transition-colors"
                    >
                      Cancel this order
                    </button>
                  )
                ) : (
                  order.status !== OrderStatus.CANCELLED && order.status !== OrderStatus.PAID && order.status !== OrderStatus.COMPLETED && (
                    <p className="text-xs text-[#9CA3AF]">
                      This order cannot be cancelled — preparation has already begun.
                      Please speak to a manager if there is an issue.
                    </p>
                  )
                )}
              </section>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

function MetaCell({ label, value, small }: { label: string; value: string; small?: boolean }) {
  return (
    <div>
      <p className="text-[10px] font-bold text-[#9CA3AF] uppercase tracking-widest mb-1">{label}</p>
      <p className={`font-semibold text-[#1C1C1E] ${small ? 'text-xs' : 'text-sm'}`}>{value}</p>
    </div>
  )
}
