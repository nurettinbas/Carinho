import SwiftData
import SwiftUI

enum SettingsFocusedField: Hashable {
    case fuelPrice
    case privacyRadius
    case newCategory
}

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserCategory.sortOrder) private var categories: [UserCategory]
    @FocusState.Binding var focusedField: SettingsFocusedField?
    @State private var newCategoryName = ""

    var body: some View {
        Section(L10n.categorySection) {
            ForEach(categories) { category in
                HStack {
                    Image(systemName: category.systemImage)
                    Text(category.name)
                    if category.isBuiltIn {
                        Spacer()
                        Text(L10n.categoryBuiltinBadge)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteCategories)

            HStack {
                TextField(L10n.categoryNewPlaceholder, text: $newCategoryName)
                    .focused($focusedField, equals: .newCategory)
                Button(L10n.actionAdd) {
                    addCategory()
                }
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let order = (categories.map(\.sortOrder).max() ?? 0) + 1
        let category = UserCategory(name: name, sortOrder: order)
        modelContext.insert(category)
        try? modelContext.save()
        newCategoryName = ""
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            let category = categories[index]
            guard !category.isBuiltIn else { continue }
            modelContext.delete(category)
        }
        try? modelContext.save()
    }
}
