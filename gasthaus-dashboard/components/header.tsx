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
    <header className="fixed top-0 right-0 left-[240px] h-[56px] z-40 bg-white border-b border-[#E5E7EB] flex items-center justify-between px-8">
      <h2 className="text-[15px] font-semibold text-[#1C1C1E]">{title}</h2>

      <div className="flex items-center gap-5">
        <span className="text-xs text-[#6B7280] font-medium">{formatDate()}</span>

        <div className="flex items-center gap-3">
          <button className="w-8 h-8 flex items-center justify-center text-[#9CA3AF] hover:text-[#D97706] transition-colors">
            <Bell size={18} />
          </button>

          <div className="w-7 h-7 rounded bg-[#D97706] flex items-center justify-center text-white text-[10px] font-bold">
            {initials}
          </div>
        </div>
      </div>
    </header>
  )
}
