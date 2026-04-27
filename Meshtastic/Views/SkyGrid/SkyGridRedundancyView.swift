//
//  SkyGridRedundancyView.swift
//  Meshtastic
//

import SwiftUI

struct SkyGridRedundancyView: View {
    private let layers: [SkyGridLayer] = [
        SkyGridLayer(
            title: "Field Layer",
            subtitle: "Meshtastic LoRa nodes",
            icon: "antenna.radiowaves.left.and.right",
            status: "Offline relay",
            detail: "LoRa nodes forward compact packets and position signals when internet access is unavailable."
        ),
        SkyGridLayer(
            title: "Apple Edge Layer",
            subtitle: "iPhone, iPad, and Mac bridge",
            icon: "iphone.radiowaves.left.and.right",
            status: "Cache and uplink",
            detail: "Apple devices receive mesh data over Bluetooth, keep a local copy, and forward updates over Wi-Fi or cellular when available."
        ),
        SkyGridLayer(
            title: "Cloud Sync Layer",
            subtitle: "IoT ingest, processing, and storage",
            icon: "cloud.fill",
            status: "Canonical record",
            detail: "Cloud services normalize packets, calculate hashes, remove duplicates, and preserve sync records."
        ),
        SkyGridLayer(
            title: "Dashboard Layer",
            subtitle: "Node visibility and review",
            icon: "point.3.connected.trianglepath.dotted",
            status: "Read-only overview",
            detail: "The dashboard presents node health, last-seen state, route confidence, and sync status."
        )
    ]

    private let routes: [SkyGridRoute] = [
        SkyGridRoute(name: "Mesh route", value: "Node → Node → Apple device → Cloud"),
        SkyGridRoute(name: "Direct route", value: "Apple device → Wi-Fi or cellular → Cloud"),
        SkyGridRoute(name: "Offline route", value: "Apple local cache → Sync later"),
        SkyGridRoute(name: "Record route", value: "Ingest → Normalize → Store → Display")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                rules
                layerMap
                routeMap
                reviewChecklist
            }
            .padding()
        }
        .navigationTitle("SkyGrid")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("SkyGrid Redundancy", systemImage: "network")
                .font(.title2)
                .fontWeight(.semibold)

            Text("A read-only map for LoRa mesh relay, Apple edge caching, cloud sync, and dashboard visibility.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rules: some View {
        SkyGridPanel(title: "Redundancy Rules") {
            SkyGridRuleRow(title: "Message ID", value: "hash(nodeId + timestamp + payload)")
            SkyGridRuleRow(title: "Duplicate policy", value: "Ignore identical packet hashes")
            SkyGridRuleRow(title: "Confidence", value: "Increase route score when a packet arrives through more than one path")
            SkyGridRuleRow(title: "Fallback", value: "Store locally until sync is available")
        }
    }

    private var layerMap: some View {
        SkyGridPanel(title: "Layer Map") {
            ForEach(layers) { layer in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: layer.icon)
                        .font(.title3)
                        .frame(width: 28)
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(layer.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(layer.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(layer.status)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(layer.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var routeMap: some View {
        SkyGridPanel(title: "Route Map") {
            ForEach(routes) { route in
                SkyGridRuleRow(title: route.name, value: route.value)
            }
        }
    }

    private var reviewChecklist: some View {
        SkyGridPanel(title: "Codex Review Checklist") {
            SkyGridRuleRow(title: "Architecture", value: "Contained SwiftUI view; no packet transport behavior changed.")
            SkyGridRuleRow(title: "Security", value: "No secrets, keys, certificates, or credentials included.")
            SkyGridRuleRow(title: "Compatibility", value: "Uses SwiftUI, SF Symbols, and standard system materials.")
            SkyGridRuleRow(title: "Next step", value: "Add this view to a settings, diagnostics, or node-visibility navigation route.")
        }
    }
}

private struct SkyGridPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SkyGridLayer: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let status: String
    let detail: String
}

private struct SkyGridRoute: Identifiable {
    let id = UUID()
    let name: String
    let value: String
}

private struct SkyGridRuleRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        SkyGridRedundancyView()
    }
}
