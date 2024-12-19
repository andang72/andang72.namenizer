//
//  FileNameNormalizer.swift
//  Namenizer
//
//  Created by 손동혁 on 12/18/24.
//
import Foundation

public struct FileNameNormalizer {
    
    /// 파일 이름을 NFC로 변환하는 함수 (단일 또는 다수의 파일 처리)
    public static func convertFileNameToNFCUsingScript(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else {
            print("처리할 URL 목록이 비어 있습니다.")
            return false
        }
        
        // 첫 번째 파일 위치에 스크립트를 생성합니다.
        let scriptURL = urls[0].deletingLastPathComponent().appendingPathComponent("rename_to_nfc.sh")
        
        // 스크립트 생성
        let scriptContent = generateRenameScript(urls)
        
        do {
            // 스크립트 파일 저장
            try scriptContent.write(to: scriptURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            print("스크립트 파일이 생성되었습니다: \(scriptURL.path)")

            // 스크립트 실행
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            }

            if process.terminationStatus == 0 {
                print("모든 파일 이름이 NFC로 변환되었습니다.")
                try FileManager.default.removeItem(at: scriptURL) // 스크립트 파일 삭제
                return true
            } else {
                print("스크립트 실행 실패, 상태 코드: \(process.terminationStatus)")
            }
        } catch {
            print("오류 발생: \(error.localizedDescription)")
        }
        
        return false
    }

    /// 파일 이름을 NFC로 변환하는 쉘 스크립트를 생성하는 함수
    private static func generateRenameScript(_ urls: [URL]) -> Data {
        var content = Data()

        for url in urls {
            if url.isHidden {
                continue
            }

            let decomp = UrlDecomposition(url)
            let path = decomp.pathPart.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: " ", with: "\\ ")
            let file = decomp.lastPart.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: " ", with: "\\ ")
            let nfcFileName = file.precomposedStringWithCanonicalMapping.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: " ", with: "\\ ")

            // mv 명령어 생성
            content.append(#"mv -f ""#.data(using: .utf8)!)
            content.append(path.data(using: .utf8)!)
            content.append(file.data(using: .utf8)!)
            content.append(#"" ""#.data(using: .utf8)!)
            content.append(path.data(using: .utf8)!)
            content.append(nfcFileName.data(using: .utf8)!)
            content.append("\"\n".data(using: .utf8)!)
        }

        return content
    }
    
    /// 문자열이 NFD로 정규화된 상태인지 확인하는 함수
    public static func isNFDUsingUnicodeScalars(_ string: String) -> Bool {
        // NFD로 변환된 문자열
        let nfdString = string.decomposedStringWithCanonicalMapping
        
        // 원본 문자열과 NFD로 변환된 문자열의 유니코드 스칼라를 비교
        return string.unicodeScalars.elementsEqual(nfdString.unicodeScalars)
    }
    
    /// 유니코드 스칼라를 출력하는 함수
    public static func printUnicodeScalars(of string: String, label: String = "String") {
        print("\(label): \(string)")
        print("Unicode Scalars:")
        for scalar in string.unicodeScalars {
            print(String(format: "\\u{%04X}", scalar.value), terminator: " ")
        }
        print("\n")
    }
}


// URL 디컴포지션을 위한 클래스
class UrlDecomposition {
    let url: URL

    var lastPart: String {
        return url.lastPathComponent
    }

    var pathPart: String {
        return url.deletingLastPathComponent().path + "/"
    }

    init(_ url: URL) {
        self.url = url
    }
}

// 숨겨진 파일 확인 확장
extension URL {
    var isHidden: Bool {
        return (try? resourceValues(forKeys: [.isHiddenKey]))?.isHidden == true
    }
}
