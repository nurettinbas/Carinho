import SwiftData
import SwiftUI

struct TripFilterChips: View {
    @Query(sort: \UserCategory.sortOrder) private var categories: [UserCategory]
    @Binding var selectedLabel: String?
    @Binding var selectedCategoryID: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: L10n.all, isSelected: selectedLabel == nil && selectedCategoryID == nil) {
                    selectedLabel = nil
                    selectedCategoryID = nil
                }
                ForEach(categories) { category in
                    filterChip(
                        title: category.name,
                        isSelected: selectedCategoryID == category.id.uuidString
                    ) {
                        let id = category.id.uuidString
                        selectedCategoryID = selectedCategoryID == id ? nil : id
                        selectedLabel = nil
                    }
                }
                ForEach(TripLabelOption.allCases.filter { $0 != .work }, id: \.self) { option in
                    filterChip(title: option.rawValue, isSelected: selectedLabel == option.rawValue) {
                        selectedLabel = selectedLabel == option.rawValue ? nil : option.rawValue
                        selectedCategoryID = nil
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 36)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
