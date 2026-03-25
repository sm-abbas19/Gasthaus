import Sidebar from '@/components/sidebar'
import Header from '@/components/header'
import AuthGuard from '@/components/auth-guard'

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <AuthGuard>
      <div className="min-h-screen bg-[#F9F9F7]">
        <Sidebar />
        <Header />
        {/* offset: 240px sidebar + 56px header */}
        <main className="ml-[240px] pt-[56px] min-h-screen">
          {children}
        </main>
      </div>
    </AuthGuard>
  )
}
