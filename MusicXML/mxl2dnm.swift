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
        return "\(step)\(alterString)\(octave)"
    }
    
    let step: String
    let alter: Int
    let octave: Int
    
    var alterString: String {
        switch alter {
        case 0: return ""
        case 1: return "#"
        case -1: return "b"
        default:
            fatalError()
        }
    }

    init(step: String, octave: Int, alter: Int = 0) {
        self.step = step
        self.octave = octave
        self.alter = alter
    }
}

private enum RestOrEvent <T> {
    case rest
    case event(T)
}

private struct Note <T> {
    
    let restOrEvent: RestOrEvent<T>
    let durationInterval: (Int, Int)
    let voice: Int
    let staff: Int
    
    init(
        restOrEvent: RestOrEvent<T>,
        durationInterval: (Int, Int),
        voice: Int,
        staff: Int = 1
    )
    {
        self.restOrEvent = restOrEvent
        self.durationInterval = durationInterval
        self.voice = voice
        self.staff = staff
    }
}

private struct CursorContext {
    let staff: Int
    let voice: Int
}

internal class MusicXMLToAbstractMusicalModelConverter {
    
    internal enum Error: Swift.Error {
        case resourceNotFound(String)
        case illFormedScore
        case nonIdentifiedPart // merge with illFormedScore?
    }
    
    internal enum Format {
        case partwise
        case timewise
    }
    
    private var divisionsByPart: [String: Int] = [:]
    
    /// Current duration in divisions
    /// Organize into cursor by voice by staff
    /// - TODO: Make conversion to beats, given divisionsByPart value
    private var cursor: Int = 0
    
    internal init(name: String) {
        
        do {
            let xml = try scoreXML(name: name)
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
        
        resetCursor()
        
        try part["measure"].all.forEach { measure in
            try traverseMeasure(measure, identifier: performerIdentifier)
        }
    }

    private func traverseMeasure(_ measure: XMLIndexer, identifier: String) throws {
        try measure.children.forEach { measureItem in
            try dispatch(measureItem, identifier: identifier)
        }
    }
    
    private func dispatch(_ measureItem: XMLIndexer, identifier: String) throws {
        
        guard let elementName = measureItem.element?.name else {
            throw Error.illFormedScore
        }

        switch elementName {
        case "backup":
            try updateCursor(backward: measureItem)
        case "forward":
            try updateCursor(forward: measureItem)
        case "note":
            try traverseNote(measureItem, identifier: identifier)
        default:
            break
        }
    }
    
    private func traverseNote(_ note: XMLIndexer, identifier: String) throws {
        
        let restOrEvent: RestOrEvent = isRest(note)
            ? .rest
            : .event(try note["pitch"].all.map(pitch))
        
        let dur = try duration(note)
        let offset = cursor
        let interval = (offset, dur)
        
        let note = Note(
            restOrEvent: restOrEvent,
            durationInterval: interval,
            voice: try voice(note),
            staff: try staff(note)
        )
        
        moveCursor(by: dur)
        
        print(note)
        
        // TODO:
        // - Tie (start / stop)
    }
    
    private func voice(_ note: XMLIndexer) throws -> Int {
        return try number(name: "voice", from: note)
    }
    
    private func staff(_ note: XMLIndexer) throws -> Int {
        return try number(name: "staff", from: note, defaultValue: 1)
    }
    
    // MARK: - Cursor
    
    private func resetCursor() {
        cursor = 0
    }
    
    /// FIXME: For now, treating the cursor as a global shared by everyone
    /// - make cursor more rich, taking into account voice and staff
    private func updateCursor(forward: XMLIndexer) throws {
        moveCursor(by: try duration(forward))
    }
    
    /// FIXME: For now, treating the cursor as a global shared by everyone
    /// - make cursor more rich, taking into account voice and staff
    private func updateCursor(backward: XMLIndexer) throws {
        moveCursor(by: try -duration(backward))
    }
    
    private func moveCursor(by amount: Int) {
        cursor += amount
    }
    
    private func duration(_ indexer: XMLIndexer) throws -> Int {
        return try number(name: "duration", from: indexer)
    }
    
    private func isRest(_ note: XMLIndexer) -> Bool {
        return note["rest"].element != nil
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
    
    private func number(
        name: String,
        from indexer: XMLIndexer,
        defaultValue: Int? = nil
    ) throws -> Int
    {
        
        guard
            let numberString = indexer[name].element?.text,
            let number = Int(numberString)
        else {
                
            guard let defaultValue = defaultValue else {
                throw Error.illFormedScore
            }
            
            return defaultValue
        }
        
        return number
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
