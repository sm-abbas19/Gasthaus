'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { isAuthenticated, getUser, clearAuth } from '@/lib/auth'

// Only MANAGER may access the main staff dashboard
const STAFF_ROLES = ['MANAGER']

export default function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const [ready, setReady] = useState(false)

  useEffect(() => {
    if (!isAuthenticated()) {
      router.replace('/login')
      return
    }
    const user = getUser()
    if (!user || !STAFF_ROLES.includes(user.role)) {
      // CUSTOMER or unknown role — clear session so login page doesn't redirect back
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
