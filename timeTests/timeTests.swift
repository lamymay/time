//
//  timeTests.swift
//  timeTests
//

import Foundation
import Testing
@testable import time

struct TimeRolloverTests {
  private let tz = "UTC"
  private var format: ClockFormatOptions {
    ClockFormatOptions(
      is24Hour: false,
      padZero: false,
      showAMPM: true,
      ampmSide: "Trailing",
      showTimeZoneText: false,
      timeZoneIdentifier: tz,
      displayPrecision: .minute
    )
  }

  private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, _ s: Int = 30) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: tz)!
    return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
  }

  @Test func minuteOnesNineRollsTens() {
    let at = date(2024, 6, 4, 16, 29)
    let fields = TimeProvider.fieldsChangingAtNextMinute(from: at, format: format)
    #expect(fields.contains(.minuteOnes))
    #expect(fields.contains(.minuteTens))
    #expect(!fields.contains(.hourOnes))
  }

  @Test func minuteFiftyNineRollsHour() {
    let at = date(2024, 6, 4, 16, 59)
    let fields = TimeProvider.fieldsChangingAtNextMinute(from: at, format: format)
    #expect(fields.contains(.minuteOnes))
    #expect(fields.contains(.minuteTens))
    #expect(fields.contains(.hourOnes))
  }

  @Test func hourNineFiftyNineRollsToTen() {
    let at = date(2024, 6, 4, 9, 59)
    let fields = TimeProvider.fieldsChangingAtNextMinute(from: at, format: format)
    #expect(fields.contains(.hourOnes))
    #expect(fields.contains(.hourTens))
    #expect(fields.contains(.minuteOnes))
    #expect(fields.contains(.minuteTens))
  }

  @Test func elevenFiftyNineAMRollsNoon() {
    var f = format
    f.ampmSide = "Trailing"
    let at = date(2024, 6, 4, 11, 59)
    let fields = TimeProvider.fieldsChangingAtNextMinute(from: at, format: f)
    #expect(fields.contains(.trailingAMPM))
    #expect(fields.contains(.hourOnes))
  }

  @Test func minuteOnesNineAtTwentyNineRollsTens() {
    let at = date(2024, 6, 4, 16, 29)
    let fields = TimeProvider.fieldsChangingAtNextMinute(from: at, format: format)
    #expect(fields.contains(.minuteOnes))
    #expect(fields.contains(.minuteTens))
  }

  @Test func minuteOnesNineAtZeroNineAlsoRollsTens() {
    let at = date(2024, 6, 4, 16, 9)
    let fields = TimeProvider.fieldsChangingAtNextMinute(from: at, format: format)
    #expect(fields.contains(.minuteOnes))
    #expect(fields.contains(.minuteTens))
  }

  @Test func minuteOnesOnlyWhenNoCarry() {
    let at = date(2024, 6, 4, 16, 3)
    let fields = TimeProvider.fieldsChangingAtNextMinute(from: at, format: format)
    #expect(fields == [.minuteOnes])
  }
}
