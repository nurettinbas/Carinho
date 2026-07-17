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
        Button {
            if reduceMotion {
                action()
            } else {
                withAnimation(TrailhoundMotion.cardSpring) {
                    action()
                }
            }
        } label: {
            Text(title)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "tripFilterHighlight", in: chipNamespace)
                    } else {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                    }
                }
        }
        .buttonStyle(.plain)
        .id(key)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
