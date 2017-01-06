//
//  mxl2dnmTests.swift
//  MusicXML
//
//  Created by James Bean on 1/3/17.
//
//

import XCTest
@testable import MusicXML

class mxl2dnmTests: XCTestCase {

    func testMusicXMLParseScorePartwise() {
        _ = MusicXMLToAbstractMusicalModelConverter()
    }
    
    func DISABLED_testMusicXMLParserPerformance() {
        self.measure {
            _ = MusicXMLToAbstractMusicalModelConverter()
        }
    }
}
