'use client'

import { usePathname } from 'next/navigation'
import { Bell } from 'lucide-react'
import { getUser } from '@/lib/auth'

const PAGE_TITLES: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/orders':    'Orders',
  '/kitchen':   'Kitchen',
  '/menu':      'Menu',
  '/tables':    'Tables',
  '/reviews':   'Reviews',
  '/insights':  'Insights',
}

function getTitle(pathname: string): string {
  for (const [route, title] of Object.entries(PAGE_TITLES)) {
    if (pathname === route || pathname.startsWith(route + '/')) {
      return title
    }
  }
  return 'Dashboard'
}

function formatDate(): string {
  return new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  })
}

export default function Header() {
  const pathname = usePathname()
  const user = getUser()

  const title = getTitle(pathname)
  const initials = user?.name
    ? user.name.split(' ').map((n) => n[0]).join('').slice(0, 2).toUpperCase()
    : 'AD'

  return (
    <header className="fixed top-0 right-0 left-[240px] h-[52px] z-40 bg-[#78350F] border-b border-black/10 flex items-center justify-between px-6">
      <h2 className="text-[13px] font-semibold text-white/90 tracking-wide">{title}</h2>

      <div className="flex items-center gap-4">
        <span className="text-[11px] text-white/45 font-medium">{formatDate()}</span>

        <div className="flex items-center gap-2.5">
          <button className="w-7 h-7 flex items-center justify-center text-white/50 hover:text-white transition-colors">
            <Bell size={16} />
          </button>

          <div className="w-6 h-6 rounded bg-white/15 flex items-center justify-center text-white text-[10px] font-bold">
            {initials}
          </div>
        </div>
      </div>
    </header>
  )
}
