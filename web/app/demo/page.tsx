import { Header } from '../components/Header'
import { Footer } from '../components/Footer'
import { GeofencingDemo } from '../components/GeofencingDemo'

export const metadata = {
  title: 'Interactive Demo - CardOnCue',
  description: 'See how CardOnCue uses geofencing to automatically show your cards when you need them.'
}

export default function DemoPage() {
  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-grow bg-gray-50 dark:bg-gray-900 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <GeofencingDemo />
        </div>
      </main>
      <Footer />
    </div>
  )
}
