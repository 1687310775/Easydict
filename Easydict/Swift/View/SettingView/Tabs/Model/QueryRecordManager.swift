//
//  QueryRecordManager.swift
//  Easydict
//
//  Created by Copilot on 2025/11/19.
//  Copyright © 2025 izual. All rights reserved.
//

import Defaults
import Foundation

// MARK: - QueryRecordSort

enum QueryRecordSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case alphabetical

    // MARK: Internal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .alphabetical: return "A-Z"
        }
    }
}

// MARK: - QueryRecordManager

/// Manages query record operations for favorites and history.
@objc
class QueryRecordManager: NSObject {
    // MARK: Internal

    /// Defines the record category stored in defaults.
    @objc
    enum RecordType: Int {
        case favorites
        case history

        // MARK: Internal

        /// Returns the defaults key for the record type.
        var storageKey: Defaults.Key<[QueryRecord]> {
            switch self {
            case .favorites:
                return Defaults.Keys.favorites
            case .history:
                return Defaults.Keys.queryHistory
            }
        }

        /// Provides the maximum number of records allowed for the type.
        var maxCount: Int? {
            switch self {
            case .favorites:
                return nil
            case .history:
                return QueryRecordManager.maxHistoryCount
            }
        }

        /// Determines how duplicates should be handled for the record type.
        var deduplicationPolicy: DeduplicationPolicy {
            switch self {
            case .favorites:
                return .skipIfExists
            case .history:
                return .moveToFront
            }
        }
    }

    /// Describes how to handle duplicate query texts when adding records.
    enum DeduplicationPolicy {
        case skipIfExists
        case moveToFront
    }

    /// Shared instance used by the app.
    @objc static let shared = QueryRecordManager()

    /// Adds a query record to the specified category.
    @objc
    func addRecord(
        queryText: String,
        fromLanguage: Language,
        toLanguage: Language,
        to type: RecordType
    ) {
        addRecord(
            makeRecord(queryText: queryText, fromLanguage: fromLanguage, toLanguage: toLanguage),
            to: type
        )
    }

    /// Adds or refreshes a favorite using current service results from the query window.
    @objc(addFavoriteWithQueryText:fromLanguage:toLanguage:services:)
    func addFavorite(
        queryText: String,
        fromLanguage: Language,
        toLanguage: Language,
        services: [QueryService]
    ) {
        let results = services.compactMap(\.result)
        let record = makeRecord(
            queryText: queryText,
            fromLanguage: fromLanguage,
            toLanguage: toLanguage,
            results: results
        )
        removeRecord(queryText: queryText, from: .favorites)
        addRecord(record, to: .favorites)
    }

    /// Toggles a favorite using current service results from the query window.
    @objc(toggleFavoriteWithQueryText:fromLanguage:toLanguage:services:)
    func toggleFavorite(
        queryText: String,
        fromLanguage: Language,
        toLanguage: Language,
        services: [QueryService]
    ) {
        if containsRecord(queryText: queryText, in: .favorites) {
            removeRecord(queryText: queryText, from: .favorites)
            return
        }

        addFavorite(
            queryText: queryText,
            fromLanguage: fromLanguage,
            toLanguage: toLanguage,
            services: services
        )
    }

    /// Removes a record by ID from the specified category.
    func removeRecord(id: UUID, from type: RecordType) {
        updateRecords(for: type) { records in
            let originalCount = records.count
            records.removeAll { $0.id == id }
            return records.count != originalCount
        }
    }

    /// Removes a record by query text from the specified category.
    @objc(removeRecordWithQueryText:from:)
    func removeRecord(queryText: String, from type: RecordType) {
        updateRecords(for: type) { records in
            let originalCount = records.count
            records.removeAll { $0.queryText.caseInsensitiveCompare(queryText) == .orderedSame }
            return records.count != originalCount
        }
    }

    /// Returns all records for the specified category.
    func getAllRecords(for type: RecordType) -> [QueryRecord] {
        loadRecords(for: type)
    }

    /// Clears all records for the specified category.
    func clearAllRecords(for type: RecordType) {
        saveRecords([], for: type)
    }

    /// Checks whether the given query text exists in the specified category.
    @objc
    func containsRecord(queryText: String, in type: RecordType) -> Bool {
        loadRecords(for: type).contains { $0.queryText.caseInsensitiveCompare(queryText) == .orderedSame }
    }

    func searchFavorites(keyword: String) -> [QueryRecord] {
        filteredRecords(for: .favorites, keyword: keyword, sort: .newest, startDate: nil, endDate: nil)
    }

