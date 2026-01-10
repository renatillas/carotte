# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.0.0] - 2026-01-10

### Changed

- **BREAKING**: Consolidated all modules into a single `carotte` module. Removed `carotte/channel`, `carotte/exchange`, `carotte/publisher`, and `carotte/queue` submodules.
- **BREAKING**: Replaced single `CarotteError` type with operation-specific error types: `ConnectionError`, `ChannelError`, `ExchangeError`, `QueueError`, `PublishError`, `ConsumeError`.
- **BREAKING**: Consumer API completely redesigned with OTP supervision integration via `factory_supervisor`
- **BREAKING**: `ClientConfig.heartbeat` now uses `Duration` instead of `Int` (seconds)
- **BREAKING**: `ClientConfig.connection_timeout` now uses `Duration` instead of `Int` (milliseconds)
- **BREAKING**: `PublishOption.Expiration` now uses `Duration` instead of `String`
- **BREAKING**: `PublishOption.Timestamp` now uses `timestamp.Timestamp` instead of `Int`

### Removed

- Removed `carotte/channel`, `carotte/exchange`, `carotte/publisher`, and `carotte/queue` submodules (consolidated into main module)
- Removed `ConsumerInfo` type and `consumer_info` function
- Removed `consumer_tag()` function (no longer needed since `subscribe` returns the tag directly)

### Added

- OTP supervision integration for consumers using `factory_supervisor`
- `consumer_supervised` function to create a child specification for supervision trees
- `named_consumer` function to get a consumer reference by name
- `describe_*_error` functions for each error type to convert errors to human-readable strings
- `gleam_time` dependency for type-safe `Duration` and `Timestamp` handling
- Comprehensive module documentation with usage examples
- `nack` function for negatively acknowledging messages with control over multiple and requeue options
- `nack_single` convenience function for negatively acknowledging a single message
- `reject` function for rejecting messages (original AMQP 0-9-1 method)

### Fixed

- Added try/catch error handling to `consume` FFI function to match other FFI functions
- Fixed `ListHeader` serialization in FFI layer - array elements were incorrectly destructured
- Fixed typo in documentation: `consumer_start` -> `start_consumer`

## 4.0.1 - 2026-01-08

### Fixed

- Fix issue with auto-generated queue names not being matched correctly in erlang ffi.
  Now auto-generated names are properly retrieved from the FFI layer.

## [4.0.0] - 2026-01-05

### Added

- Headers can now be read from received messages (previously only sending was supported)
- New `headers` field in the `Payload` type to access message headers when consuming
- `empty_headers()` function to create an empty HeaderList for pattern matching or when no headers are needed
- `headers_to_list()` function to convert a HeaderList back to a list of name-value pairs

### Changed

- **BREAKING**: `Payload` type now has three fields: `payload`, `properties`, and `headers`

## [3.0.0] - 2025-11-21

- AutoAck(True) now does what it means, setting no_ack to True in the FFI layer, instead of being inverted.

## [2.1.0] - 2024-01-23

### Added

- `subscribe_with_options` function for subscribing to queues with custom options
- `QueueOption` type with `AutoAck` option for controlling message acknowledgment behavior

### Fixed

- Queue declaration now properly handles queue names when declaring exclusive queues
- Fixed FFI error handling to properly convert Erlang error reasons to strings
- Acknowledgment functions now work correctly with proper FFI bindings
- Consumer subscription with manual acknowledgment mode now functions properly

## [2.0.0] - 2024-01-23

### Changed

- **BREAKING**: Made `Client` type opaque for better encapsulation and type safety
- **BREAKING**: Complete overhaul of error handling system with specific error variants:
  - Connection errors: `Blocked`, `Closed`, `ConnectionRefused`, `ConnectionTimeout`
  - Authentication/Authorization: `AuthFailure`, `AccessRefused`, `NotAllowed`
  - Resource errors: `ProcessNotFound`, `AlreadyRegistered`, `NotFound`, `ResourceLocked`
  - Protocol errors: `ChannelClosed`, `FrameError`, `UnexpectedFrame`, `CommandInvalid`
  - Operational errors: `PreconditionFailed`, `NoRoute`, `InvalidPath`, `NotImplemented`, `InternalError`
- **BREAKING**: Simplified client builder API - removed process name requirement from `default_client()`
- **BREAKING**: Removed supervisor functionality to simplify the API
- Improved FFI layer for better error message propagation
- Enhanced type safety across all modules

### Added

- Comprehensive error types with detailed error messages for better debugging
- `ack_single` convenience function for acknowledging single messages
- Support for manual message acknowledgment with `ack` and `ack_single` functions
- Ability to acknowledge multiple messages at once with `ack(multiple: True)`

### Removed

- Supervisor functionality (users can implement their own supervision if needed)
- Process name requirement from basic client creation

### Fixed

- Error messages now properly returned as strings instead of atoms
- FFI function names corrected from `carrot_ffi` to `carotte_ffi`

## [1.1.0] - 2023-12-15

### Added

- Header publishing functionality with support for multiple header types:
  - `BoolHeader`, `FloatHeader`, `IntHeader`, `StringHeader`, `ListHeader`
- `headers_from_list` function for easy header creation
- RabbitMQ service container in CI for automated testing
- Support for all standard AMQP message properties in publishing options

### Fixed

- README improvements and documentation updates
- CI pipeline enhancements with RabbitMQ integration

## [1.0.2] - 2023-11-30

### Fixed

- Fixed typo in FFI module name (`carrot_ffi` -> `carotte_ffi`)
- Documentation improvements

## [1.0.1] - 2023-11-28

### Fixed

- Channel module export corrections
- Minor bug fixes

## [1.0.0] - 2023-11-25

### Added

- Initial release of Carotte RabbitMQ client for Gleam
- Core connection management with `Client` and `Builder` types
- Channel operations for managing AMQP channels
- Exchange support for all types (Direct, Fanout, Topic, Headers)
- Queue operations including declare, delete, bind, unbind, purge
- Publishing messages with comprehensive options
- Consuming messages with auto-acknowledgment
- Asynchronous variants for non-blocking operations
- FFI bindings to Erlang's `amqp_client` library
- Basic authentication support
- Virtual host configuration
- Connection parameters (heartbeat, timeout, frame size)

[Unreleased]: https://github.com/renatillas/carotte/compare/v5.0.0...HEAD
[5.0.0]: https://github.com/renatillas/carotte/compare/v4.0.1...v5.0.0
[4.0.0]: https://github.com/renatillas/carotte/compare/v3.0.0...v4.0.0
[3.0.0]: https://github.com/renatillas/carotte/compare/v2.1.0...v3.0.0
[2.1.0]: https://github.com/renatillas/carotte/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/renatillas/carotte/compare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/renatillas/carotte/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/renatillas/carotte/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/renatillas/carotte/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/renatillas/carotte/releases/tag/v1.0.0
