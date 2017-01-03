//
//  mxl2dnm.swift
//  MusicXML
//
//  Created by James Bean on 1/3/17.
//
//

import Foundation
import SWXMLHash
// TODO: Import AbstractMusicalModel

// Stub types
struct SpelledPitch {
    let step: String
    let alter: Int
    let octave: Int
}

struct Note {
    let pitches: [SpelledPitch]
}

public class MusicXML {
    
    // FIXME: Make rich
    enum Error: Swift.Error {
        case invalid
    }
    
    // FIXME: This is currently set-up to test a single file
    // - Extend this to test arbitrary files
    public init() {

        let bundle = Bundle(for: MusicXML.self)
        guard
            let url = bundle.url(forResource: "Dichterliebe01", withExtension: "xml")
        else {
            print("Ill-formed URL")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let xml = SWXMLHash.parse(data)
            
            // FIXME: We assume partwise traversal
            // - Implement a check for `score-partwise` vs `score-timewise`
            let score = xml["score-partwise"]
            try traversePartwise(score: score)
            
        } catch {
            print("Something went wrong!")
        }
    }
    
    func traversePartwise(score: XMLIndexer) throws {
        
        for part in score["part"].all {
            
            // FIXME: Implement this
            let partID = part.element?.attribute(by: "id")?.text
            
            // FIXME: This will generally be set on the first measure
            // - But may change throughout a work
            var divisions: Int = 1
            
            // FIXME: Implement this to:
            // - move forward implicitly after `note` with `duration`
            // - move forward explicitly after `forward` element
            // - move backward explicitly after `backup` element
            var tick: Int = 0
            
            for measure in part["measure"].all {
                
                // FIXME: Clean-up: pull out `division` for the given `part`.
                // - This will generally be set on the first measure
                // - But may change throughout a work
                if
                    let val = measure["attributes"]["divisions"].element?.text,
                    let d = Int(val)
                {
                    divisions = d
                }
                
                for note in measure["note"].all {
                    
                    // FIXME: Manage `duration` (take into account `division` above)
                    
                    // FIXME: Manage `rest`
                    guard note["rest"].element == nil else {
                        continue
                    }
                    
                    // FIXME: Manage `note`
                    let chord = spelledPitches(from: note)
                }
            }
        }
    }

    func spelledPitches(from note: XMLIndexer) -> [SpelledPitch] {
        
        return note["pitch"].all.flatMap { pitch in
            
            guard
                let step = pitch["step"].element?.text,
                let alter = pitch["alter"].element?.text,
                let octave = pitch["octave"].element?.text
            else {
                return nil
            }
            
            return SpelledPitch(
                step: step,
                alter: Int(alter)!,
                octave: Int(octave)!
            )
        }
    }
}
