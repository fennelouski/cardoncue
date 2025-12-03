import { auth, clerkClient } from '@clerk/nextjs/server';
import { redirect } from 'next/navigation';
import Link from 'next/link';

async function checkAdminAuth() {
  const { userId } = await auth();

  if (!userId) {
    redirect('/sign-in');
  }

  const user = await clerkClient().users.getUser(userId);
  const email = user.emailAddresses[0]?.emailAddress;

  if (!email || !email.endsWith('@100apps.studio')) {
    redirect('/');
  }

  return { userId, email };
}

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { email } = await checkAdminAuth();

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex">
              <div className="flex-shrink-0 flex items-center">
                <h1 className="text-xl font-bold text-gray-900">
                  CardOnCue Admin
                </h1>
              </div>
              <div className="hidden sm:ml-6 sm:flex sm:space-x-8">
                <Link
                  href="/admin"
                  className="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
                >
                  Dashboard
                </Link>
                <Link
                  href="/admin/brands"
                  className="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
                >
                  Brands
                </Link>
                <Link
                  href="/admin/locations"
                  className="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
                >
                  Locations
                </Link>
                <Link
                  href="/admin/templates"
                  className="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
                >
                  Templates
                </Link>
              </div>
            </div>
            <div className="flex items-center">
              <span className="text-sm text-gray-500">{email}</span>
            </div>
          </div>
        </div>
      </nav>

      <main className="py-10">
        <div className="max-w-7xl mx-auto sm:px-6 lg:px-8">
          {children}
        </div>
      </main>
    </div>
  );
}
