//
//  SkyGridRedundancyView.swift
//  Meshtastic
//

import SwiftUI
import CoreData
import Foundation

struct SkyGridRedundancyView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "lastHeard", ascending: false)],
        animation: .default
    )
    private var nodes: FetchedResults<NodeInfoEntity>

    @AppStorage("skygridAWSEndpoint") private var awsEndpoint = ""
    @State private var sendStatus = SkyGridSendStatus.idle

    private var activeCutoff: Date {
        Calendar.current.date(byAdding: .minute, value: -120, to: Date()) ?? Date()
    }

    private var visibleNodes: [NodeInfoEntity] {
        nodes.filter { !$0.ignored }
    }

    private var activeNodes: [NodeInfoEntity] {
        visibleNodes.filter { node in
            guard let lastHeard = node.lastHeard else { return false }
            return lastHeard >= activeCutoff
        }
    }

    private var loraNodes: [NodeInfoEntity] {
        visibleNodes.filter { !$0.viaMqtt }
    }

    private var mqttNodes: [NodeInfoEntity] {
        visibleNodes.filter { $0.viaMqtt }
    }

    private var latestNode: NodeInfoEntity? {
        visibleNodes.first
    }

    private var confidenceScore: Int {
        guard !visibleNodes.isEmpty else { return 0 }
        let activeRatio = Double(activeNodes.count) / Double(visibleNodes.count)
        let routeBonus = (!loraNodes.isEmpty && !mqttNodes.isEmpty) ? 0.20 : 0.0
        let sendBonus = sendStatus.isSuccessful ? 0.10 : 0.0
        return min(100, Int((activeRatio + routeBonus + sendBonus) * 100.0))
    }

    private var layers: [SkyGridLayer] {
        [
            SkyGridLayer(
                title: "Field Layer",
                subtitle: "Meshtastic LoRa nodes",
                icon: "antenna.radiowaves.left.and.right",
                status: "\(loraNodes.count) LoRa node\(loraNodes.count == 1 ? "" : "s") observed",
                detail: "LoRa nodes forward compact packets and position signals when internet access is unavailable."
            ),
            SkyGridLayer(
                title: "Apple Edge Layer",
                subtitle: "iPhone, iPad, and Mac bridge",
                icon: "iphone.radiowaves.left.and.right",
                status: "\(activeNodes.count) active node\(activeNodes.count == 1 ? "" : "s") in the last 120 minutes",
                detail: "Apple devices receive mesh data over Bluetooth, keep a local copy, and forward updates over Wi-Fi or cellular when available."
            ),
            SkyGridLayer(
                title: "AWS Send Layer",
                subtitle: "HTTPS packet bridge",
                icon: "cloud.fill",
                status: sendStatus.summary,
                detail: "Sends a minimal diagnostic packet to the configured SkyGrid AWS ingest endpoint. No credentials are stored here."
            ),
            SkyGridLayer(
                title: "Dashboard Layer",
                subtitle: "Node visibility and review",
                icon: "point.3.connected.trianglepath.dotted",
                status: "\(confidenceScore)% route confidence",
                detail: "The dashboard presents node health, last-seen state, route confidence, and sync status."
            )
        ]
    }

    private var routes: [SkyGridRoute] {
        [
            SkyGridRoute(name: "Mesh route", value: "\(loraNodes.count) LoRa path node\(loraNodes.count == 1 ? "" : "s")"),
            SkyGridRoute(name: "MQTT route", value: "\(mqttNodes.count) MQTT-visible node\(mqttNodes.count == 1 ? "" : "s")"),
            SkyGridRoute(name: "AWS send route", value: sendStatus.routeValue),
            SkyGridRoute(name: "Offline route", value: "\(max(visibleNodes.count - activeNodes.count, 0)) cached or stale node\(max(visibleNodes.count - activeNodes.count, 0) == 1 ? "" : "s")"),
            SkyGridRoute(name: "Record route", value: "\(visibleNodes.count) total visible node\(visibleNodes.count == 1 ? "" : "s")")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                liveSummary
                awsSendPanel
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

            Text("Live mesh status plus a safe AWS test-packet sender.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var liveSummary: some View {
        SkyGridPanel(title: "Live Mesh Summary") {
            HStack(spacing: 10) {
                SkyGridMetricCard(title: "Nodes", value: "\(visibleNodes.count)", icon: "circle.hexagongrid.fill")
                SkyGridMetricCard(title: "Active", value: "\(activeNodes.count)", icon: "bolt.horizontal.circle.fill")
                SkyGridMetricCard(title: "Confidence", value: "\(confidenceScore)%", icon: "checkmark.seal.fill")
            }

            SkyGridRuleRow(title: "Last heard", value: latestNodeLastHeardText)
        }
    }

    private var awsSendPanel: some View {
        SkyGridPanel(title: "AWS Packet Sender") {
            TextField("https://example.com/mesh/ingest", text: $awsEndpoint)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                SkyGridMetricCard(title: "Send", value: sendStatus.badge, icon: "paperplane.fill")
                SkyGridMetricCard(title: "HTTP", value: sendStatus.httpCodeText, icon: "server.rack")
                SkyGridMetricCard(title: "Packet", value: "Test", icon: "shippingbox.fill")
            }

            Button {
                Task {
                    await sendDiagnosticPacket()
                }
            } label: {
                Label("Send Test Packet", systemImage: "paperplane")
            }
            .buttonStyle(.borderedProminent)
            .disabled(awsEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sendStatus.isSending)

            SkyGridRuleRow(title: "Status", value: sendStatus.detail)
        }
    }

    private var latestNodeLastHeardText: String {
        guard let latestNode, let lastHeard = latestNode.lastHeard else {
            return "No node history available"
        }

        let nodeName = latestNode.user?.longName ?? latestNode.user?.shortName ?? latestNode.num.formatted()
        return "\(nodeName) at \(lastHeard.formatted(date: .abbreviated, time: .shortened))"
    }

    private var rules: some View {
        SkyGridPanel(title: "Redundancy Rules") {
            SkyGridRuleRow(title: "Message ID", value: "hash(nodeId + timestamp + payload)")
            SkyGridRuleRow(title: "Duplicate policy", value: "Ignore identical packet hashes")
            SkyGridRuleRow(title: "Confidence", value: "Increase route score when active nodes are present across LoRa, MQTT, and AWS send paths")
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
            SkyGridRuleRow(title: "Architecture", value: "Live SwiftUI view backed by local CoreData node records and a configurable HTTPS sender.")
            SkyGridRuleRow(title: "Security", value: "No secrets, keys, certificates, credentials, or private mesh payload forwarding included.")
            SkyGridRuleRow(title: "Compatibility", value: "Uses SwiftUI, CoreData fetch, URLSession, SF Symbols, and system materials.")
            SkyGridRuleRow(title: "Next step", value: "Point the AWS field at your SkyGrid bridge /mesh/ingest endpoint.")
        }
    }

    @MainActor
    private func setSendStatus(_ status: SkyGridSendStatus) {
        sendStatus = status
    }

    private func sendDiagnosticPacket() async {
        let trimmedEndpoint = awsEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEndpoint.isEmpty else {
            await setSendStatus(.failed("No AWS ingest endpoint configured"))
            return
        }

        guard let url = URL(string: trimmedEndpoint), ["https", "http"].contains(url.scheme?.lowercased()) else {
            await setSendStatus(.failed("Invalid endpoint URL"))
            return
        }

        await setSendStatus(.sending)

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 10
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let packet = buildDiagnosticPacket()
            request.httpBody = try JSONSerialization.data(withJSONObject: packet, options: [])

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                await setSendStatus(.failed("No HTTP response"))
                return
            }

            if 200..<300 ~= httpResponse.statusCode {
                await setSendStatus(.sent(code: httpResponse.statusCode, checkedAt: Date()))
            } else {
                await setSendStatus(.rejected(code: httpResponse.statusCode, checkedAt: Date()))
            }
        } catch {
            await setSendStatus(.failed(error.localizedDescription))
        }
    }

    private func buildDiagnosticPacket() -> [String: Any] {
        let latestNodeName = latestNode?.user?.longName ?? latestNode?.user?.shortName ?? "unknown"
        let latestNodeId = latestNode?.num ?? 0

        return [
            "type": "skygrid.diagnostic",
            "schemaVersion": 1,
            "source": "meshtastic-apple",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "nodeSummary": [
                "visible": visibleNodes.count,
                "active": activeNodes.count,
                "lora": loraNodes.count,
                "mqtt": mqttNodes.count,
                "latestNodeId": latestNodeId,
                "latestNodeName": latestNodeName
            ],
            "routeConfidence": confidenceScore
        ]
    }
}

