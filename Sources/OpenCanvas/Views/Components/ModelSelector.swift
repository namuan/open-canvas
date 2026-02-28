import SwiftUI

struct ModelSelector: View {
    @Binding var selectedModel: String?
    let availableModels: [OCModel]
    let isLoading: Bool
    let fontSize: CGFloat
    
    @State private var isExpanded = false
    @State private var searchText = ""
    
    private var filteredModels: [OCModel] {
        if searchText.isEmpty {
            return availableModels
        }
        return availableModels.filter { model in
            model.name.localizedCaseInsensitiveContains(searchText) ||
            model.providerID.localizedCaseInsensitiveContains(searchText) ||
            model.id.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var selectedModelDisplayName: String {
        guard let selected = selectedModel else { return "Select Model" }
        if let model = availableModels.first(where: { $0.fullID == selected }) {
            return model.displayName
        }
        return selected
    }
    
    var body: some View {
        Menu {
            if isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .foregroundStyle(.secondary)
                }
            } else if filteredModels.isEmpty {
                Text("No models available")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(filteredModels) { model in
                        Button {
                            selectedModel = model.fullID
                            isExpanded = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.displayName)
                                        .font(.system(size: 12))
                                    Text(model.providerID)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if model.fullID == selectedModel {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } header: {
                    Text("\(filteredModels.count) models")
                }
            }
        } label: {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: max(8, fontSize - 3)))
                }
                Text(selectedModelDisplayName)
                    .font(.system(size: max(9, fontSize - 2)))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.ocComposerBackground)
            .cornerRadius(6)
            .foregroundStyle(.primary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 220)
    }
}
