import Foundation
import SwiftUI

final class FormatDropdownController: ObservableObject {
    @Published var isOpen: Bool = false
    @Published var query: String = ""
    @Published var highlightedIndex: Int = 0
} 