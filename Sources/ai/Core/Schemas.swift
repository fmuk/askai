import Foundation
import FoundationModels

// MARK: - Common Schema Types

/// Contact information extraction
struct ContactInfo: Codable, Sendable {
    let name: String
    let email: String?
    let phone: String?
    let address: String?
}

/// Task or todo item
struct TaskItem: Codable, Sendable {
    let title: String
    let description: String
    let priority: Priority
    let estimatedMinutes: Int?

    enum Priority: String, Codable, Sendable {
        case low, medium, high, urgent
    }
}

/// List of tasks
struct TaskList: Codable, Sendable {
    let tasks: [TaskItem]
}

/// Code issue/bug report
struct CodeIssue: Codable, Sendable {
    let severity: Severity
    let line: Int?
    let message: String
    let suggestion: String?

    enum Severity: String, Codable, Sendable {
        case error, warning, info
    }
}

/// List of code issues
struct CodeAnalysis: Codable, Sendable {
    let issues: [CodeIssue]
    let summary: String
}

/// Email/message classification
struct MessageClassification: Codable, Sendable {
    let category: Category
    let sentiment: Sentiment
    let actionRequired: Bool
    let priority: Priority
    let suggestedResponse: String?

    enum Category: String, Codable, Sendable {
        case urgent, spam, newsletter, personal, work, other
    }

    enum Sentiment: String, Codable, Sendable {
        case positive, negative, neutral
    }

    enum Priority: String, Codable, Sendable {
        case low, medium, high
    }
}

/// Key-value pairs for general extraction
struct KeyValuePairs: Codable, Sendable {
    let data: [String: String]
}

/// Simple list of strings
struct StringList: Codable, Sendable {
    let items: [String]
}

/// Calendar event for ICS export
struct CalendarEvent: Codable, Sendable {
    let summary: String           // Event title (SUMMARY in ICS)
    let dtstart: String          // Start: YYYYMMDDTHHMMSS or YYYYMMDD for all-day
    let dtend: String            // End: YYYYMMDDTHHMMSS or YYYYMMDD for all-day
    let location: String?        // LOCATION in ICS
    let description: String?     // DESCRIPTION in ICS
    let tzid: String?           // Timezone ID (e.g., "Europe/Berlin", "America/New_York")

    /// Convert to ICS format
    func toICS() -> String {
        let uid = UUID().uuidString
        let dtstamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "").replacingOccurrences(of: ".", with: "")

        // Helper to check if a string value is valid (not null, not a type description)
        func isValidValue(_ value: String?) -> Bool {
            guard let val = value, !val.isEmpty else { return false }
            let lower = val.lowercased()
            let invalid = ["null", "string or null", "string", "optional"]
            return !invalid.contains(lower)
        }

        var ics = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//askai//ai CLI//EN
        CALSCALE:GREGORIAN
        METHOD:PUBLISH
        BEGIN:VEVENT
        UID:\(uid)
        DTSTAMP:\(dtstamp)
        SUMMARY:\(summary)
        """

        // Add dates with timezone if specified
        if isValidValue(tzid) {
            ics += "\nDTSTART;TZID=\(tzid!):\(dtstart)"
            ics += "\nDTEND;TZID=\(tzid!):\(dtend)"
        } else {
            ics += "\nDTSTART:\(dtstart)"
            ics += "\nDTEND:\(dtend)"
        }

        // Add optional fields if valid
        if isValidValue(location) {
            ics += "\nLOCATION:\(location!)"
        }

        if isValidValue(description) {
            ics += "\nDESCRIPTION:\(description!)"
        }

        ics += """

