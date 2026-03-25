'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { isAuthenticated } from '@/lib/auth'

/**
 * Client-side auth guard. Wraps every dashboard page.
 * Because the JWT lives in localStorage (client-only), we check it here
 * rather than in middleware (which runs server-side and can't read localStorage).
 */
export default function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter()

  useEffect(() => {
    if (!isAuthenticated()) {
      router.replace('/login')
    }
  }, [router])

  // Render children immediately — the effect fires after first paint.
  // Unauthenticated users see a brief flash then redirect; acceptable trade-off
  // for a staff-only internal app.
  if (typeof window !== 'undefined' && !isAuthenticated()) {
    return null
  }

  return <>{children}</>
}
