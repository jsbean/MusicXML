//
//  mxl2dnm.swift
//  MusicXML
//
//  Created by James Bean on 1/3/17.
//
//

import QuartzCore
import SWXMLHash
import AbstractMusicalModel

private struct SpelledPitch: CustomStringConvertible {
    
    var description: String {
        return "\(step) \(alter) \(octave)"
    }
    
    let step: String
    let alter: Int
    let octave: Int

    init(step: String, octave: Int, alter: Int = 0) {
        self.step = step
        self.octave = octave
        self.alter = alter
    }
}


internal class MusicXMLToAbstractMusicalModelConverter {
    
    internal enum Error: Swift.Error {
        case resourceNotFound(String)
        case illFormedScore
        case nonIdentifiedPart
    }
    
    internal enum Format {
        case partwise
        case timewise
    }
    
    private var divisionsByPart: [String: Int] = [:]
    
    /// Current duration in divisions
    /// - TODO: Make conversion to beats, given divisionsByPartIdentifier value
    private var tick: Int = 0
    
    internal init() {
        
        do {
            let xml = try scoreXML(name: "Dichterliebe01")
            let (score, format) = try scoreAndFormat(xml)
            try traverse(score, format)
        } catch {
            print(error)
        }
    }
    
    private func scoreAndFormat(_ score: XMLIndexer) throws -> (XMLIndexer, Format) {
        
        if score["score-partwise"].element != nil {
            return (score["score-partwise"], Format.partwise)
        } else if score["score-timewise"].element != nil {
            return (score["score-timewise"], Format.timewise)
        } else {
            throw Error.illFormedScore
        }
    }
    
    internal func traverse(_ score: XMLIndexer, _ format: Format) throws {
        switch format {
        case .partwise:
            try traversePartwise(score)
        case .timewise:
            fatalError("Timewise traversal not yet supported!")
        }
    }
    
    private func traversePartwise(_ score: XMLIndexer) throws {
        try score["part"].all.forEach(traversePart)
    }
    
    private func traversePart(_ part: XMLIndexer) throws {
        
        guard let performerIdentifier = identifier(part: part) else {
            throw Error.nonIdentifiedPart
        }
        
        try storeDivisions(part: part, identifier: performerIdentifier)
        
        try part["measure"].all.forEach { measure in
            try traverseMeasure(measure, identifier: performerIdentifier)
        }
    }

    private func traverseMeasure(_ measure: XMLIndexer, identifier: String) throws {
        
        for child in measure.children {
            
            guard let elementName = child.element?.name else {
                continue
            }
            
            // TODO: wrap up: dispatchMeasureItem
            // TODO: case "divisions":
            switch elementName {
            case "backup":
                print("backup")
            case "forward":
                print("backup")
            case "note":
                try traverseNote(child, identifier: identifier)
            default:
                break
            }
        }
    }
    
    private func adjustTick(_ forward: XMLIndexer) throws {

    }
    
    private func traverseNote(_ note: XMLIndexer, identifier: String) throws {

        let rest = isRest(note)
        
        // first check if rest, otherwise, check for pitches
        let pitches = try note["pitch"].all.map(pitch)
        
        let dur = try duration(note)
        print("duration: \(dur)")
        print("tick: \(tick)")
        print("divisions: \(divisionsByPart[identifier])")
        tick += dur
    
        // check if rest
        // otherwise, pitch
        // voice
        // staff ?
        // tie (start / stop)
    }
    
    private func isRest(_ note: XMLIndexer) -> Bool {
        return note["rest"].element != nil
    }
    
    private func duration(_ note: XMLIndexer) throws -> Int {
        
        guard
            let durationString = note["duration"].element?.text,
            let duration = Int(durationString)
        else {
            throw Error.illFormedScore
        }
        
        return duration
    }
    
    private func pitch(_ pitch: XMLIndexer) throws -> SpelledPitch {
        
        guard
            let step = pitch["step"].element?.text,
            let octave = pitch["octave"].element?.text
        else {
            throw Error.illFormedScore
        }
        
        let alter = pitch["alter"].element?.text ?? "0"
        
        return SpelledPitch(step: step, octave: Int(octave)!, alter: Int(alter)!)
    }
    
    private func storeDivisions(part: XMLIndexer, identifier: String) throws {
        let divisions = try initialDivisions(part: part)
        divisionsByPart[identifier] = divisions
    }
    
    // Attempt to get divisions for a given `part` from the first measure
    private func initialDivisions(part: XMLIndexer) throws -> Int {
        
        guard
            let firstMeasure = part["measure"].all.first,
            let divisionsString = firstMeasure["attributes"]["divisions"].element?.text,
            let divisions = Int(divisionsString)
        else {
            throw Error.illFormedScore
        }
        
        return divisions
    }
    
    private func identifier(part: XMLIndexer) -> String? {
        return part.element?.attribute(by: "id")?.text
    }
    
    /// Creates an `XMLIndexer` representing the entire score with the given `name`.
    private func scoreXML(name: String) throws -> XMLIndexer {
        
        let bundle = Bundle(for: MusicXMLToAbstractMusicalModelConverter.self)
        
        guard let url = bundle.url(forResource: name, withExtension: "xml") else {
            throw Error.resourceNotFound(name)
        }
        
        let data = try Data(contentsOf: url)
        return SWXMLHash.parse(data)
    }
}

/*
// TODO: Import AbstractMusicalModel

// Stub types


enum RestOrEvent <T> {
    case rest
    case event(T)
}

struct Duration {
    let beats: Int
    let subdivision: Int
}

struct Note {
    // In `divisions`, for now...
    let duration: Duration
    let restOrEvent: RestOrEvent<[SpelledPitch]>
}

typealias Divisions = Int

public class MusicXML {
    
    // FIXME: Make meaningful
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
            
            guard let identifier = part.element?.attribute(by: "id")?.text else {
                throw Error.invalid
            }
            
            print("====================== \(identifier) =======================")
            
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
                
                for noteXML in measure["note"].all {
                    
                    guard let n = note(from: noteXML, divisions: divisions) else {
                        continue
                    }
                    
                    // Manage changing `divisions` as necessary
                    tick += n.duration.beats
                    print(n)
                }
            }
        }
    }

    // FIXME: Manage `duration` (take into account `division` above)
    func note(from xml: XMLIndexer, divisions: Int) -> Note? {
        
        guard let dur = duration(from: xml, divisions: divisions) else {
            return nil
        }
        
        switch xml["rest"].element {
        case nil:
            return Note(duration: dur, restOrEvent: .event(spelledPitches(from: xml)))
        default:
            return Note(duration: dur, restOrEvent: .rest)
        }
    }
    
    func duration(from note: XMLIndexer, divisions: Int) -> Duration? {
        
        guard
            let beatsString = note["duration"].element?.text,
            let beats = Int(beatsString)
        else {
            return nil
        }
        
        return Duration(beats: beats, subdivision: divisions)
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
*/
