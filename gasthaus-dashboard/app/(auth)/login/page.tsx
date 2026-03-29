'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { UtensilsCrossed, Eye, EyeOff } from 'lucide-react'
import { setAuth, isAuthenticated } from '@/lib/auth'
import api from '@/lib/api'
import type { User } from '@/types'
import { Role } from '@/types'

const schema = z.object({
  email: z
    .string()
    .min(1, 'Email is required')
    .email('Enter a valid email address'),
  password: z
    .string()
    .min(1, 'Password is required')
    .min(6, 'Password must be at least 6 characters'),
})

type FormData = z.infer<typeof schema>

export default function LoginPage() {
  const router = useRouter()
  const [showPassword, setShowPassword] = useState(false)
  const [serverError, setServerError] = useState<string | null>(null)

  useEffect(() => {
    if (isAuthenticated()) {
      router.replace('/dashboard')
      return
    }
    const flash = sessionStorage.getItem('login_error')
    if (flash) {
      setServerError(flash)
      sessionStorage.removeItem('login_error')
    }
  }, [router])

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormData>({
    resolver: zodResolver(schema),
  })

  async function onSubmit(data: FormData) {
    setServerError(null)
    try {
      const res = await api.post<{ user: User; token: string }>(
        '/auth/login',
        data,
      )
      const { user, token } = res.data
      setAuth(token, user)

      // Role-based redirect
      if (user.role === Role.KITCHEN) {
        router.replace('/kitchen')
      } else {
        router.replace('/dashboard')
      }
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { message?: string } } })?.response?.data
          ?.message ?? 'Invalid credentials. Please try again.'
      setServerError(message)
    }
  }

  return (
    <main className="flex h-screen w-full overflow-hidden">
      {/* ── Left pane 55% ── */}
      <section className="hidden lg:flex lg:w-[55%] relative flex-col justify-end p-20 bg-[#1C1C1E]">
        {/* Background photo */}
        <div className="absolute inset-0 z-0">
          <img
            src="https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=1600&q=80"
            alt="Elegant restaurant dining room"
            className="w-full h-full object-cover opacity-40"
          />
          <div className="absolute inset-0 bg-black/40" />
        </div>

        {/* Content overlay */}
        <div className="relative z-10 space-y-5 max-w-md">
          <div className="w-10 h-[2px] bg-[#D97706]" />
          <h1 className="text-5xl text-white leading-tight" style={{ fontWeight: 300 }}>
            Where every order matters.
          </h1>
          <p className="text-[15px] text-[#9CA3AF] leading-relaxed">
            Manage your restaurant with precision. Real-time orders,
            live kitchen display, and AI-powered insights — all in one place.
          </p>
        </div>
      </section>

      {/* ── Right pane 45% ── */}
      <section className="w-full lg:w-[45%] bg-white flex flex-col justify-between items-center px-8 py-12">
        {/* Wordmark */}
        <div className="max-w-sm w-full flex items-center gap-3">
          <UtensilsCrossed size={20} className="text-[#1C1C1E]" />
          <span
            className="font-semibold text-[#1C1C1E] uppercase"
            style={{ fontSize: 13, letterSpacing: '0.3em' }}
          >
            GASTHAUS
          </span>
        </div>

        {/* Form area */}
        <div className="max-w-sm w-full">
          <div className="mb-10">
            <h2 className="text-[28px] font-semibold text-[#1C1C1E] tracking-tight mb-2">
              Staff Portal
            </h2>
            <p className="text-[14px] text-[#6B7280]">Sign in to your account</p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6" noValidate>
            {/* Email */}
            <div className="space-y-2">
              <label
                htmlFor="email"
                className="block text-[11px] font-medium text-[#6B7280] tracking-[0.08em] uppercase"
              >
                Email
              </label>
              <input
                id="email"
                type="email"
                autoComplete="email"
                placeholder="Enter your email"
                {...register('email', { onChange: () => setServerError(null) })}
                className={[
                  'w-full h-[44px] bg-[#FAFAFA] border rounded-[6px] px-4 text-[14px] text-[#111827] placeholder-[#9CA3AF] transition-colors outline-none focus:border-[#D97706]',
                  errors.email ? 'border-red-400' : 'border-[#D1D5DB]',
                ].join(' ')}
              />
              {errors.email && (
                <p className="text-[12px] text-red-500">{errors.email.message}</p>
              )}
            </div>

            {/* Password */}
            <div className="space-y-2">
              <div className="flex justify-between items-center">
                <label
                  htmlFor="password"
                  className="block text-[11px] font-medium text-[#6B7280] tracking-[0.08em] uppercase"
                >
                  Password
                </label>
              </div>
              <div className="relative">
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  autoComplete="current-password"
                  placeholder="Enter your password"
                  {...register('password', { onChange: () => setServerError(null) })}
                  className={[
                    'w-full h-[44px] bg-[#FAFAFA] border rounded-[6px] px-4 pr-11 text-[14px] text-[#111827] placeholder-[#9CA3AF] transition-colors outline-none focus:border-[#D97706]',
                    errors.password ? 'border-red-400' : 'border-[#D1D5DB]',
                  ].join(' ')}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-[#9CA3AF] hover:text-[#6B7280] transition-colors"
                  tabIndex={-1}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
              {errors.password && (
                <p className="text-[12px] text-red-500">{errors.password.message}</p>
              )}
            </div>

            {/* Server error */}
            {serverError && (
              <div className="bg-red-50 border border-red-200 rounded-[6px] px-4 py-3">
                <p className="text-[13px] text-red-600">{serverError}</p>
              </div>
            )}

            {/* Submit */}
            <button
              type="submit"
              disabled={isSubmitting}
              className="w-full h-[44px] bg-[#D97706] text-white font-semibold text-[14px] tracking-[0.02em] rounded-[6px] transition-all hover:bg-[#B45309] active:scale-[0.98] disabled:opacity-60 disabled:cursor-not-allowed"
            >
              {isSubmitting ? 'Signing in…' : 'Sign In'}
            </button>
          </form>
        </div>

        {/* Footer */}
        <p className="text-[11px] text-[#9CA3AF] text-center">
          © {new Date().getFullYear()} Gasthaus. All rights reserved.
        </p>
      </section>
    </main>
  )
}
