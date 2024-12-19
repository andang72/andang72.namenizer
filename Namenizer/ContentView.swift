//
//  ContentView.swift
//  Namenizer
//
//  Created by 손동혁 on 12/16/24.
//
import SwiftUI

// 파일 노드 구조체
struct FileNode: Identifiable {
    let id = UUID()
    let url: URL
    var children: [FileNode]? = nil
}

// 파일 아이템 구조체
struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let size: Int64
    let unicodeType: String
    let url: URL
    let modificationDate: Date  // 수정 날짜 추가
}

struct ContentView: View {
    @State private var folderURL: URL? = nil
    @State private var rootNode: FileNode?
    @State private var selectedFolder: URL?
    @State private var fileItems: [FileItem] = []
    @State private var selectedFiles: Set<FileItem.ID> = [] // 선택된 파일 상태

    // 소팅 상태
    @State private var sortOrder: [KeyPathComparator<FileItem>] = [
        .init(\.name, order: .forward)
    ]

    var body: some View {
        NavigationView {
            // 좌측: 폴더 트리 뷰
            FolderTreeView(rootNode: rootNode, selectedFolder: $selectedFolder, loadFiles: loadFiles)
                .frame(minWidth: 250)
                .navigationTitle("폴더 탐색기")
            // 우측: 파일 테이블과 변환 버튼
            VStack {
                FileTableView(fileItems: $fileItems, sortOrder: $sortOrder, selectedFiles: $selectedFiles)
                    .navigationTitle(selectedFolder?.lastPathComponent ?? "파일 목록")
                if !selectedFiles.isEmpty {
                    Button(action: convertSelectedFilesToNFC) {
                        Label("NFC 유니코드 변경", systemImage: "arrow.left.arrow.right")
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            ToolbarItem {
                if let folder = selectedFolder {
                    Button(action: {
                        loadFiles(from: folder)
                    }) {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }
                }
            }
            ToolbarItem {
                Button("폴더 선택") {
                    selectFolder()
                }
            }
        }
    }

    // 폴더 선택 함수
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            folderURL = url
            rootNode = createFileNode(url: url)
            selectedFolder = url
            fileItems = []
            loadFiles(from: url)
        }
    }

    // 파일 노드 생성 함수
    func createFileNode(url: URL) -> FileNode {
        var childrenNodes: [FileNode]? = nil
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            childrenNodes = contents.filter { $0.hasDirectoryPath }.map { createFileNode(url: $0) }
        } catch {
            print("하위 폴더 불러오기 실패: \(error.localizedDescription)")
        }
        return FileNode(url: url, children: childrenNodes)
    }

    // 파일 목록 로드 함수
    func loadFiles(from folder: URL) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
            fileItems = contents.filter { !$0.hasDirectoryPath }.map { url in
                let fileName = url.lastPathComponent
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes?[.size] as? Int64 ?? 0
                let modificationDate = attributes?[.modificationDate] as? Date ?? Date.distantPast
                let unicodeType = !FileNameNormalizer.isNFDUsingUnicodeScalars(fileName) ? "NFC" : "NFD: " + decomposedStringWithSpaces(fileName)
                return FileItem(name: fileName, size: fileSize, unicodeType: unicodeType, url: url, modificationDate: modificationDate)
            }
            //fileItems.sort(using: sortOrder)
            // 수정 날짜를 기준으로 내림차순 정렬 (최신 파일이 먼저)
            fileItems.sort { $0.modificationDate > $1.modificationDate }
        } catch {
            print("파일 목록 로드 실패: \(error.localizedDescription)")
        }
    }
    
    func convertSelectedFilesToNFC() {
        // NFC로 변환해야 할 파일 URL들을 저장할 배열
        var urlsToConvert: [URL] = []
        
        for selectedID in selectedFiles {
            // 선택된 파일을 찾기
            guard let selectedFileItem = fileItems.first(where: { $0.id == selectedID }) else {
                print("선택된 파일을 찾을 수 없습니다.")
                continue
            }

            let originalURL = selectedFileItem.url
            let originalFileName = originalURL.lastPathComponent

            // NFD로 정규화된 파일만 추가
            if FileNameNormalizer.isNFDUsingUnicodeScalars(originalFileName) {
                urlsToConvert.append(originalURL)
            } else {
                print("이미 NFC로 정규화된 파일입니다: \(originalFileName)")
            }
        }
        // NFC로 파일 이름 변환 시도 (배열로 전달)
        if !urlsToConvert.isEmpty {
            let success = FileNameNormalizer.convertFileNameToNFCUsingScript(urlsToConvert)
            if success {
                    print("파일 이름 변환 성공")
            } else {
                print("파일 이름 변환 실패")
            }
        } else {
            print("변환할 파일이 없습니다.")
        }
        // 선택된 폴더가 있으면 파일 목록 새로고침
        if let folder = selectedFolder {
            loadFiles(from: folder)
        }
        // 선택 해제
        selectedFiles.removeAll()
    }
    
    func decomposedStringWithSpaces(_ string: String) -> String {
        let nfdString = string.decomposedStringWithCanonicalMapping
        return nfdString.unicodeScalars.map { String($0) }.joined(separator: " ")
    }
    
}

// 좌측 폴더 트리 뷰
struct FolderTreeView: View {
    let rootNode: FileNode?
    @Binding var selectedFolder: URL?
    let loadFiles: (URL) -> Void

    var body: some View {
        List {
            if let rootNode = rootNode {
                OutlineGroup(rootNode, children: \.children) { node in
                    Button(action: {
                        selectedFolder = node.url
                        loadFiles(node.url)
                    }) {
                        HStack {
                            Image(systemName: "folder").foregroundColor(.blue)
                            Text(node.url.lastPathComponent)
                        }
                    }
                }
            } else {
                Text("폴더를 선택해 주세요.").foregroundColor(.gray)
            }
        }
    }
}
// 파일 테이블 뷰
struct FileTableView: View {
    @Binding var fileItems: [FileItem]
    @Binding var sortOrder: [KeyPathComparator<FileItem>]
    @Binding var selectedFiles: Set<FileItem.ID>  // 선택된 파일 상태

    var body: some View {
        Table(fileItems, selection: $selectedFiles, sortOrder: $sortOrder) {
            TableColumn("이름", value: \FileItem.name)
            TableColumn("유니코드 형식", value: \FileItem.unicodeType)
            TableColumn("크기") { item in
                Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
            }
        }
        .onChange(of: sortOrder) { oldOrder, newOrder in
            fileItems.sort(using: newOrder)
        }
    }
}

#Preview {
    ContentView()
}
