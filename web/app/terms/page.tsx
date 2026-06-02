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
              Terms of Service
            </h1>

            <div className="prose dark:prose-invert max-w-none">
              <p className="text-gray-600 dark:text-gray-300 mb-6">
                <strong>Last updated:</strong> June 2, 2026
              </p>
              <div className="mb-8 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-100 dark:border-blue-800">
                <h2 className="text-xl font-semibold text-gray-900 dark:text-white mt-0 mb-3">
                  Effective Date and Version History
                </h2>
                <ul className="list-disc pl-6 text-gray-700 dark:text-gray-200 mb-0">
                  <li><strong>Effective date:</strong> June 2, 2026 (Version 2.0)</li>
                  <li><strong>Version 2.0:</strong> Replaced legacy terms with expanded service-specific legal framework, arbitration terms, and liability boundaries.</li>
                  <li><strong>Version 1.0:</strong> Initial public website terms.</li>
                </ul>
              </div>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                1. Acceptance of Terms
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                These Terms of Service ("Terms") are a legally binding agreement between you and CardOnCue
                ("CardOnCue," "we," "us," and "our") that governs your access to and use of our websites,
                mobile applications, APIs, and related services (collectively, the "Service"). By accessing or
                using the Service, you agree to these Terms. If you do not agree, do not use the Service.
              </p>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                You represent that you have authority to enter these Terms. If you use the Service on behalf of
                an organization, you represent that you can bind that organization, and "you" includes that organization.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                2. Eligibility and Minors
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                You may use the Service only if you can form a binding contract where you live and your use is not prohibited by law.
                The Service is not directed to children under 13. If you are under the age of majority in your jurisdiction,
                you must have permission from a parent or legal guardian.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                3. Description of the Service
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                CardOnCue helps you store and manage card-related information, including barcode content,
                card metadata, optional card location associations, and related reminders. Features may include
                scanning or importing card details, manual card entry, geolocation-aware reminders, and selected
                API-powered functionality. Features vary by platform, device capability, region, and service availability.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                4. Accounts and Security
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Some features require an account. You agree to provide accurate and current information, keep credentials secure,
                and promptly notify us of unauthorized access. You are responsible for activity occurring through your account.
                We may require identity or account ownership verification before certain account actions.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                5. User Content and Limited License
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                You retain ownership of content you submit to the Service, including card information, images, receipt uploads,
                notes, and related data ("User Content"). You grant CardOnCue a worldwide, non-exclusive, royalty-free license
                to host, process, reproduce, display, and otherwise use User Content solely to operate, secure, improve,
                and provide the Service.
              </p>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                You represent that you have all rights necessary to submit User Content and that your content and conduct do not
                violate law, third-party rights, or these Terms.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                6. Geolocation and Notifications
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Certain features depend on device location permissions, background app behavior, operating system settings,
                and notification permissions. You control these permissions through your device settings. If permissions are
                disabled, location-aware functionality may be limited or unavailable.
              </p>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Geofencing and notification timing are estimates and can be affected by factors outside our control,
                including GPS signal quality, hardware limits, platform restrictions, connectivity, and battery optimization.
                CardOnCue does not guarantee that any reminder, geofence event, or alert will occur at a specific time or place.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                7. Card Data and Third-Party Merchant Systems
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                You are responsible for the accuracy and legality of card data you store or submit. CardOnCue provides
                organizational and display tooling only and is not a card issuer, payment network, loyalty operator, library,
                or merchant.
              </p>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We do not guarantee that any barcode, card number, or related data will be accepted by a third party.
                Merchant policies, scanner quality, account status, and external systems may reject or misread card data.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                8. AI-Assisted Features
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                The Service may include AI-assisted features such as card-brand discovery or metadata suggestions.
                AI outputs may be incomplete, outdated, or incorrect. You are responsible for reviewing and verifying
                AI-generated outputs before relying on them.
              </p>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                You must not use AI-assisted outputs as legal, financial, medical, tax, or other regulated professional advice.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                9. Acceptable Use and Prohibited Conduct
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                You agree not to, and not to attempt to:
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Use the Service for unlawful activity, fraud, or deceptive practices.</li>
                <li>Upload malicious code, interfere with Service integrity, or bypass security controls.</li>
                <li>Scrape, harvest, or exfiltrate data from the Service except as expressly permitted.</li>
                <li>Reverse engineer, decompile, or attempt to derive source code except where prohibited by law.</li>
                <li>Infringe or violate intellectual property, privacy, publicity, or other rights.</li>
                <li>Use automated systems that unreasonably burden the Service or disrupt other users.</li>
                <li>Access non-public APIs or administrative functions without explicit authorization.</li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                10. Third-Party Services and Links
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                The Service may rely on or link to third-party products and services. We do not control and are not responsible
                for third-party services, terms, policies, uptime, or content. Your use of third-party services is governed by
                their terms and policies.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                11. Intellectual Property
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Except for User Content, the Service and all related software, design, text, graphics, trademarks, and other
                intellectual property are owned by CardOnCue or its licensors and protected by law. No rights are granted except
                as expressly set out in these Terms.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                12. Feedback
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                If you provide suggestions, ideas, or feedback, you grant CardOnCue a perpetual, irrevocable, worldwide,
                royalty-free license to use and exploit that feedback without compensation or attribution.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                13. Privacy Policy
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Our <a href="/privacy">Privacy Policy</a> describes how we collect, use, and disclose personal information.
                By using the Service, you acknowledge the Privacy Policy.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                14. Beta Features and Service Changes
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We may label certain features as alpha, beta, preview, or experimental. These features may be changed,
                limited, or discontinued at any time and may be less reliable. We may also modify, suspend, or discontinue
                any part of the Service at any time without liability, to the maximum extent permitted by law.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                15. Disclaimers
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS,
                IMPLIED, STATUTORY, OR OTHERWISE, INCLUDING IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
                PURPOSE, NON-INFRINGEMENT, AND ANY WARRANTIES ARISING FROM COURSE OF DEALING OR USAGE OF TRADE.
              </p>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                CARDONCUE DOES NOT WARRANT THAT THE SERVICE WILL BE UNINTERRUPTED, ERROR-FREE, SECURE, OR FREE OF HARMFUL COMPONENTS,
                OR THAT DATA WILL ALWAYS BE ACCURATE, COMPLETE, OR AVAILABLE.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                16. Limitation of Liability
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                TO THE MAXIMUM EXTENT PERMITTED BY LAW, CARDONCUE AND ITS AFFILIATES, OFFICERS, EMPLOYEES, AGENTS, SUPPLIERS,
                AND LICENSORS WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES,
                OR FOR ANY LOSS OF PROFITS, REVENUE, DATA, GOODWILL, OR BUSINESS INTERRUPTION, ARISING OUT OF OR RELATING TO THE SERVICE.
              </p>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                TO THE MAXIMUM EXTENT PERMITTED BY LAW, CARDONCUE'S TOTAL LIABILITY FOR ALL CLAIMS ARISING OUT OF OR RELATING
                TO THESE TERMS OR THE SERVICE WILL NOT EXCEED THE GREATER OF (A) AMOUNTS YOU PAID TO CARDONCUE FOR THE SERVICE
                IN THE 12 MONTHS BEFORE THE EVENT GIVING RISE TO LIABILITY OR (B) USD $100.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                17. Indemnification
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                You agree to defend, indemnify, and hold harmless CardOnCue and its affiliates, officers, employees, agents,
                suppliers, and licensors from and against any claims, liabilities, damages, losses, and expenses (including
                reasonable attorneys' fees) arising out of or related to your use of the Service, your User Content, or your
                violation of these Terms or applicable law.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                18. Suspension and Termination
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We may suspend or terminate your access to the Service at any time, with or without notice, if we reasonably
                believe you violated these Terms, created legal risk, or threatened Service security or operations. You may
                stop using the Service at any time.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                19. Governing Law and Venue
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                These Terms and any dispute arising out of or relating to these Terms or the Service are governed by the laws
                of the State of California, without regard to conflict-of-laws principles.
              </p>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Subject to the arbitration provisions below, you and CardOnCue consent to the exclusive jurisdiction and venue
                of the state and federal courts located in San Francisco County, California.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                20. Binding Arbitration and Class Action Waiver
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                Please read this section carefully. Except for disputes that qualify for small claims court, you and CardOnCue
                agree to resolve disputes through final and binding individual arbitration.
              </p>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>Arbitration will be administered by the American Arbitration Association under its Consumer Arbitration Rules.</li>
                <li>Arbitration will take place in California, unless the parties agree otherwise.</li>
                <li>The arbitrator may award the same individual remedies available in court.</li>
                <li>
                  YOU AND CARDONCUE WAIVE ANY RIGHT TO A JURY TRIAL AND TO PARTICIPATE IN A CLASS, COLLECTIVE, OR REPRESENTATIVE ACTION.
                </li>
              </ul>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                If a court determines that this class action waiver is unenforceable for a particular claim, then that claim
                may proceed in court only on an individual basis and not as part of a class proceeding.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                21. Export Controls and Sanctions
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                You agree to comply with all applicable export control and sanctions laws. You represent that you are not
                located in, organized under the laws of, or ordinarily resident in any country or region subject to comprehensive
                sanctions, and that you are not on any applicable denied-party list.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                22. Changes to Terms
              </h2>
              <p className="text-gray-600 dark:text-gray-300 mb-4">
                We may update these Terms from time to time. Material changes will be posted with an updated
                "Last updated" date. Continued use of the Service after updated Terms become effective constitutes
                your acceptance of the updated Terms.
              </p>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                23. General Terms
              </h2>
              <ul className="list-disc pl-6 text-gray-600 dark:text-gray-300 mb-4">
                <li>
                  <strong>Entire Agreement:</strong> These Terms and the Privacy Policy are the entire agreement between you and CardOnCue regarding the Service.
                </li>
                <li>
                  <strong>Severability:</strong> If any provision is held unenforceable, the remaining provisions remain in full force.
                </li>
                <li>
                  <strong>No Waiver:</strong> Failure to enforce any provision is not a waiver of future enforcement.
                </li>
                <li>
                  <strong>Assignment:</strong> You may not assign these Terms without our prior written consent. We may assign these Terms as part of a merger, acquisition, or asset transfer.
                </li>
              </ul>

              <h2 className="text-2xl font-semibold text-gray-900 dark:text-white mt-8 mb-4">
                24. Contact Information
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
