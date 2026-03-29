'use client'

import { useState, useMemo, useEffect, useRef } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Sparkles, ChevronRight } from 'lucide-react'
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer,
  AreaChart, Area,
} from 'recharts'
import api from '@/lib/api'
import type { Order, Review } from '@/types'

// ── helpers ────────────────────────────────────────────────────────────────

const DAY_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

function startOf(period: 'today' | 'week' | 'month'): Date {
  const now = new Date()
  if (period === 'today') {
    return new Date(now.getFullYear(), now.getMonth(), now.getDate())
  }
  if (period === 'week') {
    const d = new Date(now)
    d.setDate(d.getDate() - 6)
    d.setHours(0, 0, 0, 0)
    return d
  }
  return new Date(now.getFullYear(), now.getMonth(), 1)
}

function inPeriod(dateStr: string, period: 'today' | 'week' | 'month'): boolean {
  return new Date(dateStr) >= startOf(period)
}

// ── page ───────────────────────────────────────────────────────────────────

// Auto-generate once per tab session — survives navigation but not tab close
let _sessionGenerated = false

export default function InsightsPage() {
  const [period, setPeriod]   = useState<'today' | 'week' | 'month'>('today')
  const [aiText, setAiText]   = useState<string | null>(null)
  const [aiLoading, setAiLoading] = useState(false)
  const [aiError, setAiError] = useState(false)

  const { data: orders = [] } = useQuery<Order[]>({
    queryKey: ['orders'],
    queryFn:  () => api.get<Order[]>('/orders').then((r) => r.data),
  })

  const { data: reviews = [] } = useQuery<Review[]>({
    queryKey: ['reviews'],
    queryFn:  () => api.get<Review[]>('/reviews').then((r) => r.data),
  })

  // ── period-filtered orders ────────────────────────────────────────────
  const periodOrders = useMemo(
    () => orders.filter((o) => inPeriod(o.createdAt, period)),
    [orders, period],
  )

  const totalRevenue  = periodOrders.reduce((s, o) => s + o.totalAmount, 0)
  const avgOrderValue = periodOrders.length ? totalRevenue / periodOrders.length : 0
  const avgRating     = reviews.length
    ? reviews.reduce((s, r) => s + r.rating, 0) / reviews.length
    : 0
  const avgFulfillmentMin = useMemo(() => {
    const served = periodOrders.filter(
      (o) => o.status === 'SERVED' || o.status === 'COMPLETED',
    )
    if (!served.length) return null
    const totalMs = served.reduce(
      (s, o) => s + (new Date(o.updatedAt).getTime() - new Date(o.createdAt).getTime()),
      0,
    )
    return Math.round(totalMs / served.length / 60_000)
  }, [periodOrders])

  // ── hourly orders chart (today's orders by hour) ──────────────────────
  const hourlyData = useMemo(() => {
    const todayOrders = orders.filter((o) => inPeriod(o.createdAt, 'today'))
    const hours: { hour: string; orders: number }[] = []
    for (let h = 9; h <= 21; h++) {
      const label   = h <= 12 ? `${h}AM` : `${h - 12}PM`
      const count   = todayOrders.filter((o) => new Date(o.createdAt).getHours() === h).length
      hours.push({ hour: label, orders: count })
    }
    return hours
  }, [orders])

  // ── daily revenue chart (last 7 days) ─────────────────────────────────
  const dailyRevenueData = useMemo(() => {
    const result: { day: string; revenue: number }[] = []
    for (let i = 6; i >= 0; i--) {
      const d   = new Date()
      d.setDate(d.getDate() - i)
      const ymd = d.toDateString()
      const rev = orders
        .filter((o) => new Date(o.createdAt).toDateString() === ymd)
        .reduce((s, o) => s + o.totalAmount, 0)
      result.push({ day: DAY_LABELS[d.getDay()], revenue: rev })
    }
    return result
  }, [orders])

  // ── top items by order count ───────────────────────────────────────────
  const topItems = useMemo(() => {
    const map = new Map<string, number>()
    periodOrders.forEach((o) =>
      o.items.forEach((i) => {
        const name = i.menuItem.name
        map.set(name, (map.get(name) ?? 0) + i.quantity)
      }),
    )
    const sorted = Array.from(map.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 6)
    const max = sorted[0]?.[1] ?? 1
    return sorted.map(([name, count]) => ({ name, count, pct: Math.round((count / max) * 100) }))
  }, [periodOrders])

  // ── Auto-generate once per session after data loads ──────────────────
  const autoFired = useRef(false)
  useEffect(() => {
    if (autoFired.current || _sessionGenerated || orders.length === 0) return
    autoFired.current = true
    _sessionGenerated = true
    generateInsights()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [orders])

  // ── AI insights ───────────────────────────────────────────────────────
  async function generateInsights() {
    setAiLoading(true)
    setAiError(false)
    try {
      const res = await api.post('/ai/insights', {
        period,
        totalOrders:   periodOrders.length,
        totalRevenue,
        avgOrderValue: Math.round(avgOrderValue),
        avgRating:     parseFloat(avgRating.toFixed(1)),
        topItems:      topItems.slice(0, 5).map((i) => ({ name: i.name, count: i.count })),
        complaints:    reviews
          .filter((r) => r.rating <= 2 && r.comment)
          .map((r) => r.comment as string)
          .slice(0, 5),
      })
      const data = res.data
      setAiText(
        typeof data === 'string'
          ? data
          : data?.insights ?? data?.insight ?? data?.message ?? data?.response ?? JSON.stringify(data),
      )
    } catch {
      setAiError(true)
      setAiText('Unable to generate insights at this time. Please check the AI service.')
    } finally {
      setAiLoading(false)
    }
  }

  return (
    <div className="px-8 py-8 max-w-7xl mx-auto space-y-6">

      {/* ── Period toggle + Generate button ─────────────────────────── */}
      <div className="flex items-center justify-between">
        <div className="flex bg-[#E5E7EB]/50 p-1 rounded-lg">
          {(['today', 'week', 'month'] as const).map((p) => (
            <button
              key={p}
              onClick={() => setPeriod(p)}
              className={`px-4 py-1.5 text-xs font-semibold rounded-md transition-all capitalize ${
                period === p ? 'bg-[#1C1C1E] text-white shadow-sm' : 'text-[#6B7280] hover:text-zinc-900'
              }`}
            >
              {p === 'today' ? 'Today' : p === 'week' ? 'This Week' : 'This Month'}
            </button>
          ))}
        </div>

        <button
          onClick={generateInsights}
          disabled={aiLoading}
          className="flex items-center gap-2 bg-[#D97706] text-white px-4 py-2 rounded-lg text-xs font-semibold hover:bg-[#B45309] transition-colors disabled:opacity-60"
        >
          <Sparkles size={14} />
          {aiLoading ? 'Generating…' : 'Generate Insights'}
        </button>
      </div>

      {/* ── AI Insights card ─────────────────────────────────────────── */}
      <section className="bg-white border border-[#E5E7EB] border-l-[3px] border-l-[#D97706] p-5 rounded-lg">
        <div className="flex justify-between items-start mb-3">
          <div className="flex items-center gap-2 text-[#D97706]">
            <Sparkles size={16} />
            <h2 className="font-bold text-sm uppercase tracking-wider">AI Insights</h2>
          </div>
          <span className="bg-[#F3F4F6] text-[#6B7280] px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-tight">
            Powered by Gemini
          </span>
        </div>

        {aiText ? (
          <p className={`text-sm leading-relaxed mb-4 ${aiError ? 'text-red-600' : 'text-zinc-700'}`}>
            {aiText}
          </p>
        ) : (
          <p className="text-sm text-[#9CA3AF] leading-relaxed mb-4">
            Click <strong className="text-[#D97706]">Generate Insights</strong>{' '}to get an AI-powered
            summary of your restaurant&apos;s performance — orders, revenue trends, and recommendations.
          </p>
        )}
      </section>

      {/* ── Charts row ───────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">

        {/* Hourly Orders */}
        <ChartCard title="Hourly Orders">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={hourlyData} margin={{ top: 0, right: 0, bottom: 0, left: -20 }}>
              <XAxis
                dataKey="hour"
                tick={{ fontSize: 9, fill: '#9CA3AF' }}
                tickLine={false}
                axisLine={false}
                interval={3}
              />
              <YAxis hide />
              <Tooltip
                contentStyle={{ fontSize: 11, borderRadius: 6, border: '1px solid #E5E7EB' }}
                cursor={{ fill: '#F9F9F7' }}
              />
              <Bar dataKey="orders" fill="#D97706" radius={[3, 3, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        {/* Revenue this week */}
        <ChartCard title="Revenue This Week">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={dailyRevenueData} margin={{ top: 4, right: 0, bottom: 0, left: -20 }}>
              <defs>
                <linearGradient id="revGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%"  stopColor="#D97706" stopOpacity={0.15} />
                  <stop offset="95%" stopColor="#D97706" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis
                dataKey="day"
                tick={{ fontSize: 9, fill: '#9CA3AF' }}
                tickLine={false}
                axisLine={false}
              />
              <YAxis hide />
              <Tooltip
                contentStyle={{ fontSize: 11, borderRadius: 6, border: '1px solid #E5E7EB' }}
                formatter={(v) => [`Rs. ${Number(v ?? 0).toLocaleString()}`, 'Revenue']}
              />
              <Area
                type="monotone"
                dataKey="revenue"
                stroke="#D97706"
                strokeWidth={2}
                fill="url(#revGrad)"
                dot={{ fill: '#D97706', r: 3 }}
              />
            </AreaChart>
          </ResponsiveContainer>
        </ChartCard>

        {/* Top Items */}
        <ChartCard title="Top Items">
          {topItems.length === 0 ? (
            <p className="text-xs text-[#9CA3AF] flex items-center justify-center h-full">No data</p>
          ) : (
            <div className="flex flex-col justify-between h-full py-1 space-y-2">
              {topItems.map((item) => (
                <div key={item.name} className="space-y-0.5">
                  <div className="flex justify-between text-[10px]">
                    <span className="font-medium text-zinc-700 truncate mr-2">{item.name}</span>
                    <span className="text-[#6B7280] shrink-0">{item.count}</span>
                  </div>
                  <div className="w-full bg-[#F3F4F6] h-1.5 rounded-full">
                    <div
                      className="bg-[#D97706] h-full rounded-full transition-all duration-500"
                      style={{ width: `${item.pct}%` }}
                    />
                  </div>
                </div>
              ))}
            </div>
          )}
        </ChartCard>
      </div>

      {/* ── Bottom row ───────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">

        {/* Key Metrics */}
        <div className="space-y-3">
          <h3 className="text-[10px] font-bold text-[#9CA3AF] uppercase tracking-widest px-1">
            Key Metrics
          </h3>
          <div className="grid grid-cols-2 gap-3">
            <MetricCard
              label="Avg Order Value"
              value={`Rs. ${Math.round(avgOrderValue).toLocaleString()}`}
              trend={{ text: `${periodOrders.length} orders`, positive: true }}
            />
            <MetricCard
              label="Total Revenue"
              value={`Rs. ${totalRevenue.toLocaleString()}`}
              trend={{ text: period, positive: true }}
            />
            <MetricCard
              label="Customer Satisfaction"
              value={`${avgRating.toFixed(1)} / 5`}
              trend={{ text: `${reviews.length} reviews`, positive: avgRating >= 4 }}
            />
            <MetricCard
              label="Avg Fulfillment Time"
              value={avgFulfillmentMin !== null ? `${avgFulfillmentMin} min` : '—'}
              trend={{
                text: avgFulfillmentMin !== null
                  ? avgFulfillmentMin <= 30 ? 'On target' : 'Above 30 min'
                  : 'No completed orders',
                positive: avgFulfillmentMin !== null && avgFulfillmentMin <= 30,
              }}
            />
          </div>
        </div>

        {/* Recommended Actions */}
        <div className="space-y-3">
          <h3 className="text-[10px] font-bold text-[#9CA3AF] uppercase tracking-widest px-1">
            Recommended Actions
          </h3>
          <div className="bg-white border border-[#E5E7EB] rounded-lg overflow-hidden">
            <RecommendedAction
              index={1}
              title={topItems[0] ? `Monitor "${topItems[0].name}" supply` : 'Check inventory levels'}
              desc={topItems[0] ? `"${topItems[0].name}" leads with ${topItems[0].count} orders this period.` : 'Review stock for high-demand items.'}
              primary
            />
            <RecommendedAction
              index={2}
              title="Review low-rated items"
              desc={`Average rating is ${avgRating.toFixed(1)}/5. ${avgRating < 4 ? 'Address quality concerns on underperforming dishes.' : 'Keep up the great quality.'}`}
            />
            <RecommendedAction
              index={3}
              title="Optimise peak-hour staffing"
              desc="Analyse hourly order spikes to schedule kitchen staff more efficiently."
            />
          </div>
        </div>
      </div>
    </div>
  )
}

// ── sub-components ─────────────────────────────────────────────────────────

function ChartCard({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <article className="bg-white border border-[#E5E7EB] p-4 rounded-lg flex flex-col h-[220px]">
      <h3 className="text-[10px] font-bold text-[#9CA3AF] uppercase tracking-widest mb-3 shrink-0">
        {title}
      </h3>
      <div className="flex-1 min-h-0">{children}</div>
    </article>
  )
}

function MetricCard({
  label,
  value,
  trend,
}: {
  label: string
  value: string
  trend: { text: string; positive: boolean }
}) {
  return (
    <div className="bg-white border border-[#E5E7EB] p-4 rounded-lg">
      <p className="text-[10px] text-[#9CA3AF] font-bold uppercase mb-1">{label}</p>
      <div className="flex items-baseline gap-2 flex-wrap">
        <span className="text-lg font-bold text-zinc-900">{value}</span>
        <span className={`text-[10px] font-bold ${trend.positive ? 'text-emerald-600' : 'text-red-500'}`}>
          {trend.text}
        </span>
      </div>
    </div>
  )
}

function RecommendedAction({
  index,
  title,
  desc,
  primary = false,
}: {
  index: number
  title: string
  desc: string
  primary?: boolean
}) {
  return (
    <div className="p-4 flex gap-4 items-center group cursor-pointer hover:bg-[#F9F9F7] transition-colors border-b border-[#F4F4F2] last:border-0">
      <div
        className={`w-8 h-8 rounded-full border-2 flex items-center justify-center font-bold text-sm shrink-0 ${
          primary ? 'border-[#D97706]/30 text-[#D97706]' : 'border-[#E5E7EB] text-[#9CA3AF]'
        }`}
      >
        {index}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-zinc-900">{title}</p>
        <p className="text-[11px] text-[#6B7280] mt-0.5 leading-relaxed">{desc}</p>
      </div>
      <ChevronRight size={16} className="text-[#D1D5DB] group-hover:text-[#D97706] transition-colors shrink-0" />
    </div>
  )
}
