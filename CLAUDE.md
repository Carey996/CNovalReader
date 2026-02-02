# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build for iOS Simulator
xcodebuild -scheme CNovalReader -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run tests
xcodebuild test -scheme CNovalReader -destination 'platform=iOS Simulator,name=iPhone 17'

# Run a single test
xcodebuild test -scheme CNovalReader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:CNovalReaderTests/BookTests/testBookInitialization
```

## Project Overview

CNovalReader is an iOS ebook reader app built with SwiftUI and SwiftData (iOS 17+).

### Architecture

```
CNovalReaderApp → ContentView → [DownloadView, BookDetailView]
                      ↓
                    Book (SwiftData model)
                      ↓
               DownloadService, FileManagerService
```

### Key Technologies

- **SwiftUI** - UI framework
- **SwiftData** - Data persistence (iOS 17+)
- **URLSession** - Network downloads
- **NavigationSplitView** - Main navigation pattern

### Directory Structure

- `Models/` - SwiftData models (Book.swift)
- `Services/` - Business logic (DownloadService, FileManagerService)
- `ViewModels/` - View state management (DownloadViewModel)
- `Views/` - SwiftUI views
- `Extensions/` - Swift extensions (URL+Extensions)
- `Utilities/` - Helper types (DownloadError)

### Patterns Used

- **MVVM** - ViewModel pattern with `@MainActor`
- **Singleton** - FileManagerService.shared
- **Dependency Injection** - Services injected into ViewModels
- **Codable Enums** - BookStatus stored as JSON in Data field

### Book Status States

The `BookStatus` enum tracks download/reading state:
- `.unknown` - Initial state
- `.downloading(progress)` - Active download
- `.downloaded` - Ready to read
- `.failed(error)` - Download error
- `.reading` - Currently being read

### File Storage

Downloaded books are stored in `Documents/Books/` via FileManagerService. The `Book.localFileName` property references the stored file.

### Supported Formats

EPUB, PDF, TXT, MOBI, AZW3, FB2 (validated in DownloadViewModel)

### Testing

Tests use Swift Testing framework (`@Testing`) with `@testable import CNovalReader`. Test file is at `CNovalReaderTests/CNovalReaderTests.swift` with test suites:
- `BookTests` - Model initialization and status transitions
- `DownloadErrorTests` - Error descriptions and recovery suggestions
- `URLExtensionsTests` - URL parsing and file handling
- `DownloadStatusTests` - Status display text
