//
//  FavoritesTab.swift
//  Easydict
//
//  Created by Copilot on 2025/11/19.
//  Copyright © 2025 izual. All rights reserved.
//

import AppKit
import Defaults
import SwiftUI
import UniformTypeIdentifiers

// MARK: - FavoritesTab

/// Displays favorites and history in a searchable management view.
struct FavoritesTab: View {
    // MARK: Internal

    var body: some View {
        VStack(spacing: 12) {
            Picker(selection: $selectedSection) {
                Text("history.tab").tag(FavoritesSection.history)
                Text("favorites.tab").tag(FavoritesSection.favorites)
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            HStack(spacing: 10) {
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 220)

                Picker("Sort", selection: $sort) {
                    ForEach(QueryRecordSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .frame(width: 140)

                Toggle("Date Range", isOn: $usesDateRange)
                    .toggleStyle(.checkbox)

                DatePicker("From", selection: $startDate, displayedComponents: .date)
                    .disabled(!usesDateRange)
                    .labelsHidden()

                DatePicker("To", selection: $endDate, displayedComponents: .date)
                    .disabled(!usesDateRange)
                    .labelsHidden()

                Spacer()
            }

            HStack {
                Text(headerTitleKey)
                    .font(.headline)
                Text("\(displayedRecords.count)")
                    .foregroundColor(.secondary)
                Spacer()

                Button(selectionButtonTitle) {
                    toggleSelectDisplayedRecords()
                }
                .disabled(displayedRecords.isEmpty)

                Button(role: .destructive) {
                    deleteSelectedRecords()
                } label: {
                    Label("common.delete", systemImage: "trash")
                }
                .disabled(selectedRecordIDs.isEmpty)

                Menu {
                    Button("CSV") { exportDisplayedRecords(format: .csv) }
                    Button("TSV") { exportDisplayedRecords(format: .tsv) }
                    Button("APKG") { exportDisplayedRecords(format: .apkg) }
                } label: {
                    Label("common.export", systemImage: "square.and.arrow.up")
                }
                .disabled(exportRecords.isEmpty)
            }

            if displayedRecords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: emptyStateImageName)
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(emptyStateTitleKey)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedRecordIDs) {
                    ForEach(displayedRecords) { record in
                        QueryRecordRow(record: record, onDelete: {
                            removeRecord(record)
                        })
                        .tag(record.id)
                    }
                }
            }
        }
        .borderedCard()
        .padding(20)
        .onReceive(Defaults.publisher(.favorites)) { change in
            favorites = change.newValue
            selectedRecordIDs = selectedRecordIDs.intersection(Set(displayedRecords.map(\.id)))
        }
        .onReceive(Defaults.publisher(.queryHistory)) { change in
            history = change.newValue
            selectedRecordIDs = selectedRecordIDs.intersection(Set(displayedRecords.map(\.id)))
        }
        .onChange(of: selectedSection) { _ in
            selectedRecordIDs.removeAll()
        }
        .onChange(of: searchText) { _ in
            selectedRecordIDs.removeAll()
        }
        .onChange(of: usesDateRange) { _ in
            selectedRecordIDs.removeAll()
        }
        .onAppear {
            loadRecords()
        }
    }

    // MARK: Private

    @State private var selectedSection: FavoritesSection = .favorites
    @State private var favorites: [QueryRecord] = []
    @State private var history: [QueryRecord] = []
    @State private var searchText = ""
    @State private var sort: QueryRecordSort = .newest
    @State private var selectedRecordIDs = Set<UUID>()
    @State private var usesDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()

    private var displayedRecords: [QueryRecord] {
        QueryRecordManager.shared.filteredRecords(
            for: selectedSection.recordType,
            keyword: searchText,
            sort: sort,
            startDate: usesDateRange ? Calendar.current.startOfDay(for: startDate) : nil,
            endDate: usesDateRange ? Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) : nil
        )
    }

    private var exportRecords: [QueryRecord] {
        if selectedRecordIDs.isEmpty {
            return displayedRecords
        }
        return displayedRecords.filter { selectedRecordIDs.contains($0.id) }
    }

    private var headerTitleKey: LocalizedStringKey {
        selectedSection == .favorites ? "favorites.title" : "history.title"
    }

    private var emptyStateTitleKey: LocalizedStringKey {
        selectedSection == .favorites ? "favorites.empty" : "history.empty"
    }

    private var emptyStateImageName: String {
        selectedSection == .favorites ? "star.slash" : "clock.badge.xmark"
    }

    private var selectionButtonTitle: String {
        selectedRecordIDs.count == displayedRecords.count && !displayedRecords.isEmpty ? "Deselect All" : "Select All"
    }

    /// Removes a record from the currently selected section.
    private func removeRecord(_ record: QueryRecord) {
        QueryRecordManager.shared.removeRecord(id: record.id, from: selectedSection.recordType)
        selectedRecordIDs.remove(record.id)
    }

    private func deleteSelectedRecords() {
        for id in selectedRecordIDs {
            QueryRecordManager.shared.removeRecord(id: id, from: selectedSection.recordType)
        }
        selectedRecordIDs.removeAll()
    }

    private func toggleSelectDisplayedRecords() {
        let displayedIDs = Set(displayedRecords.map(\.id))
        if selectedRecordIDs == displayedIDs {
            selectedRecordIDs.removeAll()
        } else {
            selectedRecordIDs = displayedIDs
        }
    }

    /// Loads the favorites and history data for display.
    private func loadRecords() {
        favorites = QueryRecordManager.shared.getAllRecords(for: .favorites)
        history = QueryRecordManager.shared.getAllRecords(for: .history)
    }

    private func exportDisplayedRecords(format: FavoriteExportFormat) {
        let records = exportRecords
        guard !records.isEmpty else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [format.contentType]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = suggestedExportFileName(format: format)
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else {
                return
            }
            do {
                try FavoriteAnkiExporter.export(records: records, format: format, to: url)
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            } catch {
                logError("Export records failed: \(error)")
            }
        }
    }

    /// Builds a suggested export filename with a timestamp.
    private func suggestedExportFileName(format: FavoriteExportFormat) -> String {
        let sectionName = selectedSection == .favorites ? "Favorites" : "History"
        let dateString = FavoriteAnkiExporter.fileNameFormatter.string(from: Date())
        return "Easydict \(sectionName) \(dateString).\(format.fileExtension)"
    }
}

