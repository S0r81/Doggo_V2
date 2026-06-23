//
//  CoachContextAssemblerTests.swift
//  Doggo_V2Tests
//
//  Stage 1 gate for the AI Coach context store: the assembler must waste no
//  tokens when empty, group by category and skip empties when populated, and
//  produce a deterministic, stably-ordered block.
//

import Testing
import Foundation
@testable import Doggo_V2

struct CoachContextAssemblerTests {

    @Test func emptyStoreYieldsNoTokens() {
        #expect(CoachContextAssembler.contextBlock(from: []) == "")
    }

    @Test func allWhitespaceItemsYieldNoTokens() {
        let items = [
            CoachContextItem(category: .dietary, text: "   "),
            CoachContextItem(category: .other, text: "\n")
        ]
        #expect(CoachContextAssembler.contextBlock(from: items) == "")
    }

    @Test func groupsByCategoryAndSkipsEmptyOnes() {
        let items = [
            CoachContextItem(category: .injuries, text: "left knee — careful with squats"),
            CoachContextItem(category: .equipment, text: "home gym, no barbell")
        ]
        let block = CoachContextAssembler.contextBlock(from: items)

        #expect(block.contains("Injuries & Limitations:"))
        #expect(block.contains("- left knee — careful with squats"))
        #expect(block.contains("Available Equipment:"))
        #expect(block.contains("- home gym, no barbell"))
        // Categories with no items must not appear at all (no wasted tokens).
        #expect(!block.contains("Dietary"))
        #expect(!block.contains("Personal Goals"))
    }

    @Test func orderingIsStableByCategoryThenSortOrder() {
        // Deliberately out of order; assembler must normalize deterministically.
        let items = [
            CoachContextItem(category: .goals, text: "bench 225"),
            CoachContextItem(category: .injuries, text: "shoulder", sortOrder: 1),
            CoachContextItem(category: .injuries, text: "knee", sortOrder: 0)
        ]
        let block = CoachContextAssembler.contextBlock(from: items)

        // Category order: injuries appears before goals (fixed enum order).
        let injuriesIdx = try! #require(block.range(of: "Injuries & Limitations"))
        let goalsIdx = try! #require(block.range(of: "Personal Goals"))
        #expect(injuriesIdx.lowerBound < goalsIdx.lowerBound)

        // Within injuries: sortOrder 0 (knee) before sortOrder 1 (shoulder).
        let kneeIdx = try! #require(block.range(of: "knee"))
        let shoulderIdx = try! #require(block.range(of: "shoulder"))
        #expect(kneeIdx.lowerBound < shoulderIdx.lowerBound)
    }

    @Test func activeCountIgnoresBlankItems() {
        let items = [
            CoachContextItem(category: .dietary, text: "vegetarian"),
            CoachContextItem(category: .other, text: "   "),
            CoachContextItem(category: .goals, text: "lose 10 lb")
        ]
        #expect(CoachContextAssembler.activeCount(items) == 2)
    }
}
