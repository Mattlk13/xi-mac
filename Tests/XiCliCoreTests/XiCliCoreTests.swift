// Copyright 2018 The xi-editor Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest
@testable import XiCliCore

class XiCliCoreTests: XCTestCase {

    var commandLineTool: CommandLineTool!
    
    override func setUp() {
        super.setUp()
        let testArguments = Arguments(arguments: ["test.txt", "--wait"])
        commandLineTool = CommandLineTool(args: testArguments)
        let fileManager = FileManager.default
        fileManager.createFile(atPath: "test.txt", contents: "This is a tester file".data(using: .utf8), attributes: nil)
        try? fileManager.createSymbolicLink(atPath: "test_link.txt", withDestinationPath: "test.txt")
    }
    
    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(atPath: "test_link.txt")
        try? FileManager.default.removeItem(atPath: "test.txt")
    }

    func testArgParse() {
        let arguments = ["xi", "--wait", "test1.txt", "test2.txt"]
        let retrievedArgs = Arguments(arguments: arguments)
        XCTAssertNotNil(retrievedArgs)
        XCTAssert(retrievedArgs.fileInputs == ["test1.txt", "test2.txt"])
        XCTAssert(retrievedArgs.wait == true)
        XCTAssert(retrievedArgs.help == false)
    }

    func testResolveAbsolutePath() {
        let fromPath = fileInTempDir("testResolvePath")
        FileManager
            .default
            .createFile(atPath: fromPath, contents: "This is a tester file".data(using: .utf8), attributes: nil)
        do {
            let path = try commandLineTool.resolvePath(from: fromPath)
            XCTAssert(path == fromPath)
        } catch {
            XCTFail("temp file in temp dir not found")
        }
    }

    func testResolveRelativePath() {
        do {
            let path = try commandLineTool.resolvePath(from: "test.txt")
            let expectedPath = fileInCurrentDir("test.txt")
            XCTAssert(path == expectedPath, "path does not match expected")
        } catch {
            XCTFail("temp file not found")
        }
    }

    func testResolveSymlink() {
        do {
            let path = try commandLineTool.resolvePath(from: "test_link.txt")
            let expectedPath = fileInCurrentDir("test.txt")
            XCTAssert(path == expectedPath, "path does not match expected")
        } catch {
            XCTFail("symbolic link file not found")
        }
    }

    func testFileOpen() {
        XCTAssertNoThrow(try commandLineTool.openFile(at: "test.txt"))
    }

    func testObserver() {
        let group = DispatchGroup()
        group.enter()
        let observedPaths = ["filePath1", "test_link.txt"]
        let expectedPaths = [fileInCurrentDir("filePath1"), fileInCurrentDir("test.txt")]
        commandLineTool.setObserver(group: group, filePaths: expectedPaths)
        DistributedNotificationCenter.default().post(name: Notification.Name("io.xi-editor.XiEditor.FileClosed"), object: nil, userInfo: ["path": observedPaths.first!])
        DistributedNotificationCenter.default().post(name: Notification.Name("io.xi-editor.XiEditor.FileClosed"), object: nil, userInfo: ["path": observedPaths.last!])
        let expectation = XCTestExpectation(description: "Notification Recieved")

        let queue = OperationQueue()
        queue.addOperation {
            self.wait(for: [expectation], timeout: 3)
        }
        group.wait()
        expectation.fulfill()
    }

    func fileInCurrentDir(_ filename: String) -> String {
        var url = URL(string: FileManager.default.currentDirectoryPath)!
        url.appendPathComponent(filename)
        return url.path
    }

    func fileInTempDir(_ filename: String) -> String {
        var url = FileManager.default.temporaryDirectory
        url.appendPathComponent(filename)
        return url.path
    }
}
