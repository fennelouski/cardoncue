import '@testing-library/jest-dom'

// Mock Next.js router
jest.mock('next/navigation', () => ({
  useRouter() {
    return {
      push: jest.fn(),
      replace: jest.fn(),
      prefetch: jest.fn(),
      back: jest.fn(),
      forward: jest.fn(),
      refresh: jest.fn(),
      pathname: '/',
      query: '',
    }
  },
  useSearchParams() {
    return new URLSearchParams()
  },
  usePathname() {
    return '/'
  },
}))

// Mock Vercel KV
jest.mock('@vercel/kv', () => ({
  kv: {
    get: jest.fn(),
    setex: jest.fn(),
    del: jest.fn(),
  },
}));

// Mock Clerk
jest.mock('@clerk/nextjs', () => ({
  ClerkProvider: ({ children }) => <div>{children}</div>,
  SignedIn: ({ children }) => <div>{children}</div>,
  SignedOut: ({ children }) => <div>{children}</div>,
  UserButton: () => <div data-testid="user-button">User Button</div>,
  useUser: () => ({
    user: {
      id: 'test-user',
      emailAddresses: [{ emailAddress: 'test@example.com' }],
      firstName: 'Test',
      lastName: 'User',
    },
    isLoaded: true,
  }),
}))

// Mock lucide-react icons
jest.mock('lucide-react', () => ({
  Search: () => <svg data-testid="search-icon" />,
  Menu: () => <svg data-testid="menu-icon" />,
  X: () => <svg data-testid="x-icon" />,
  ChevronDown: () => <svg data-testid="chevron-down-icon" />,
  MapPin: () => <svg data-testid="map-pin-icon" />,
  Building: () => <svg data-testid="building-icon" />,
  Smartphone: () => <svg data-testid="smartphone-icon" />,
  CheckCircle: () => <svg data-testid="check-circle-icon" />,
  AlertCircle: () => <svg data-testid="alert-circle-icon" />,
  Clock: () => <svg data-testid="clock-icon" />,
  Mail: () => <svg data-testid="mail-icon" />,
  MessageSquare: () => <svg data-testid="message-square-icon" />,
  HelpCircle: () => <svg data-testid="help-circle-icon" />,
  User: () => <svg data-testid="user-icon" />,
  Github: () => <svg data-testid="github-icon" />,
  Twitter: () => <svg data-testid="twitter-icon" />,
  CreditCard: () => <svg data-testid="credit-card-icon" />,
  Bell: () => <svg data-testid="bell-icon" />,
  Shield: () => <svg data-testid="shield-icon" />,
  QrCode: () => <svg data-testid="qr-code-icon" />,
  Users: () => <svg data-testid="users-icon" />,
  ArrowRightLeft: () => <svg data-testid="arrow-right-left-icon" />,
}))

// Mock framer-motion
jest.mock('framer-motion', () => ({
  motion: {
    div: ({ children, whileInView, initial, animate, transition, exit, ...props }) => <div {...props}>{children}</div>,
    button: ({ children, whileInView, initial, animate, transition, exit, ...props }) => <button {...props}>{children}</button>,
    h1: ({ children, whileInView, initial, animate, transition, exit, ...props }) => <h1 {...props}>{children}</h1>,
    h2: ({ children, whileInView, initial, animate, transition, exit, ...props }) => <h2 {...props}>{children}</h2>,
    p: ({ children, whileInView, initial, animate, transition, exit, ...props }) => <p {...props}>{children}</p>,
  },
  AnimatePresence: ({ children }) => <>{children}</>,
}))