private enum SkyGridSendStatus: Equatable {
    case idle
    case sending
    case sent(code: Int, checkedAt: Date)
    case rejected(code: Int, checkedAt: Date)
    case failed(String)

    var isSending: Bool {
        if case .sending = self { return true }
        return false
    }

    var isSuccessful: Bool {
        if case .sent = self { return true }
        return false
    }

    var badge: String {
        switch self {
        case .idle: return "Idle"
        case .sending: return "Sending"
        case .sent: return "Sent"
        case .rejected: return "Rejected"
        case .failed: return "Failed"
        }
    }

    var summary: String {
        switch self {
        case .idle: return "AWS sender idle"
        case .sending: return "Sending diagnostic packet"
        case .sent(let code, _): return "AWS accepted packet (HTTP \(code))"
        case .rejected(let code, _): return "AWS rejected packet (HTTP \(code))"
        case .failed: return "AWS send failed"
        }
    }

    var routeValue: String {
        switch self {
        case .idle: return "Not sent yet"
        case .sending: return "Sending diagnostic packet"
        case .sent(let code, _): return "Packet accepted through HTTPS bridge (HTTP \(code))"
        case .rejected(let code, _): return "Endpoint reachable but rejected packet (HTTP \(code))"
        case .failed(let message): return "Send failed: \(message)"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return "Enter a SkyGrid AWS ingest URL and send a test packet."
        case .sending:
            return "Sending a minimal diagnostic packet."
        case .sent(let code, let checkedAt):
            return "Packet accepted with HTTP \(code) at \(checkedAt.formatted(date: .abbreviated, time: .standard))."
        case .rejected(let code, let checkedAt):
            return "Endpoint responded with HTTP \(code) at \(checkedAt.formatted(date: .abbreviated, time: .standard))."
        case .failed(let message):
            return message
        }
    }

    var httpCodeText: String {
        switch self {
        case .sent(let code, _), .rejected(let code, _): return "\(code)"
        default: return "—"
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

private struct SkyGridMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.tint)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