// MARK: - FavoritesSection

/// Represents the section shown in the favorites tab.
private enum FavoritesSection: String, CaseIterable, Identifiable {
    case favorites
    case history

    // MARK: Internal

    var id: String { rawValue }

    var recordType: QueryRecordManager.RecordType {
        switch self {
        case .favorites: return .favorites
        case .history: return .history
        }
    }
}

// MARK: - QueryRecordRow

/// Displays a query record with quick actions.
struct QueryRecordRow: View {
    // MARK: Internal

    let record: QueryRecord
    let onDelete: () -> ()

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(record.queryText)
                        .font(.body)
                        .lineLimit(1)
                    if let phonetic = record.phonetic, !phonetic.isEmpty {
                        Text(phonetic)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if !summaryText.isEmpty {
                    Text(summaryText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Text(Self.timestampFormatter.string(from: record.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                Button {
                    performQuery()
                } label: {
                    Label("common.query", systemImage: "magnifyingglass")
                        .labelStyle(.titleAndIcon)
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("common.delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Private

    /// Formats timestamps without relative updates.
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var summaryText: String {
        [record.bestTranslation, record.bestDefinition]
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }

    /// Replays the query stored in this record.
    private func performQuery() {
        let windowType = Defaults[.shortcutSelectTranslateWindowType]
        let windowManager = EZWindowManager.shared()
        windowManager.showFloating(windowType, queryText: record.queryText, autoQuery: true, actionType: .inputQuery)
    }
}

// MARK: - FavoriteExportFormat

private enum FavoriteExportFormat {
    case csv
    case tsv
    case apkg

    // MARK: Internal

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .tsv: return "tsv"
        case .apkg: return "apkg"
        }
    }

    var contentType: UTType {
        switch self {
        case .csv:
            return .commaSeparatedText
        case .tsv:
            return UTType(filenameExtension: "tsv") ?? .plainText
        case .apkg:
            return UTType(filenameExtension: "apkg") ?? .data
        }
    }
}

// MARK: - FavoriteAnkiExporter

private enum FavoriteAnkiExporter {
    // MARK: Internal

    static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter
    }()

    static func export(records: [QueryRecord], format: FavoriteExportFormat, to url: URL) throws {
        switch format {
        case .csv:
            try makeDelimitedText(records: records, delimiter: ",").write(to: url, atomically: true, encoding: .utf8)
        case .tsv:
            try makeDelimitedText(records: records, delimiter: "\t").write(to: url, atomically: true, encoding: .utf8)
        case .apkg:
            try makeAPKG(records: records, to: url)
        }
    }

    // MARK: Private

    private static func makeDelimitedText(records: [QueryRecord], delimiter: String) -> String {
        let template = AnkiCardTemplate.builtIns.first { $0.id == "full-card" } ?? AnkiCardTemplate.builtIns[0]
        let header = ["Front", "Back"].joined(separator: delimiter)
        let rows = records.map { record in
            [template.renderFront(record: record), template.renderBack(record: record)]
                .map { escaped($0, delimiter: delimiter) }
                .joined(separator: delimiter)
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private static func escaped(_ value: String, delimiter: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(delimiter) || escaped.contains("\n") || escaped.contains("\r") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private static func makeAPKG(records: [QueryRecord], to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(
            "Easydict-Anki-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDirectory) }

        let collectionURL = tempDirectory.appendingPathComponent("collection.anki2")
        let sqlURL = tempDirectory.appendingPathComponent("collection.sql")
        let mediaURL = tempDirectory.appendingPathComponent("media")

        try makeAnkiSQL(records: records).write(to: sqlURL, atomically: true, encoding: .utf8)
        try runProcess(executable: "/usr/bin/sqlite3", arguments: [collectionURL.path, ".read \(sqlURL.path)"])
        try "{}".write(to: mediaURL, atomically: true, encoding: .utf8)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try runProcess(
            executable: "/usr/bin/zip",
            arguments: ["-q", "-r", destinationURL.path, "collection.anki2", "media"],
            currentDirectory: tempDirectory
        )
    }

    private static func makeAnkiSQL(records: [QueryRecord]) throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let deckID = 1_707_000_001
        let modelID = 1_707_000_002
        let defaultConfigID = 1
        let deckJSON = try jsonString([
            "\(deckID)": [
                "id": deckID,
                "name": "Easydict Favorites",
                "desc": "Generated by Easydict",
                "mod": now,
                "usn": 0,
                "collapsed": false,
                "browserCollapsed": false,
                "conf": defaultConfigID,
                "dyn": 0,
                "extendNew": 10,
                "extendRev": 50,
                "newToday": [0, 0],
                "revToday": [0, 0],
                "lrnToday": [0, 0],
                "timeToday": [0, 0],
            ],
        ])
        let deckConfigJSON = try jsonString([
            "\(defaultConfigID)": [
                "id": defaultConfigID,
                "name": "Default",
                "mod": now,
                "usn": 0,
                "maxTaken": 60,
                "autoplay": true,
                "timer": 0,
                "replayq": true,
                "new": [
                    "bury": true,
                    "delays": [1, 10],
                    "initialFactor": 2500,
                    "ints": [1, 4, 7],
                    "order": 1,
                    "perDay": 20,
                    "separate": true,
                ],
                "rev": [
                    "bury": true,
                    "ease4": 1.3,
                    "fuzz": 0.05,
                    "ivlFct": 1.0,
                    "maxIvl": 36500,
                    "perDay": 200,
                ],
                "lapse": [
                    "delays": [10],
                    "leechAction": 0,
                    "leechFails": 8,
                    "minInt": 1,
                    "mult": 0.0,
                ],
            ],
        ])
        let collectionConfigJSON = try jsonString([
            "activeDecks": [deckID],
            "addToCur": true,
            "collapseTime": 1_200,
            "curDeck": deckID,
            "dueCounts": true,
            "estTimes": true,
            "newBury": true,
            "newSpread": 0,
            "nextPos": records.count + 1,
            "sortBackwards": false,
            "sortType": "noteFld",
            "timeLim": 0,
        ])
        let modelJSON = try jsonString([
            "\(modelID)": [
                "id": modelID,
                "name": "Easydict Favorite",
                "type": 0,
                "mod": now,
                "usn": 0,
                "sortf": 0,
                "did": deckID,
                "flds": [
                    ["name": "Front", "ord": 0, "sticky": false, "rtl": false, "font": "Arial", "size": 20],
                    ["name": "Back", "ord": 1, "sticky": false, "rtl": false, "font": "Arial", "size": 20],
                ],
                "tmpls": [[
                    "name": "Card 1",
                    "ord": 0,
                    "qfmt": "{{Front}}",
                    "afmt": "{{FrontSide}}<hr id=answer>{{Back}}",
                    "did": deckID,
                    "bqfmt": "",
                    "bafmt": "",
                ]],
                "css": ".card { font-family: arial; font-size: 20px; text-align: left; color: black; background-color: white; }",
                "latexPre": "",
                "latexPost": "",
                "req": [[0, "all", [0]]],
            ],
        ])

        var statements = [
            "PRAGMA foreign_keys=OFF;",
            "BEGIN TRANSACTION;",
            "CREATE TABLE col (id integer primary key, crt integer not null, mod integer not null, scm integer not null, ver integer not null, dty integer not null, usn integer not null, ls integer not null, conf text not null, models text not null, decks text not null, dconf text not null, tags text not null);",
            "CREATE TABLE notes (id integer primary key, guid text not null, mid integer not null, mod integer not null, usn integer not null, tags text not null, flds text not null, sfld integer not null, csum integer not null, flags integer not null, data text not null);",
            "CREATE TABLE cards (id integer primary key, nid integer not null, did integer not null, ord integer not null, mod integer not null, usn integer not null, type integer not null, queue integer not null, due integer not null, ivl integer not null, factor integer not null, reps integer not null, lapses integer not null, left integer not null, odue integer not null, odid integer not null, flags integer not null, data text not null);",
            "CREATE TABLE revlog (id integer primary key, cid integer not null, usn integer not null, ease integer not null, ivl integer not null, lastIvl integer not null, factor integer not null, time integer not null, type integer not null);",
            "CREATE TABLE graves (oid integer not null, type integer not null, usn integer not null, primary key (oid, type));",
            "CREATE INDEX idx_graves_pending on graves (usn);",
            "CREATE INDEX ix_notes_usn on notes (usn);",
            "CREATE INDEX ix_cards_usn on cards (usn);",
            "CREATE INDEX ix_cards_nid on cards (nid);",
            "INSERT INTO col VALUES(1, \(now), \(now * 1000), \(now * 1000), 11, 0, 0, 0, '\(sqlEscape(collectionConfigJSON))', '\(sqlEscape(modelJSON))', '\(sqlEscape(deckJSON))', '\(sqlEscape(deckConfigJSON))', '{}');",
        ]

        let template = AnkiCardTemplate.builtIns.first { $0.id == "full-card" } ?? AnkiCardTemplate.builtIns[0]
        for (index, record) in records.enumerated() {
            let noteID = (now * 1000) + index + 1
            let cardID = noteID + 100_000
            let front = html(template.renderFront(record: record))
            let back = html(template.renderBack(record: record))
            let fields = "\(front)\u{1f}\(back)"
            let checksum = abs(record.queryText.hashValue % 2_147_483_647)
            statements
                .append(
                    "INSERT INTO notes VALUES(\(noteID), '\(UUID().uuidString)', \(modelID), \(now), 0, '', '\(sqlEscape(fields))', '\(sqlEscape(front))', \(checksum), 0, '');"
                )
            statements
                .append(
                    "INSERT INTO cards VALUES(\(cardID), \(noteID), \(deckID), 0, \(now), 0, 0, 0, \(index + 1), 0, 2500, 0, 0, 0, 0, 0, 0, '');"
                )
        }

        statements.append("COMMIT;")
        return statements.joined(separator: "\n")
    }

    private static func html(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private static func sqlEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private static func jsonString(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func runProcess(executable: String, arguments: [String], currentDirectory: URL? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw NSError(domain: "EasydictFavoritesExport", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Failed to run \(executable)",
            ])
        }
    }
}

#Preview {
    FavoritesTab()
        .frame(width: 900, height: 640)
}
