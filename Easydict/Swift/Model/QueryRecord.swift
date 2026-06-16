//
//  QueryRecord.swift
//  Easydict
//
//  Created by Copilot on 2025/11/19.
//  Copyright © 2025 izual. All rights reserved.
//

import Defaults
import Foundation

// MARK: - QueryRecordServiceResult

/// A compact, codable snapshot of one service result saved with a favorite.
struct QueryRecordServiceResult: Codable, Hashable {
    let serviceName: String
    let translation: String?
    let definition: String?
    let htmlText: String?
}

// MARK: - QueryRecord

/// Represents a single query record for favorites or history.
struct QueryRecord: Codable, Identifiable, Hashable, Defaults.Serializable {
    // MARK: Lifecycle

    init(
        id: UUID = UUID(),
        queryText: String,
        queryFromLanguage: Language,
        queryToLanguage: Language,
        timestamp: Date = Date(),
        phonetic: String? = nil,
        definition: String? = nil,
        translation: String? = nil,
        example: String? = nil,
        serviceResults: [QueryRecordServiceResult] = [],
        aiContent: CardContent? = nil
    ) {
        self.id = id
        self.queryText = queryText
        self.queryFromLanguage = queryFromLanguage
        self.queryToLanguage = queryToLanguage
        self.timestamp = timestamp
        self.phonetic = phonetic
        self.definition = definition
        self.translation = translation
        self.example = example
        self.serviceResults = serviceResults
        self.aiContent = aiContent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.queryText = try container.decode(String.self, forKey: .queryText)
        self.queryFromLanguage = try container.decode(Language.self, forKey: .queryFromLanguage)
        self.queryToLanguage = try container.decode(Language.self, forKey: .queryToLanguage)
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        self.phonetic = try container.decodeIfPresent(String.self, forKey: .phonetic)
        self.definition = try container.decodeIfPresent(String.self, forKey: .definition)
        self.translation = try container.decodeIfPresent(String.self, forKey: .translation)
        self.example = try container.decodeIfPresent(String.self, forKey: .example)
        self.serviceResults = try container
            .decodeIfPresent([QueryRecordServiceResult].self, forKey: .serviceResults) ?? []
        self.aiContent = try container.decodeIfPresent(CardContent.self, forKey: .aiContent)
    }

    // MARK: Internal

    let id: UUID
    let queryText: String
    let queryFromLanguage: Language
    let queryToLanguage: Language
    let timestamp: Date
    let phonetic: String?
    let definition: String?
    let translation: String?
    let example: String?
    let serviceResults: [QueryRecordServiceResult]
    let aiContent: CardContent?

    var word: String { queryText }

    var bestTranslation: String {
        if let aiTranslation = aiContent?.translation, !aiTranslation.isEmpty {
            return aiTranslation
        }
        if let translation, !translation.isEmpty {
            return translation
        }
        return serviceResults.compactMap(\.translation).first { !$0.isEmpty } ?? ""
    }

    var bestDefinition: String {
        if let aiDefinition = aiContent?.definition, !aiDefinition.isEmpty {
            return aiDefinition
        }
        if let definition, !definition.isEmpty {
            return definition
        }
        return serviceResults.compactMap(\.definition).first { !$0.isEmpty } ?? ""
    }

    var bestExample: String {
        if let aiExample = aiContent?.example, !aiExample.isEmpty {
            return aiExample
        }
        return example ?? ""
    }

    static func == (lhs: QueryRecord, rhs: QueryRecord) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - CardContent

/// Optional AI enriched card content. Stored now so generated content can be added without a storage migration later.
struct CardContent: Codable, Hashable {
    var word: String
    var translation: String
    var definition: String
    var example: String
    var etymology: String
    var synonyms: [String]
    var antonyms: [String]
    var memoryTip: String
}

// MARK: - AnkiCardTemplate

/// Template used when exporting favorites to Anki.
struct AnkiCardTemplate: Codable, Identifiable, Hashable {
    // MARK: Internal

    static let builtIns: [AnkiCardTemplate] = [
        AnkiCardTemplate(id: "word-to-chinese", name: "Word -> Chinese", front: "{{word}}", back: "{{translation}}"),
        AnkiCardTemplate(
            id: "word-to-definition",
            name: "Word -> Definition",
            front: "{{word}}",
            back: "{{definition}}"
        ),
        AnkiCardTemplate(
            id: "full-card",
            name: "Full Study Card",
            front: "{{word}}",
            back: "{{phonetic}}\n\n{{translation}}\n\n{{example}}"
        ),
        AnkiCardTemplate(id: "reverse", name: "Reverse Memory", front: "{{translation}}", back: "{{word}}"),
    ]

    let id: String
    let name: String
    let front: String
    let back: String

    func renderFront(record: QueryRecord) -> String {
        render(front, record: record)
    }

    func renderBack(record: QueryRecord) -> String {
        render(back, record: record)
    }

    // MARK: Private

    private func render(_ template: String, record: QueryRecord) -> String {
        let serviceSummary = record.serviceResults.map { result in
            [result.serviceName, result.translation, result.definition]
                .compactMap { value in
                    guard let value, !value.isEmpty else { return nil }
                    return value
                }
                .joined(separator: "\n")
        }.filter { !$0.isEmpty }.joined(separator: "\n\n")

        let values = [
            "word": record.word,
            "phonetic": record.phonetic ?? "",
            "translation": record.bestTranslation,
            "definition": record.bestDefinition,
            "example": record.bestExample,
            "etymology": record.aiContent?.etymology ?? "",
            "synonyms": record.aiContent?.synonyms.joined(separator: ", ") ?? "",
            "antonyms": record.aiContent?.antonyms.joined(separator: ", ") ?? "",
            "memoryTip": record.aiContent?.memoryTip ?? "",
            "serviceResults": serviceSummary,
        ]

        var text = template
        for (key, value) in values {
            text = text.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
