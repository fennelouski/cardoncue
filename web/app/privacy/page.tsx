import { Header } from '../components/Header'
import { Footer } from '../components/Footer'

export default function PrivacyPage() {
  return (
    <div className="min-h-screen flex flex-col">
      <Header />

      <main className="flex-grow py-20">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="card">
            <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-8">
              Privacy Policy
            </h1>

            <div className="prose dark:prose-invert max-w-none">
              <p className="text-gray-600 dark:text-gray-300 mb-6">
                <strong>Last updated:</strong> {new Date().toLocaleDateString()}
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                1. Introduction
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                At CardOnCue, we take your privacy seriously. This Privacy Policy explains how we collect, use,
                disclose, and safeguard your information when you use our location-aware digital card storage service.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                2. Information We Collect
              </h2>

              <h3 className="text-xl font-semibold text-gray-900 dark:text-white mt-6 mb-3">
                2.1 Information You Provide
              </h3>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Account information (email, name) when you create an account</li>
                <li>Card information (encrypted and stored securely)</li>
                <li>Communications you send to us (support requests, feedback)</li>
              </ul>

              <h3 className="text-xl font-semibold text-gray-900 dark:text-white mt-6 mb-3">
                2.2 Information Collected Automatically
              </h3>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Device information (iOS version, device model)</li>
                <li>App usage statistics (anonymized)</li>
                <li>Location data (processed locally, never stored on our servers)</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                3. How We Use Your Information
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We use the information we collect to:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Provide and maintain the CardOnCue service</li>
                <li>Process your transactions and manage subscriptions</li>
                <li>Send you important updates and notifications</li>
                <li>Respond to your customer service requests</li>
                <li>Improve our service through anonymized analytics</li>
                <li>Ensure security and prevent fraud</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                4. Data Security and Encryption
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Your card data is protected with industry-standard encryption:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>All card data is encrypted using AES-256-GCM encryption</li>
                <li>Encryption keys are stored securely on your device</li>
                <li>We cannot decrypt or access your actual card information</li>
                <li>Location data is processed locally and never transmitted to our servers</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                5. Location Data Handling
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                CardOnCue requires location permissions to provide its core functionality:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Location data is used only for location detection on your device</li>
                <li>No location history is stored or transmitted to our servers</li>
                <li>Location detection uses efficient geofencing to minimize battery impact</li>
                <li>You can disable location services in your device settings at any time</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                6. Information Sharing and Disclosure
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We do not sell, trade, or otherwise transfer your personal information to third parties, except in the following cases:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>With your explicit consent</li>
                <li>To comply with legal obligations</li>
                <li>To protect our rights and prevent fraud</li>
                <li>In connection with a business transfer (with notice)</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                7. Data Retention
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We retain your information for as long as necessary to provide our services and comply with legal obligations:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Account data is retained while your account is active</li>
                <li>Encrypted card data is deleted when you delete your account</li>
                <li>Support communications may be retained for quality assurance</li>
                <li>Anonymous analytics data is aggregated and retained indefinitely</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                8. Your Rights and Choices
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                You have the following rights regarding your data:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li><strong>Access:</strong> Request a copy of your personal data</li>
                <li><strong>Correction:</strong> Update inaccurate or incomplete data</li>
                <li><strong>Deletion:</strong> Request deletion of your account and data</li>
                <li><strong>Portability:</strong> Export your data in a portable format</li>
                <li><strong>Opt-out:</strong> Unsubscribe from marketing communications</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                9. Cookies and Tracking
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Our website uses minimal cookies and tracking:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Essential cookies for website functionality</li>
                <li>Anonymous analytics to improve user experience</li>
                <li>No advertising or third-party tracking cookies</li>
                <li>You can disable cookies in your browser settings</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                10. International Data Transfers
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Your data may be transferred to and processed in countries other than your own. We ensure appropriate
                safeguards are in place to protect your data in accordance with applicable privacy laws.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                11. Children's Privacy
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                CardOnCue is not intended for children under 13. We do not knowingly collect personal information
                from children under 13. If we become aware of such collection, we will delete the information immediately.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                12. Changes to This Policy
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We may update this Privacy Policy from time to time. We will notify you of any material changes
                by posting the new policy on this page and updating the "Last updated" date.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                13. Contact Us
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                If you have questions about this Privacy Policy or our data practices, please contact us at:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Email: privacy@cardoncue.com</li>
                <li>Address: [Company Address]</li>
              </ul>

              <div className="mt-8 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
                <p className="text-blue-800 dark:text-blue-200 text-sm">
                  <strong>Data Controller:</strong> CardOnCue operates as the data controller for the personal information
                  collected through our service. We are committed to protecting your privacy and handling your data responsibly.
                </p>
              </div>
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  )
}