    func filteredRecords(
        for type: RecordType,
        keyword: String,
        sort: QueryRecordSort,
        startDate: Date?,
        endDate: Date?
    )
        -> [QueryRecord] {
        var records = loadRecords(for: type)

        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKeyword.isEmpty {
            records = records.filter { record in
                let haystack = [
                    record.queryText,
                    record.phonetic ?? "",
                    record.bestTranslation,
                    record.bestDefinition,
                    record.bestExample,
                ].joined(separator: "\n")
                return haystack.localizedCaseInsensitiveContains(trimmedKeyword)
            }
        }

        if let startDate {
            records = records.filter { $0.timestamp >= startDate }
        }
        if let endDate {
            records = records.filter { $0.timestamp <= endDate }
        }

        switch sort {
        case .newest:
            records.sort { $0.timestamp > $1.timestamp }
        case .oldest:
            records.sort { $0.timestamp < $1.timestamp }
        case .alphabetical:
            records.sort { $0.queryText.localizedCaseInsensitiveCompare($1.queryText) == .orderedAscending }
        }

        return records
    }

    func exportFavorites() -> [QueryRecord] {
        getAllRecords(for: .favorites)
    }

    // MARK: Private

    /// Maximum number of history records to keep.
    private static let maxHistoryCount = 1000

    /// Returns all records stored for the specified type.
    private func loadRecords(for type: RecordType) -> [QueryRecord] {
        Defaults[type.storageKey]
    }

    /// Saves the records for the specified type.
    private func saveRecords(_ records: [QueryRecord], for type: RecordType) {
        Defaults[type.storageKey] = records
    }

    /// Updates records for the specified type and saves when modified.
    private func updateRecords(for type: RecordType, mutate: (inout [QueryRecord]) -> Bool) {
        var records = loadRecords(for: type)
        let didChange = mutate(&records)
        if didChange {
            saveRecords(records, for: type)
        }
    }

    private func addRecord(_ record: QueryRecord, to type: RecordType) {
        updateRecords(for: type) { records in
            switch type.deduplicationPolicy {
            case .skipIfExists:
                guard !records
                    .contains(where: { $0.queryText.caseInsensitiveCompare(record.queryText) == .orderedSame }) else {
                    return false
                }
            case .moveToFront:
                records.removeAll { $0.queryText.caseInsensitiveCompare(record.queryText) == .orderedSame }
            }

            records.insert(record, at: 0)

            if let maxCount = type.maxCount, records.count > maxCount {
                records = Array(records.prefix(maxCount))
            }

            return true
        }
    }

    /// Creates a query record from the provided values.
    private func makeRecord(
        queryText: String,
        fromLanguage: Language,
        toLanguage: Language,
        results: [QueryResult] = []
    )
        -> QueryRecord {
        let snapshots = results.compactMap(makeServiceResult)
        let dictionaryResult = results.compactMap(\.wordResult).first

        return QueryRecord(
            queryText: queryText,
            queryFromLanguage: fromLanguage,
            queryToLanguage: toLanguage,
            phonetic: dictionaryResult?.phonetics?.compactMap(\.value).first { !$0.isEmpty },
            definition: definitionText(from: dictionaryResult),
            translation: results.compactMap(\.translatedText).first { !$0.isEmpty },
            example: exampleText(from: dictionaryResult),
            serviceResults: snapshots
        )
    }

    private func makeServiceResult(from result: QueryResult) -> QueryRecordServiceResult? {
        guard result.hasTranslatedResult else {
            return nil
        }

        let definition = definitionText(from: result.wordResult)
        let htmlText = result.innerTexts?.joined(separator: "\n")
        let snapshot = QueryRecordServiceResult(
            serviceName: result.serviceTypeWithUniqueIdentifier,
            translation: result.translatedText,
            definition: definition,
            htmlText: htmlText
        )

        let hasContent = [snapshot.translation, snapshot.definition, snapshot.htmlText].contains { value in
            value?.isEmpty == false
        }
        return hasContent ? snapshot : nil
    }

    private func definitionText(from wordResult: EZTranslateWordResult?) -> String? {
        guard let wordResult else { return nil }

        let partTexts: [String] = wordResult.parts?.map { part in
            let prefix = part.part?.isEmpty == false ? "\(part.part ?? "") " : ""
            return prefix + part.means.joined(separator: "; ")
        } ?? []

        let simpleTexts: [String] = wordResult.simpleWords?.map { simpleWord in
            let prefix = simpleWord.part?.isEmpty == false ? "\(simpleWord.part ?? "") " : ""
            return prefix + simpleWord.meansText
        } ?? []

        let text = (partTexts + simpleTexts).filter { !$0.isEmpty }.joined(separator: "\n")
        return text.isEmpty ? nil : text
    }

    private func exampleText(from wordResult: EZTranslateWordResult?) -> String? {
        guard let simpleWord = wordResult?.simpleWords?.first else { return nil }
        let text = simpleWord.meansText
        return text.isEmpty ? nil : text
    }
}
