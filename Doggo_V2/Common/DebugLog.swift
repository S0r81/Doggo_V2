//
//  DebugLog.swift
//  Doggo_V2
//
//  Development-only logging. Compiles to a no-op in release builds, so no
//  diagnostic output, user data, AI prompts, or AI responses are ever written
//  to the device console in shipping builds. The message is an @autoclosure, so
//  in release the string isn't even built. Use in place of `print`.
//

import Foundation

@inline(__always)
func DLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}
