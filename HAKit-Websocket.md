# Refactoring HAKit: Removing Starscream and Implementing Native WebSocket Connection

## Introduction

This README provides an overview of the recent refactoring of the HAKit library, focusing on the removal of Starscream and the subsequent implementation of a native WebSocket connection using Apple's native technologies.

## Background

HAKit is a Swift library that facilitates seamless communication with the Home Assistant platform. The library has been an essential tool for iOS developers who want to integrate Home Assistant's capabilities into their applications. However Starscream seems to have a [problem](https://github.com/daltoniam/Starscream/issues/743#issue-575306711) with `compressionHandler` and this led HAKit to be unable to connect with Home Assistant.


## Refactoring Process

The refactoring process involved the following steps:

1. **Dependency Removal:** Starscream was removed from the HAKit library's dependencies. This step reduced the library's size and simplified its structure.

2. **Integration of Native WebSocket:** Apple's native WebSocket framework was integrated into the HAKit library. The core of the communication is the `SocketStream` class. Other noteworthy changes are in `HAConnectionImpl` (class and extensions), `HAConnectionInfo` and `HAResponseController`

3. **Code Adaptation:** The existing code that relied on Starscream for WebSocket communication was modified to work seamlessly with the native WebSocket framework. This included adjustments to handling connections, messages, and error states. I modified current code implementation trying to keep as best as possible same structure, naming and method signatures

## Benefits of the Refactoring

The refactoring of HAKit has resulted in several benefits:

1. **Reduced Dependencies:** The removal of Starscream reduces the number of external dependencies, making the library more self-contained and easier to maintain.
3. **More control on code:** The switch to Apple's native framework with custom websocket implementation improves control, without the need to rely on third party libraries and making it easy (hopefully) to mantain and improve.


## Notes
The implementation needed min iOS version to be increased from 12 to 13.

## Further improvements

 - Some tests are commented out because of StarScream dependency. Should be better to re-introduce connection and responses handler tests to improve code quality.
 - The new HAKit version has been tested only on iOS. Should worth a try on macOS (probably min macOS version should be increased too)
 - Secure connection (https/wss) is fully supported but self signed certificate custom validation is not yet implemented (as it was Starscream version).

