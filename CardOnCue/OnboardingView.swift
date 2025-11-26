import SwiftUI
import Clerk

// PreferenceKey to track scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct OnboardingView: View {
    @Environment(\.clerk) private var clerk
    @EnvironmentObject var onboardingService: OnboardingService
    @State private var currentPage = 0
    @State private var showSignIn = false
    @State private var scrollOffset: CGFloat = 0

    private let pages = [
        OnboardingPage(
            title: NSLocalizedString("welcome_title", comment: "Welcome screen title"),
            subtitle: NSLocalizedString("welcome_subtitle", comment: "Welcome screen subtitle"),
            description: NSLocalizedString("welcome_description", comment: "Welcome screen description"),
            systemImage: "AppLogo",
            color: .appPrimary,
            isCustomImage: true
        ),
        OnboardingPage(
            title: NSLocalizedString("scan_store_title", comment: "Scan & Store screen title"),
            subtitle: NSLocalizedString("scan_store_subtitle", comment: "Scan & Store screen subtitle"),
            description: NSLocalizedString("scan_store_description", comment: "Scan & Store screen description"),
            systemImage: "camera.viewfinder",
            color: .appBlue,
            isCustomImage: false
        ),
        OnboardingPage(
            title: NSLocalizedString("location_aware_title", comment: "Location Aware screen title"),
            subtitle: NSLocalizedString("location_aware_subtitle", comment: "Location Aware screen subtitle"),
            description: NSLocalizedString("location_aware_description", comment: "Location Aware screen description"),
            systemImage: "location.circle.fill",
            color: .appGreen,
            isCustomImage: false
        ),
        OnboardingPage(
            title: NSLocalizedString("privacy_first_title", comment: "Privacy First screen title"),
            subtitle: NSLocalizedString("privacy_first_subtitle", comment: "Privacy First screen subtitle"),
            description: NSLocalizedString("privacy_first_description", comment: "Privacy First screen description"),
            systemImage: "hand.raised.fill",
            color: .appBlue,
            isCustomImage: false
        )
    ]

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content with gradient overlays
                ZStack {
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            OnboardingPageView(
                                page: pages[index]
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                    }

                    // Top gradient fade
                    VStack {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.appBackground.opacity(1.0),
                                Color.appBackground.opacity(0.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                        .allowsHitTesting(false)

                        Spacer()
                    }

                    // Bottom gradient fade
                    VStack {
                        Spacer()

                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.appBackground.opacity(0.0),
                                Color.appBackground.opacity(1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                        .allowsHitTesting(false)
                    }
                }

                Spacer(minLength: 0)

                // Navigation buttons
                VStack(spacing: 16) {
                    // Main action button (Next or Get Started)
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        Text(currentPage < pages.count - 1
                            ? NSLocalizedString("next_button", comment: "Next button")
                            : NSLocalizedString("get_started", comment: "Get Started button"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.appPrimary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    // Skip button (fades out on last page)
                    Button(action: {
                        completeOnboarding()
                    }) {
                        Text(NSLocalizedString("skip_button", comment: "Skip button"))
                            .font(.subheadline)
                            .foregroundColor(.appLightGray)
                    }
                    .opacity(currentPage < pages.count - 1 ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: currentPage)
                }
                .padding(.top, 16)
                .padding(.bottom, 16)

                // Page indicator at the bottom
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? pages[index].color : Color.appLightGray)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showSignIn) {
            AuthView()
                .environment(\.clerk, clerk)
        }
        .overlay(alignment: .topTrailing) {
            if clerk.user == nil {
                SignInButton(
                    scrollOffset: scrollOffset,
                    action: { showSignIn = true }
                )
            }
        }
    }

    private func completeOnboarding() {
        withAnimation {
            onboardingService.completeOnboarding()
        }
    }
}

// Sign In button that responds to scroll offset
struct SignInButton: View {
    let scrollOffset: CGFloat
    let action: () -> Void

    private var scrollProgress: CGFloat {
        // Progress from 0 (at top) to 1 (scrolled down)
        // Transition happens over first 100 points of scroll
        min(max(-scrollOffset / 100, 0), 1)
    }

    private var backgroundOpacity: CGFloat {
        // Fade background from 0.1 to 0 as user scrolls
        0.1 * (1 - scrollProgress)
    }

    private var horizontalPadding: CGFloat {
        // Move from 24 to 16 as user scrolls
        24 - (8 * scrollProgress)
    }

    private var verticalPadding: CGFloat {
        // Move from 16 to 8 as user scrolls
        16 - (8 * scrollProgress)
    }

    private var buttonPadding: CGFloat {
        // Reduce button padding as user scrolls
        16 - (4 * scrollProgress)
    }

    var body: some View {
        Button(action: action) {
            Text("Sign In")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.appPrimary)
                .padding(.horizontal, buttonPadding)
                .padding(.vertical, 8)
                .background(Color.appPrimary.opacity(backgroundOpacity))
                .cornerRadius(8)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, verticalPadding)
        .animation(.easeOut(duration: 0.2), value: scrollOffset)
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let systemImage: String
    let color: Color
    let isCustomImage: Bool
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // GeometryReader to track scroll offset
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("scroll")).minY
                    )
                }
                .frame(height: 0)

                VStack(spacing: 32) {
                    // Top spacing to account for sign-in button area
                    Spacer(minLength: 60)

                    // Icon
                    if page.isCustomImage {
                        Image(page.systemImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .cornerRadius(20)
                    } else {
                        ZStack {
                            Circle()
                                .fill(page.color.opacity(0.1))
                                .frame(width: 120, height: 120)

                            Image(systemName: page.systemImage)
                                .font(.system(size: 48))
                                .foregroundColor(page.color)
                        }
                    }

                    // Content
                    VStack(spacing: 16) {
                        Text(page.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.appBlue)
                            .multilineTextAlignment(.center)

                        Text(page.subtitle)
                            .font(.title2)
                            .foregroundColor(.appGreen)
                            .multilineTextAlignment(.center)

                        Text(page.description)
                            .font(.body)
                            .foregroundColor(.appLightGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .lineSpacing(4)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .coordinateSpace(name: "scroll")
    }
}

#Preview {
    OnboardingView()
        .environmentObject(OnboardingService())
        .environment(\.clerk, Clerk.shared)
}
