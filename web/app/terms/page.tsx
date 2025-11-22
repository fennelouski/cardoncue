import { Header } from '../components/Header'
import { Footer } from '../components/Footer'

export default function TermsPage() {
  return (
    <div className="min-h-screen flex flex-col">
      <Header />

      <main className="flex-grow py-20">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="card">
            <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-8">
              Terms of Use
            </h1>

            <div className="prose dark:prose-invert max-w-none">
              <p className="text-gray-600 dark:text-gray-300 mb-6">
                <strong>Last updated:</strong> {new Date().toLocaleDateString()}
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                1. Acceptance of Terms
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                By accessing and using CardOnCue ("the Service"), you accept and agree to be bound by the terms
                and provision of this agreement. If you do not agree to abide by the above, please do not use this service.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                2. Description of Service
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                CardOnCue is a location-aware digital card storage application that automatically displays membership cards,
                library cards, and barcodes when users enter relevant locations. The service is available on iOS devices,
                with Android support planned for future release.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                3. User Accounts
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                To use certain features of the Service, you must register for an account. When you register, you agree to:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Provide accurate and complete information</li>
                <li>Maintain the security of your password and account</li>
                <li>Accept responsibility for all activities under your account</li>
                <li>Notify us immediately of any unauthorized use</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                4. Privacy and Data Security
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Your privacy is important to us. Card data is encrypted end-to-end and we never store your actual card
                information in plain text. Location data is processed locally on your device and never sent to our servers.
                See our Privacy Policy for more details.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                5. Acceptable Use
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                You agree not to use the Service for any unlawful purposes or to conduct any unlawful activity,
                including but not limited to:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Fraud, deceit, or misrepresentation</li>
                <li>Violation of intellectual property rights</li>
                <li>Distribution of harmful or malicious code</li>
                <li>Interference with the Service's operation</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                6. Subscription and Billing
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Some features require a paid subscription. By subscribing, you agree to pay all applicable fees.
                Subscriptions automatically renew unless cancelled. Refunds are provided at our discretion.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                7. Termination
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We may terminate or suspend your account and access to the Service immediately, without prior notice,
                for conduct that violates these Terms or is harmful to other users, us, or third parties.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                8. Disclaimers
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                The Service is provided "as is" without warranties of any kind. We do not guarantee uninterrupted
                service or that the Service will meet your specific requirements.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                9. Limitation of Liability
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                In no event shall we be liable for any indirect, incidental, special, or consequential damages
                arising out of or in connection with your use of the Service.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                10. Changes to Terms
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We reserve the right to modify these Terms at any time. Continued use of the Service after
                changes constitutes acceptance of the new Terms.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                11. Contact Information
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                If you have questions about these Terms, please contact us at hello@cardoncue.com.
              </p>
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  )
}
