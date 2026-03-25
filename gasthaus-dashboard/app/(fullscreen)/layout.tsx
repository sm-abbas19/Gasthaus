import AuthGuard from '@/components/auth-guard'

// Full-screen layout: auth-protected but NO sidebar/header.
// Used by Kitchen KDS which is a standalone dark display.
export default function FullscreenLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return <AuthGuard>{children}</AuthGuard>
}
