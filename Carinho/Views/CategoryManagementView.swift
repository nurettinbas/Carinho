import SwiftData
import SwiftUI

enum SettingsFocusedField: Hashable {
    case fuelConsumption
    case fuelPrice
    case privacyRadius
    case newCategory
    case newVehicle
    case vehicleConsumption
    case evChargePrice
}

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserCategory.sortOrder) private var categories: [UserCategory]
    @FocusState.Binding var focusedField: SettingsFocusedField?
    @State private var newCategoryName = ""

    var body: some View {
        Section("Kategoriler") {
            ForEach(categories) { category in
                HStack {
                    Image(systemName: category.systemImage)
                    Text(category.name)
                    if category.isBuiltIn {
                        Spacer()
                        Text("Varsayılan")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteCategories)

            HStack {
                TextField("Yeni kategori", text: $newCategoryName)
                    .focused($focusedField, equals: .newCategory)
                Button("Ekle") {
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
