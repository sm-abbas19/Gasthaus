'use client'

import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import {
  UtensilsCrossed,
  LayoutDashboard,
  ScrollText,
  ChefHat,
  BookOpen,
  Table2,
  Star,
  TrendingUp,
  Users,
  LogOut,
} from 'lucide-react'
import { getUser, clearAuth } from '@/lib/auth'

const navItems = [
  { label: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
  { label: 'Orders',    href: '/orders',    icon: ScrollText },
  { label: 'Kitchen',   href: '/kitchen',   icon: ChefHat },
  { label: 'Menu',      href: '/menu',      icon: BookOpen },
  { label: 'Tables',    href: '/tables',    icon: Table2 },
  { label: 'Reviews',   href: '/reviews',   icon: Star },
  { label: 'Insights',  href: '/insights',  icon: TrendingUp },
  { label: 'Staff',     href: '/staff',     icon: Users },
]

export default function Sidebar() {
  const pathname = usePathname()
  const router = useRouter()
  const user = getUser()

  function handleLogout() {
    clearAuth()
    router.replace('/login')
  }

  const initials = user?.name
    ? user.name.split(' ').map((n) => n[0]).join('').slice(0, 2).toUpperCase()
    : 'AD'
  const role = user?.role ?? 'Manager'

  return (
    <aside className="fixed left-0 top-0 h-full w-[240px] bg-[#1C1C1E] z-50 flex flex-col pt-6 pb-5">
      {/* Brand */}
      <div className="px-5 flex items-center gap-2.5">
        <UtensilsCrossed size={17} className="text-white/80 shrink-0" />
        <span
          className="text-white font-semibold uppercase tracking-[0.28em]"
          style={{ fontSize: 11 }}
        >
          GASTHAUS
        </span>
      </div>

      {/* Hairline below brand */}
      <div className="mx-5 mt-5 mb-3 h-px bg-white/10" />

      {/* Nav */}
      <nav className="flex-1 space-y-px px-3 overflow-y-auto">
        {navItems.map(({ label, href, icon: Icon }) => {
          const active = pathname === href || pathname.startsWith(href + '/')
          return (
            <Link
              key={href}
              href={href}
              className={[
                'flex items-center gap-3 px-3 py-[7px] rounded-md text-[12.5px] font-medium transition-all',
                active
                  ? 'bg-[#2C2C2C] text-white border-l-2 border-[#D97706] pl-[10px]'
                  : 'text-white/55 hover:text-white/85 hover:bg-white/8 border-l-2 border-transparent pl-[10px]',
              ].join(' ')}
            >
              <Icon size={15} className="text-current shrink-0" />
              <span>{label}</span>
            </Link>
          )
        })}
      </nav>

      {/* User + Logout */}
      <div className="mx-3 pt-3 border-t border-white/10">
        <div className="flex items-center gap-2.5 px-3">
          <div className="w-7 h-7 rounded-full bg-white/15 flex items-center justify-center text-white text-[10px] font-bold shrink-0">
            {initials}
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-white text-[12px] font-medium truncate leading-tight">
              {user?.name ?? 'Admin'}
            </p>
            <p className="text-white/50 text-[10px] capitalize leading-tight mt-0.5">
              {role.toString().charAt(0) + role.toString().slice(1).toLowerCase()}
            </p>
          </div>
          <button
            onClick={handleLogout}
            title="Log out"
            className="text-white/50 hover:text-white transition-colors shrink-0"
          >
            <LogOut size={14} />
          </button>
        </div>
      </div>
    </aside>
  )
}
