import SwiftUI

struct DepartmentPicker: View {
    @Binding var departmentSlug: String
    let departments: [Department]

    var body: some View {
        if departments.count <= 1 {
            EmptyView()
        } else if departments.count == 2 {
            TwoDepartmentToggle(departmentSlug: $departmentSlug, departments: departments)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Department")
                    .font(.subheadline.bold())
                Picker("Department", selection: $departmentSlug) {
                    ForEach(departments) { dept in
                        Text(dept.label).tag(dept.slug)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

private struct TwoDepartmentToggle: View {
    @Binding var departmentSlug: String
    let departments: [Department]

    var body: some View {
        let sorted = departments.sorted { $0.sort_order < $1.sort_order }
        GeometryReader { geometry in
            let halfWidth = (geometry.size.width - 8) / 2
            let sliderHeight = geometry.size.height - 8
            let selectedIndex = sorted.firstIndex(where: { $0.slug == departmentSlug }) ?? 0
            let color = DepartmentPalette.color(for: selectedIndex)

            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(Color(red: color.red, green: color.green, blue: color.blue))
                    .frame(width: halfWidth, height: sliderHeight)
                    .offset(x: 4 + (selectedIndex == 1 ? halfWidth : 0))
                    .animation(.spring(response: 0.32, dampingFraction: 0.78), value: departmentSlug)
                HStack(spacing: 0) {
                    ForEach(sorted) { dept in
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                departmentSlug = dept.slug
                            }
                        } label: {
                            Text(dept.label)
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .foregroundStyle(departmentSlug == dept.slug ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
    }
}

struct DepartmentBadge: View {
    let slug: String
    let label: String
    let colorIndex: Int

    var body: some View {
        let color = DepartmentPalette.color(for: colorIndex)
        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(Capsule().fill(Color(red: color.red, green: color.green, blue: color.blue)))
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .accessibilityLabel("\(label) department")
            .accessibilityIdentifier(slug)
    }
}

struct DepartmentCompletionBar: View {
    let completions: [DepartmentCompletion]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completed by Department")
                .font(.headline)
                .foregroundStyle(.primary)

            if completions.allSatisfy({ $0.completed_count == 0 }) {
                Text("No completed tickets yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
            } else {
                let total = max(completions.reduce(0) { $0 + $1.completed_count }, 1)
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(Array(completions.enumerated()), id: \.element.id) { index, item in
                            let fraction = CGFloat(item.completed_count) / CGFloat(total)
                            let color = DepartmentPalette.color(for: index)
                            Rectangle()
                                .fill(Color(red: color.red, green: color.green, blue: color.blue))
                                .frame(width: geometry.size.width * fraction)
                        }
                    }
                }
                .frame(height: 28)
                .clipShape(Capsule())

                ForEach(Array(completions.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Circle()
                            .fill(paletteColor(index))
                            .frame(width: 10, height: 10)
                        Text(item.label)
                        Spacer()
                        Text("\(item.completed_count)")
                            .font(.subheadline.bold())
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .analyticsPanel()
        .padding(.horizontal)
    }

    private func paletteColor(_ index: Int) -> Color {
        let c = DepartmentPalette.color(for: index)
        return Color(red: c.red, green: c.green, blue: c.blue)
    }
}
