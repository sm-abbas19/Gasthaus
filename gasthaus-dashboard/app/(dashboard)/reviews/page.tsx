'use client'

import { useState, useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Star } from 'lucide-react'
import api from '@/lib/api'
import type { Review } from '@/types'

// ── helpers ────────────────────────────────────────────────────────────────

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime()
  const mins  = Math.floor(diff / 60_000)
  if (mins < 60)  return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24)   return `${hrs} hour${hrs > 1 ? 's' : ''} ago`
  const days = Math.floor(hrs / 24)
  if (days === 1) return 'Yesterday'
  return `${days} days ago`
}

function initials(name?: string): string {
  if (!name) return '?'
  return name.split(' ').map((n) => n[0]).join('').slice(0, 2).toUpperCase()
}

// Deterministic avatar background colour from initials — amber/grey palette only
const AVATAR_COLORS = [
  'bg-[#FEF3C7] text-[#92400E]',
  'bg-[#FFF7ED] text-[#D97706]',
  'bg-[#F3F4F6] text-[#374151]',
  'bg-[#E5E7EB] text-[#6B7280]',
  'bg-[#FEF3C7] text-[#78350F]',
  'bg-[#F9FAFB] text-[#4B5563]',
]

function avatarColor(name?: string): string {
  const code = (name ?? '').split('').reduce((acc, c) => acc + c.charCodeAt(0), 0)
  return AVATAR_COLORS[code % AVATAR_COLORS.length]
}

// ── StarRow ────────────────────────────────────────────────────────────────

function StarRow({ rating, size = 14 }: { rating: number; size?: number }) {
  return (
    <div className="flex items-center gap-0.5">
      {[1, 2, 3, 4, 5].map((n) => (
        <Star
          key={n}
          size={size}
          className={n <= rating ? 'text-[#D97706] fill-[#D97706]' : 'text-[#D1D5DB]'}
        />
      ))}
    </div>
  )
}

// ── page ───────────────────────────────────────────────────────────────────

