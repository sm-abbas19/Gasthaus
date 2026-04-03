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
    <header className="fixed top-0 right-0 left-[240px] h-[56px] z-40 bg-[#78350F] flex items-center justify-between px-8">
      <h2 className="text-[15px] font-semibold text-white">{title}</h2>

      <div className="flex items-center gap-5">
        <span className="text-xs text-white/80 font-medium">{formatDate()}</span>

        <div className="flex items-center gap-3">
          <button className="w-8 h-8 flex items-center justify-center text-white/70 hover:text-white transition-colors">
            <Bell size={18} />
          </button>

          <div className="w-7 h-7 rounded bg-white/20 flex items-center justify-center text-white text-[10px] font-bold">
            {initials}
          </div>
        </div>
      </div>
    </header>
  )
}
