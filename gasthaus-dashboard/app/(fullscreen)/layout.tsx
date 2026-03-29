'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { isAuthenticated, getUser, clearAuth } from '@/lib/auth'

// KITCHEN and MANAGER may access fullscreen pages (kitchen KDS)
const ALLOWED_ROLES = ['KITCHEN', 'MANAGER']

export default function FullscreenLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const router = useRouter()
  const [ready, setReady] = useState(false)

  useEffect(() => {
    if (!isAuthenticated()) {
      router.replace('/login')
      return
    }
    const user = getUser()
    if (!user || !ALLOWED_ROLES.includes(user.role)) {
      clearAuth()
      sessionStorage.setItem('login_error', 'ACHTUNG! Unauthorized')
      router.replace('/login')
      return
    }
    setReady(true)
  }, [router])

  if (!ready) return null
  return <>{children}</>
}
