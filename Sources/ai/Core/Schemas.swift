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
        }
    }
}
