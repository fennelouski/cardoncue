import Foundation
import MapKit
import Combine

class LocationSearchService: NSObject, ObservableObject {
    @Published var searchQuery = ""
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter
    private var cancellables = Set<AnyCancellable>()

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()

        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]

        // Debounce search query updates
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                if query.isEmpty {
                    self?.suggestions = []
                } else {
                    self?.completer.queryFragment = query
                }
            }
            .store(in: &cancellables)
    }

    func selectLocation(_ completion: MKLocalSearchCompletion) -> String {
        // Return the full location name
        let title = completion.title
        let subtitle = completion.subtitle

        if subtitle.isEmpty {
            return title
        } else {
            return "\(title), \(subtitle)"
        }
    }
}

extension LocationSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.suggestions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Location search error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.suggestions = []
        }
    }
}
