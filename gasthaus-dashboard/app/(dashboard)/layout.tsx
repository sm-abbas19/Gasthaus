import Sidebar from '@/components/sidebar'
import Header from '@/components/header'

// Sidebar and Header are both fixed-position — layout only needs
// matching margin/padding offsets so content sits in the right place.
export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div className="min-h-screen bg-[#F9F9F7]">
      <Sidebar />
      <Header />
      {/* offset: 240px sidebar + 56px header */}
      <main className="ml-[240px] pt-[56px] min-h-screen">
        {children}
      </main>
    </div>
  )
}
