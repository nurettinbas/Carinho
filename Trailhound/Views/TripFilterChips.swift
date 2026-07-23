import SwiftData
import SwiftUI

struct TripFilterChips: View {
    @Query(sort: \UserCategory.sortOrder) private var categories: [UserCategory]
    @Binding var selectedCategoryID: String?

    @Namespace private var chipNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectionKey: String {
        if let selectedCategoryID { return "category:\(selectedCategoryID)" }
        return "all"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(
                        title: L10n.all,
                        key: "all",
                        isSelected: selectedCategoryID == nil
                    ) {
                        selectedCategoryID = nil
                    }
                    ForEach(categories) { category in
                        let id = category.id.uuidString
                        filterChip(
                            title: category.name,
                            key: "category:\(id)",
                            isSelected: selectedCategoryID == id
                        ) {
                            selectedCategoryID = selectedCategoryID == id ? nil : id
                        }
                    }
                }
                .padding(.horizontal)
                .animation(reduceMotion ? nil : TrailhoundMotion.cardSpring, value: selectionKey)
            }
            .onChange(of: selectionKey) { _, newKey in
                revealChip(withID: newKey, using: proxy)
            }
        }
        .frame(height: 36)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private func revealChip(withID id: String, using proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo(id, anchor: .center)
        } else {
            withAnimation(TrailhoundMotion.cardSpring) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    private func filterChip(
        title: String,
        key: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        GlassFilterChip(
            title: title,
            isSelected: isSelected,
            namespace: chipNamespace,
            highlightID: "tripFilterHighlight",
            action: {
                if reduceMotion {
                    action()
                } else {
                    withAnimation(TrailhoundMotion.cardSpring) {
                        action()
                    }
                }
            }
        )
        .id(key)
    }
}
