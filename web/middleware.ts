import { authMiddleware } from '@clerk/nextjs/server'

export default authMiddleware({
  publicRoutes: [
    '/',
    '/features',
    '/search',
    '/support',
    '/contact',
    '/privacy',
    '/terms',
    '/android',
    '/api/v1/search',
    '/api/v1/place/(.*)',
    '/api/v1/networks/(.*)',
    '/api/v1/region-refresh',
    '/api/contact',
    '/api/android-request',
    '/api/debug-schema',
  ],
})

export const config = {
  matcher: [
    // Skip Next.js internals and all static files, unless found in search params
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    // Always run for API routes
    '/(api|trpc)(.*)',
  ],
}
