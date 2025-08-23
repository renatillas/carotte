# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `subscribe_with_options` function for subscribing to queues with custom options
- `QueueOption` type with `RequiredAck` option for controlling message acknowledgment behavior

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

[Unreleased]: https://github.com/renatillas/carotte/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/renatillas/carotte/compare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/renatillas/carotte/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/renatillas/carotte/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/renatillas/carotte/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/renatillas/carotte/releases/tag/v1.0.0