export default function ReviewsPage() {
  const [itemFilter,   setItemFilter]   = useState('all')
  const [ratingFilter, setRatingFilter] = useState('all')
  const [dateFilter,   setDateFilter]   = useState('30')   // days
  const [sortLatest,   setSortLatest]   = useState(true)

  const { data: reviews = [] } = useQuery<Review[]>({
    queryKey: ['reviews'],
    queryFn:  () => api.get<Review[]>('/reviews').then((r) => r.data),
  })

  // ── derived data ──────────────────────────────────────────────────────

  // Unique menu items from reviews
  const menuItems = useMemo(() => {
    const map = new Map<string, string>()
    reviews.forEach((r) => {
      if (r.menuItem) map.set(r.menuItem.id, r.menuItem.name)
    })
    return Array.from(map.entries()).map(([id, name]) => ({ id, name }))
  }, [reviews])

  // Filter
  const filtered = useMemo(() => {
    const cutoff = dateFilter === 'all'
      ? null
      : new Date(Date.now() - Number(dateFilter) * 24 * 60 * 60 * 1000)

    return reviews.filter((r) => {
      if (itemFilter !== 'all'   && r.menuItem?.id !== itemFilter)          return false
      if (ratingFilter !== 'all' && r.rating !== Number(ratingFilter))      return false
      if (cutoff && new Date(r.createdAt) < cutoff)                         return false
      return true
    })
  }, [reviews, itemFilter, ratingFilter, dateFilter])

  const sorted = [...filtered].sort((a, b) => {
    const diff = new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    return sortLatest ? diff : -diff
  })

  // Aggregate stats (from ALL reviews, not filtered)
  const totalReviews = reviews.length
  const avgRating    = totalReviews
    ? parseFloat((reviews.reduce((s, r) => s + r.rating, 0) / totalReviews).toFixed(1))
    : 0

  const distrib = useMemo(() => {
    const d: Record<number, number> = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 }
    reviews.forEach((r) => { d[r.rating] = (d[r.rating] ?? 0) + 1 })
    return d
  }, [reviews])

  // Item performance: avg rating per menu item
  const itemPerf = useMemo(() => {
    const map = new Map<string, { name: string; sum: number; count: number }>()
    reviews.forEach((r) => {
      if (!r.menuItem) return
      const existing = map.get(r.menuItem.id) ?? { name: r.menuItem.name, sum: 0, count: 0 }
      existing.sum   += r.rating
      existing.count += 1
      map.set(r.menuItem.id, existing)
    })
    return Array.from(map.values())
      .map((v) => ({ name: v.name, avg: parseFloat((v.sum / v.count).toFixed(1)) }))
      .sort((a, b) => b.avg - a.avg)
      .slice(0, 5)
  }, [reviews])

  // Sentiment: positive ≥4, neutral = 3, negative ≤2
  const positive = reviews.filter((r) => r.rating >= 4).length
  const neutral  = reviews.filter((r) => r.rating === 3).length
  const negative = reviews.filter((r) => r.rating <= 2).length

  return (
    <div className="px-8 py-8 max-w-7xl mx-auto">
      <div className="flex gap-10">

        {/* ── Left: reviews list (65%) ─────────────────────────────── */}
        <section className="flex-1 space-y-6 min-w-0">

          {/* Filter bar */}
          <div className="bg-white border border-[#E5E7EB] rounded-lg p-4 flex items-center justify-between gap-4">
            <div className="flex items-center gap-3 flex-wrap">
              <select
                value={itemFilter}
                onChange={(e) => setItemFilter(e.target.value)}
                className="bg-[#F9F9F7] text-sm font-medium border-none focus:ring-0 text-[#6B7280] cursor-pointer py-1.5 px-3 rounded-lg"
              >
                <option value="all">All Items</option>
                {menuItems.map((item) => (
                  <option key={item.id} value={item.id}>{item.name}</option>
                ))}
              </select>

              <select
                value={ratingFilter}
                onChange={(e) => setRatingFilter(e.target.value)}
                className="bg-[#F9F9F7] text-sm font-medium border-none focus:ring-0 text-[#6B7280] cursor-pointer py-1.5 px-3 rounded-lg"
              >
                <option value="all">All Ratings</option>
                {[5, 4, 3, 2, 1].map((n) => (
                  <option key={n} value={n}>{n} Star{n > 1 ? 's' : ''}</option>
                ))}
              </select>

              <select
                value={dateFilter}
                onChange={(e) => setDateFilter(e.target.value)}
                className="bg-[#F9F9F7] text-sm font-medium border-none focus:ring-0 text-[#6B7280] cursor-pointer py-1.5 px-3 rounded-lg"
              >
                <option value="7">Last 7 Days</option>
                <option value="30">Last 30 Days</option>
                <option value="all">All Time</option>
              </select>
            </div>

            <div className="flex items-center gap-5 shrink-0">
              <span className="text-xs text-[#9CA3AF] font-medium whitespace-nowrap">
                {sorted.length} review{sorted.length !== 1 ? 's' : ''}
              </span>
              <button
                onClick={() => setSortLatest((v) => !v)}
                className="flex items-center gap-1 text-[#D97706] text-xs font-bold uppercase tracking-widest hover:opacity-75 transition-opacity"
              >
                {sortLatest ? 'Latest First' : 'Oldest First'}
              </button>
            </div>
          </div>

          {/* Cards */}
          {sorted.length === 0 ? (
            <div className="bg-white border border-[#E5E7EB] rounded-lg p-12 text-center text-[#9CA3AF] text-sm">
              No reviews match the current filters.
            </div>
          ) : (
            <div className="space-y-4">
              {sorted.map((review) => (
                <ReviewCard key={review.id} review={review} />
              ))}
            </div>
          )}
        </section>

        {/* ── Right: overview (35%) ─────────────────────────────────── */}
        <aside className="w-[300px] shrink-0 space-y-6">

          {/* Rating overview */}
          <div className="bg-white border border-[#E5E7EB] rounded-lg p-7">
            <h3 className="text-[10px] font-bold text-[#6B7280] uppercase tracking-[0.15em] mb-5">
              Rating Overview
            </h3>
            <div className="flex items-end gap-4 mb-6">
              <span className="text-5xl font-light text-zinc-900 leading-none">{avgRating}</span>
              <div className="pb-1">
                <StarRow rating={Math.round(avgRating)} size={16} />
                <p className="text-xs text-[#9CA3AF] mt-1">
                  {totalReviews} review{totalReviews !== 1 ? 's' : ''}
                </p>
              </div>
            </div>
            <div className="space-y-3">
              {[5, 4, 3, 2, 1].map((star) => {
                const count = distrib[star] ?? 0
                const pct   = totalReviews ? Math.round((count / totalReviews) * 100) : 0
                return (
                  <div key={star} className="flex items-center gap-3">
                    <span className="text-[10px] font-bold text-[#9CA3AF] w-5 shrink-0">{star}★</span>
                    <div className="flex-1 h-2 bg-[#F3F4F6] rounded-full overflow-hidden">
                      <div
                        className="h-full bg-amber-500 rounded-full transition-all duration-500"
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                    <span className="text-[10px] font-bold text-zinc-900 w-6 text-right shrink-0">
                      {count}
                    </span>
                  </div>
                )
              })}
            </div>
          </div>

          {/* Item performance */}
          {itemPerf.length > 0 && (
            <div className="bg-white border border-[#E5E7EB] rounded-lg p-7">
              <h3 className="text-[10px] font-bold text-[#6B7280] uppercase tracking-[0.15em] mb-5">
                Item Performance
              </h3>
              <div className="space-y-4">
                {itemPerf.map((item) => (
                  <div key={item.name} className="flex items-center justify-between">
                    <span className="text-sm font-medium text-zinc-900 truncate mr-3">{item.name}</span>
                    <div className="flex items-center gap-1.5 shrink-0">
                      <Star size={13} className="text-amber-500 fill-amber-500" />
                      <span className="text-sm font-bold text-zinc-900">{item.avg}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Sentiment */}
          {totalReviews > 0 && (
            <div className="bg-white border border-[#E5E7EB] rounded-lg p-7">
              <h3 className="text-[10px] font-bold text-[#6B7280] uppercase tracking-[0.15em] mb-5">
                Sentiment
              </h3>
              <div className="flex items-center gap-2 flex-wrap">
                <span className="bg-[#FEF3C7] text-[#78350F] text-[11px] font-semibold px-3 py-1 rounded">
                  {positive} Positive
                </span>
                <span className="bg-[#F3F4F6] text-[#6B7280] text-[11px] font-semibold px-3 py-1 rounded">
                  {neutral} Neutral
                </span>
                <span className="bg-[#E5E7EB] text-[#6B7280] text-[11px] font-semibold px-3 py-1 rounded">
                  {negative} Negative
                </span>
              </div>
            </div>
          )}

          {/* Quick insight */}
          {negative > 0 && (
            <div className="bg-amber-50 rounded-lg p-5 border border-amber-100">
              <h4 className="text-[10px] font-bold text-[#D97706] uppercase tracking-widest mb-2">
                Quick Insight
              </h4>
              <p className="text-[11px] leading-relaxed text-[#6B7280]">
                {Math.round((negative / totalReviews) * 100)}% of reviews are negative (≤2 stars).{' '}
                {negative >= 3 ? 'Consider reviewing kitchen quality and service speed.' : 'Keep an eye on low-rated items.'}
              </p>
            </div>
          )}
        </aside>
      </div>
    </div>
  )
}

// ── ReviewCard ─────────────────────────────────────────────────────────────

// Returns a consistent 8-char uppercase display ID from a raw UUID string.
function displayOrderId(rawId?: string): string {
  if (!rawId) return '—'
  return `#${rawId.replace(/-/g, '').slice(0, 8).toUpperCase()}`
}

function ReviewCard({ review }: { review: Review }) {
  const name    = review.customer?.name
  const low     = review.rating <= 2
  const orderId = displayOrderId(review.orderId)

  return (
    <div
      className={`bg-white rounded-lg p-6 transition-all ${
        low
          ? 'border-l-[3px] border-l-red-500 border-y border-r border-[#E5E7EB]'
          : 'border border-[#E5E7EB]'
      }`}
    >
      {/* Header */}
      <div className="flex justify-between items-start mb-4">
        <div className="flex items-center gap-3">
          <div
            className={`w-11 h-11 rounded-full flex items-center justify-center font-bold text-sm shrink-0 ${avatarColor(name)}`}
          >
            {initials(name)}
          </div>
          <div>
            <h4 className="font-bold text-zinc-900 text-sm">{name ?? 'Anonymous'}</h4>
            <div className="flex items-center gap-2 mt-1">
              {review.menuItem && (
                <span className="text-[10px] bg-[#F3F4F6] px-2 py-0.5 rounded text-[#6B7280] font-bold uppercase tracking-wider">
                  {review.menuItem.name}
                </span>
              )}
              <StarRow rating={review.rating} size={12} />
            </div>
          </div>
        </div>
        <span className="text-xs text-[#9CA3AF] font-medium shrink-0 ml-4">
          {timeAgo(review.createdAt)}
        </span>
      </div>

      {/* Comment */}
      {review.comment && (
        <p className="text-[#6B7280] text-sm leading-relaxed mb-5">{review.comment}</p>
      )}

      {/* Footer */}
      <div className="flex items-center justify-between border-t border-[#F4F4F2] pt-4">
        <span className="text-[10px] font-mono text-[#9CA3AF]">Order #{orderId}</span>
      </div>
    </div>
  )
}
