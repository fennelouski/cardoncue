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
                <strong>Last updated:</strong> June 2, 2026
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                1. Introduction
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                This Privacy Policy explains how CardOnCue ("CardOnCue," "we," "us," and "our") collects, uses, discloses,
                and protects personal information when you use our website, iOS application, and related services
                (collectively, the "Service"). It also describes your choices and rights.
              </p>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We aim to collect only the information reasonably needed to operate and secure the Service.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                2. Information We Collect
              </h2>
              <h3 className="text-xl font-semibold text-gray-900 dark:text-white mt-6 mb-3">
                2.1 Information You Provide Directly
              </h3>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Account profile details, such as name and email address</li>
                <li>Card content you upload or enter, including barcode or card-related information</li>
                <li>Messages you send us, such as support requests or feedback</li>
              </ul>

              <h3 className="text-xl font-semibold text-gray-900 dark:text-white mt-6 mb-3">
                2.2 Information Collected Automatically
              </h3>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Technical and device data such as IP address, browser/app version, and operating system</li>
                <li>Operational logs and diagnostics used to maintain performance, reliability, and security</li>
                <li>Location-related signals needed to enable location-aware features, where permitted by your settings</li>
              </ul>

              <h3 className="text-xl font-semibold text-gray-900 dark:text-white mt-6 mb-3">
                2.3 Information from Service Providers
              </h3>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We use third-party providers to support account access, hosting, storage, and infrastructure. These providers
                may process personal information on our behalf under contractual obligations. Current categories include
                authentication provider services (such as Clerk) and hosting or infrastructure providers
                (such as Vercel-managed services).
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                3. How We Use Your Information
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We use personal information for legitimate business and operational purposes, including to:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Provide, personalize, and maintain core Service features</li>
                <li>Authenticate users and secure accounts</li>
                <li>Store and manage user-submitted card content and related settings</li>
                <li>Respond to support requests and communicate service notices</li>
                <li>Monitor performance, debug issues, and improve service stability</li>
                <li>Detect, investigate, and prevent misuse, fraud, and security incidents</li>
                <li>Comply with legal and regulatory obligations</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                4. Legal Bases (Where Applicable)
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Depending on your location, we process personal information on one or more of the following legal bases:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Performance of a contract (for example, to provide requested Service functionality)</li>
                <li>Legitimate interests (for example, securing and improving the Service)</li>
                <li>Compliance with legal obligations</li>
                <li>Consent, where required by law and requested by us</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                5. Data Security
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We apply technical and organizational safeguards designed to protect personal information against unauthorized
                access, loss, misuse, or disclosure.
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Encryption protections in transit and at rest where applicable</li>
                <li>Access controls and restricted production access</li>
                <li>Operational monitoring and incident response procedures</li>
              </ul>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                No method of transmission or storage is completely secure, and we cannot guarantee absolute security.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                6. Location Data Handling
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Some Service features rely on location permissions. Location-related data is used to support those features,
                subject to your device and app permission settings.
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>You can control location permissions through your device settings</li>
                <li>Disabling location permissions may reduce or disable location-aware functionality</li>
                <li>We design location processing with data minimization in mind</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                7. How We Share Information
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We do not sell personal information for money. We may share information in the following circumstances:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>With service providers and subprocessors supporting authentication, hosting, storage, and operations</li>
                <li>With affiliates or advisors under confidentiality obligations</li>
                <li>When required by law, legal process, or valid governmental request</li>
                <li>To enforce terms, protect rights/safety/security, and prevent fraud or abuse</li>
                <li>As part of a merger, acquisition, financing, or asset transaction (with notice where required)</li>
                <li>With your direction or consent</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                8. Data Retention
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We retain personal information for as long as reasonably necessary to provide the Service, fulfill the purposes
                described in this policy, resolve disputes, enforce agreements, and comply with legal obligations.
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Account/profile data while your account is active and for reasonable post-closure periods</li>
                <li>User-submitted content according to account status, settings, and deletion workflows</li>
                <li>Security and operational logs for service integrity and compliance needs</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                9. Your Rights and Choices
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Depending on your location, you may have rights to access, correct, delete, export, or object to certain
                processing of your personal information.
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li><strong>Access:</strong> Request a copy of personal information we hold about you</li>
                <li><strong>Correction:</strong> Ask us to fix inaccurate or incomplete information</li>
                <li><strong>Deletion:</strong> Request deletion of personal information, subject to legal exceptions</li>
                <li><strong>Portability:</strong> Request export where technically feasible and legally required</li>
                <li><strong>Restriction/Objection:</strong> Request limits on certain processing where applicable</li>
                <li><strong>Consent Withdrawal:</strong> Withdraw consent where processing is based on consent</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                10. Cookies and Similar Technologies
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Our website and services may use cookies or similar technologies for authentication, session management,
                security, and product operations.
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>You can manage browser cookies through your browser settings</li>
                <li>Blocking some cookies may impact functionality</li>
                <li>Where required, we will request consent before using non-essential technologies</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                11. International Transfers
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We and our service providers may process information in countries other than your own. Where required,
                we use appropriate transfer safeguards.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                12. Children&apos;s Privacy
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                The Service is not directed to children under 13 (or a higher age where required by local law). If we learn
                we have collected personal information from a child without appropriate authorization, we will take steps to delete it.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                13. Changes to This Policy
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We may update this policy periodically. Material updates will be posted on this page with an updated "Last updated"
                date, and additional notice may be provided when required by law.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                14. Privacy Requests and Complaints
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                For privacy requests or complaints, contact us and include enough detail for verification and response,
                such as your account email, region, and request type.
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Email: privacy@cardoncue.com</li>
                <li>General support: hello@cardoncue.com</li>
                <li>We aim to acknowledge requests promptly and respond within legally required timelines</li>
                <li>We may request additional information to verify identity before fulfilling certain requests</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                15. Contact Us
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                If you have questions about this policy or our data practices, contact:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Email: privacy@cardoncue.com</li>
                <li>Company: CardOnCue</li>
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
