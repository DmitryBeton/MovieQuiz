//
//  ArrayTests.swift
//  MovieQuiz
//
//  Created by Дмитрий Чалов on 25.07.2025.
//

import XCTest
@testable import MovieQuiz

final class ArrayTests: XCTestCase {
    func testGetValueInRange() throws {
        // Given
        let array = [1, 1, 2, 3, 5]
        
        // When
        let value = array[safe: 2]
        
        // Then
        XCTAssertNotNil(value)
        XCTAssertEqual(value, 2)
        
    }
    
    func testGetValueOfRange() throws {
        // Given
        let array = [1, 1, 2, 3, 5]
        
        // When
        let value = array[safe: 20]
        
        // Then
        XCTAssertNil(value)
        
    }
}
