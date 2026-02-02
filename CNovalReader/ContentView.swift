//
//  ContentView.swift
//  CNovalReader
//
//  Created by 陈凯瑞 on 2026/2/2.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @State private var showDownloadSheet = false

    var body: some View {
        NavigationSplitView {
            Group {
                if books.isEmpty {
                    emptyStateView
                } else {
                    bookListView
                }
            }
            .navigationTitle("My Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDownloadSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        } detail: {
            Text("Select a book to read")
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showDownloadSheet) {
            DownloadView()
        }
    }

    // MARK: - 视图组件

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Books Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Download books from URL to start reading")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showDownloadSheet = true
            } label: {
                Label("Download Book", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }

    private var bookListView: some View {
        List {
            ForEach(books) { book in
                NavigationLink {
                    BookDetailView(book: book)
                } label: {
                    BookRowView(book: book)
                }
            }
            .onDelete(perform: deleteBooks)
        }
    }

    // MARK: - 操作

    private func deleteBooks(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let book = books[index]
                // 删除本地文件
                if let fileName = book.localFileName {
                    try? FileManagerService.shared.deleteBook(fileName: fileName)
                }
                modelContext.delete(book)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Book.self, inMemory: true)
}
