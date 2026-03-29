'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Users, Plus, ChefHat, ShieldCheck, X } from 'lucide-react'
import api from '@/lib/api'
import type { User } from '@/types'
import { Role } from '@/types'

const ROLE_META = {
  [Role.MANAGER]: { label: 'Manager', icon: ShieldCheck, color: 'text-[#D97706] bg-[#FEF3C7]' },
  [Role.KITCHEN]: { label: 'Kitchen', icon: ChefHat,     color: 'text-[#6D28D9] bg-[#EDE9FE]' },
}

export default function StaffPage() {
  const queryClient = useQueryClient()
  const [showForm, setShowForm] = useState(false)
  const [form, setForm]         = useState({ name: '', email: '', password: '', role: Role.KITCHEN })
  const [formError, setFormError] = useState<string | null>(null)

  const { data: staff = [], isLoading } = useQuery<User[]>({
    queryKey: ['staff'],
    queryFn:  () => api.get<User[]>('/auth/staff').then((r) => r.data),
  })

  const { mutate: createStaff, isPending } = useMutation({
    mutationFn: (data: typeof form) => api.post('/auth/register/staff', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['staff'] })
      setShowForm(false)
      setForm({ name: '', email: '', password: '', role: Role.KITCHEN })
      setFormError(null)
    },
    onError: (err: unknown) => {
      const msg = (err as { response?: { data?: { message?: string } } })
        ?.response?.data?.message ?? 'Failed to create account.'
      setFormError(msg)
    },
  })

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setFormError(null)
    if (!form.name.trim() || !form.email.trim() || !form.password.trim()) return
    createStaff(form)
  }

  const managers = staff.filter((u) => u.role === Role.MANAGER)
  const kitchen  = staff.filter((u) => u.role === Role.KITCHEN)

  return (
    <div className="px-8 py-8 max-w-4xl mx-auto space-y-6">

      {/* ── Header ───────────────────────────────────────────────── */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-zinc-900">Staff Accounts</h2>
          <p className="text-sm text-[#6B7280] mt-0.5">{staff.length} staff member{staff.length !== 1 ? 's' : ''}</p>
        </div>
        <button
          onClick={() => { setShowForm(true); setFormError(null) }}
          className="flex items-center gap-2 bg-[#D97706] text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-[#B45309] transition-colors"
        >
          <Plus size={15} />
          Add Staff
        </button>
      </div>

      {/* ── Create form ──────────────────────────────────────────── */}
      {showForm && (
        <div className="bg-white border border-[#E5E7EB] rounded-lg p-6">
          <div className="flex items-center justify-between mb-5">
            <h3 className="font-semibold text-zinc-900 text-sm">New Staff Account</h3>
            <button onClick={() => setShowForm(false)} className="text-[#9CA3AF] hover:text-zinc-700">
              <X size={16} />
            </button>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <label className="text-[11px] font-bold text-[#6B7280] uppercase tracking-wider">Name</label>
                <input
                  type="text"
                  value={form.name}
                  onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                  placeholder="Full name"
                  className="w-full h-10 border border-[#E5E7EB] rounded-lg px-3 text-sm focus:outline-none focus:border-[#D97706]"
                  required
                />
              </div>
              <div className="space-y-1.5">
                <label className="text-[11px] font-bold text-[#6B7280] uppercase tracking-wider">Email</label>
                <input
                  type="email"
                  value={form.email}
                  onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
                  placeholder="email@gasthaus.com"
                  className="w-full h-10 border border-[#E5E7EB] rounded-lg px-3 text-sm focus:outline-none focus:border-[#D97706]"
                  required
                />
              </div>
              <div className="space-y-1.5">
                <label className="text-[11px] font-bold text-[#6B7280] uppercase tracking-wider">Password</label>
                <input
                  type="password"
                  value={form.password}
                  onChange={(e) => setForm((f) => ({ ...f, password: e.target.value }))}
                  placeholder="Min. 6 characters"
                  className="w-full h-10 border border-[#E5E7EB] rounded-lg px-3 text-sm focus:outline-none focus:border-[#D97706]"
                  required
                  minLength={6}
                />
              </div>
              <div className="space-y-1.5">
                <label className="text-[11px] font-bold text-[#6B7280] uppercase tracking-wider">Role</label>
                <select
                  value={form.role}
                  onChange={(e) => setForm((f) => ({ ...f, role: e.target.value as Role }))}
                  className="w-full h-10 border border-[#E5E7EB] rounded-lg px-3 text-sm focus:outline-none focus:border-[#D97706] bg-white"
                >
                  <option value={Role.KITCHEN}>Kitchen</option>
                  <option value={Role.MANAGER}>Manager</option>
                </select>
              </div>
            </div>

            {formError && (
              <div className="bg-red-50 border border-red-200 rounded-lg px-4 py-2.5">
                <p className="text-[13px] text-red-600">{formError}</p>
              </div>
            )}

            <div className="flex justify-end gap-3 pt-1">
              <button
                type="button"
                onClick={() => setShowForm(false)}
                className="px-4 py-2 text-sm text-[#6B7280] border border-[#E5E7EB] rounded-lg hover:bg-[#F9F9F7]"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isPending}
                className="px-4 py-2 text-sm font-semibold bg-[#D97706] text-white rounded-lg hover:bg-[#B45309] disabled:opacity-60"
              >
                {isPending ? 'Creating…' : 'Create Account'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* ── Staff lists ───────────────────────────────────────────── */}
      {isLoading ? (
        <p className="text-sm text-[#9CA3AF]">Loading staff…</p>
      ) : (
        <div className="space-y-6">
          <StaffSection title="Managers" icon={ShieldCheck} users={managers} color="text-[#D97706]" badge="bg-[#FEF3C7] text-[#D97706]" />
          <StaffSection title="Kitchen Staff" icon={ChefHat} users={kitchen} color="text-[#6D28D9]" badge="bg-[#EDE9FE] text-[#6D28D9]" />
        </div>
      )}
    </div>
  )
}

function StaffSection({
  title, icon: Icon, users, color, badge,
}: {
  title: string
  icon: React.ElementType
  users: User[]
  color: string
  badge: string
}) {
  return (
    <div>
      <div className="flex items-center gap-2 mb-3">
        <Icon size={15} className={color} />
        <h3 className="text-[11px] font-bold text-[#9CA3AF] uppercase tracking-widest">{title}</h3>
        <span className="text-[10px] text-[#9CA3AF]">({users.length})</span>
      </div>

      {users.length === 0 ? (
        <p className="text-sm text-[#9CA3AF] pl-1">No {title.toLowerCase()} yet.</p>
      ) : (
        <div className="bg-white border border-[#E5E7EB] rounded-lg divide-y divide-[#F4F4F2]">
          {users.map((u) => (
            <div key={u.id} className="flex items-center gap-4 px-5 py-3.5">
              <div className="w-8 h-8 rounded-full bg-[#F3F4F6] flex items-center justify-center text-[11px] font-bold text-zinc-600 shrink-0">
                {u.name.split(' ').map((n) => n[0]).join('').slice(0, 2).toUpperCase()}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-zinc-900">{u.name}</p>
                <p className="text-[11px] text-[#6B7280]">{u.email}</p>
              </div>
              <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wide ${badge}`}>
                {u.role.charAt(0) + u.role.slice(1).toLowerCase()}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
