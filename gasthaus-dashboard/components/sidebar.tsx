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
    <aside className="fixed left-0 top-0 h-full w-[240px] bg-[#1C1C1E] z-50 flex flex-col py-8">
      {/* Brand */}
      <div className="px-6 mb-10 flex items-center gap-3">
        <UtensilsCrossed size={22} className="text-[#D97706] shrink-0" />
        <span
          className="text-white font-semibold uppercase"
          style={{ fontSize: 13, letterSpacing: '0.3em' }}
        >
          GASTHAUS
        </span>
      </div>

      {/* Nav */}
      <nav className="flex-1 space-y-0.5 px-3">
        {navItems.map(({ label, href, icon: Icon }) => {
          const active = pathname === href || pathname.startsWith(href + '/')
          return (
            <Link
              key={href}
              href={href}
              className={[
                'flex items-center gap-3 px-3 py-2.5 rounded text-[13px] transition-colors',
                active
                  ? 'bg-[#2C2C2C] text-white border-l-2 border-[#D97706] pl-[10px]'
                  : 'text-[#9CA3AF] hover:text-white hover:bg-white/5 border-l-2 border-transparent pl-[10px]',
              ].join(' ')}
            >
              <Icon
                size={17}
                className={active ? 'text-[#D97706]' : 'text-current'}
              />
              <span>{label}</span>
            </Link>
          )
        })}
      </nav>

      {/* User + Logout */}
      <div className="mt-auto mx-3 pt-6 border-t border-white/10">
        <div className="flex items-center gap-3 px-3">
          <div className="w-8 h-8 rounded-full bg-[#D97706] flex items-center justify-center text-white text-[10px] font-bold shrink-0">
            {initials}
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-white text-[13px] font-medium truncate">
              {user?.name ?? 'Admin'}
            </p>
            <p className="text-[#9CA3AF] text-[11px] capitalize">
              {role.toString().charAt(0) + role.toString().slice(1).toLowerCase()}
            </p>
          </div>
          <button
            onClick={handleLogout}
            title="Log out"
            className="text-[#9CA3AF] hover:text-white transition-colors shrink-0"
          >
            <LogOut size={16} />
          </button>
        </div>
      </div>
    </aside>
  )
}