        END:VEVENT
        END:VCALENDAR
        """

        return ics
    }
}

// MARK: - Schema Registry

enum SchemaType: String, CaseIterable {
    case contact = "contact"
    case task = "task"
    case taskList = "task-list"
    case codeIssue = "code-issue"
    case codeAnalysis = "code-analysis"
    case messageClassification = "message"
    case keyValuePairs = "key-value"
    case stringList = "list"
    case calendarEvent = "calendar"

    var description: String {
        switch self {
        case .contact:
            return "Extract contact information (name, email, phone, address)"
        case .task:
            return "Extract a single task with title, description, priority"
        case .taskList:
            return "Extract multiple tasks from text"
        case .codeIssue:
            return "Identify a code issue with severity and suggestion"
        case .codeAnalysis:
            return "Analyze code for multiple issues"
        case .messageClassification:
            return "Classify email/message by category, sentiment, priority"
        case .keyValuePairs:
            return "Extract key-value pairs from text"
        case .stringList:
            return "Extract a list of items"
        case .calendarEvent:
            return "Extract calendar event with date/time and location"
        }
    }

    var extractionDescription: String {
        switch self {
        case .contact:
            return "contact information (name, email, phone, address)"
        case .task:
            return "a single task with its title, description, and priority"
        case .taskList:
            return "all tasks mentioned"
        case .codeIssue:
            return "the code issue with severity and suggested fix"
        case .codeAnalysis:
            return "all code issues with a summary"
        case .messageClassification:
            return "the message category, sentiment, priority, and action required"
        case .keyValuePairs:
            return "all key-value pairs"
        case .stringList:
            return "a list of all items mentioned"
        case .calendarEvent:
            return "calendar event details including date, time, location, and description"
        }
    }

    var schemaFields: String {
        switch self {
        case .contact:
            return """
            {
              "name": "string (required)",
              "email": "string or null",
              "phone": "string or null",
              "address": "string or null"
            }
            """
        case .task:
            return """
            {
              "title": "string",
              "description": "string",
              "priority": "low|medium|high|urgent",
              "estimatedMinutes": "number or null"
            }
            """
        case .taskList:
            return """
            {
              "tasks": [
                {"title": "string", "description": "string", "priority": "low|medium|high|urgent", "estimatedMinutes": number or null}
              ]
            }
            """
        case .codeIssue:
            return """
            {
              "severity": "error|warning|info",
              "line": "number or null",
              "message": "string",
              "suggestion": "string or null"
            }
            """
        case .codeAnalysis:
            return """
            {
              "issues": [array of code issues],
              "summary": "string"
            }
            """
        case .messageClassification:
            return """
            {
              "category": "urgent|spam|newsletter|personal|work|other",
              "sentiment": "positive|negative|neutral",
              "actionRequired": "boolean",
              "priority": "low|medium|high",
              "suggestedResponse": "string or null"
            }
            """
        case .keyValuePairs:
            return """
            {
              "data": {
                "key1": "value1",
                "key2": "value2"
              }
            }
            """
        case .stringList:
            return """
            {
              "items": ["string1", "string2", "string3"]
            }
            """
        case .calendarEvent:
            return """
            Required fields:
            - summary: Event title
            - dtstart: Start date/time in YYYYMMDDTHHMMSS format (e.g., 20251216T110000 for Dec 16, 2025 11:00 AM)
            - dtend: End date/time in YYYYMMDDTHHMMSS format

            Optional fields (omit if not available):
            - location: Event location
            - description: Event description
            - tzid: Timezone identifier (e.g., Europe/Berlin, America/New_York)
            """
        }
    }

    var exampleJSON: String {
        switch self {
        case .contact:
            return """
            {
              "name": "John Doe",
              "email": "john@example.com",
              "phone": "555-1234",
              "address": "123 Main St"
            }
            """
        case .task:
            return """
            {
              "title": "Fix login bug",
              "description": "Users cannot log in with email",
              "priority": "high",
              "estimatedMinutes": 30
            }
            """
        case .taskList:
            return """
            {
              "tasks": [
                {"title": "Task 1", "description": "...", "priority": "high"},
                {"title": "Task 2", "description": "...", "priority": "medium"}
              ]
            }
            """
        case .codeIssue:
            return """
            {
              "severity": "error",
              "line": 42,
              "message": "Null pointer dereference",
              "suggestion": "Add null check"
            }
            """
        case .codeAnalysis:
            return """
            {
              "issues": [...],
              "summary": "Found 3 errors, 5 warnings"
            }
            """
        case .messageClassification:
            return """
            {
              "category": "urgent",
              "sentiment": "negative",
              "actionRequired": true,
              "priority": "high",
              "suggestedResponse": "I'll handle this immediately"
            }
            """
        case .keyValuePairs:
            return """
            {
              "data": {
                "key1": "value1",
                "key2": "value2"
              }
            }
            """
        case .stringList:
            return """
            {
              "items": ["item1", "item2", "item3"]
            }
            """
        case .calendarEvent:
            return """
            {
              "summary": "Team Meeting",
              "dtstart": "20251224T140000",
              "dtend": "20251224T150000",
              "location": "Conference Room A",
              "description": "Quarterly review meeting",
              "tzid": "Europe/Berlin"
            }
            """
        }
    }
}
