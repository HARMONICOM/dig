# AGENTS.md

This document provides guidelines for AI agents to understand and appropriately assist with this Zig project.


## Project Overview

This project is documentation for the "Dig" ORM mapper written in Zig.


## Technology Stack

- **Language**: Zig 0.15.2
- **Container**: Docker (Based on Debian Trixie Slim)
- **Orchestration**: Docker Compose
- **External Dependencies**:
  - PCRE2 (libpcre2-dev) - Regular expression processing library


## Project Structure

```
.
├── compose.yml                 # Docker Compose configuration for build environment
├── docker/
│   └── app/
│       └── Dockerfile          # Docker image definition for build environment
├── build.zig                   # Zig build configuration
├── build.zig.zon               # Zig module definition
├── src/                        # Source code
│   ├── dig.zig                 # Module base
│   │── dig/                    # Module files directory
│   │   └── drivers/            # Common utilities and helpers
│   │       ├── mysql.zig       # MySQL driver
│   │       └── postgresql.zig  # PostgreSQL driver
│   └── tests/                  # Test files
├── zig-out/                    # Build output directory
├── Makefile                    # Make execution configuration
└── AGENTS.md                   # This file
```


## Build and Execution

### Build Environment Using Docker Compose

```bash
# Build and start container
make up

# Open shell in container
make run bash

# Check Zig version
make zig version

# Use formatter
make zig fmt [target directory]

# Build
make zig build [target (all if omitted)]

# Execute
make zig run src/main.zig
```

**Note:** Error code `Error 3` indicates normal termination


## Development Guidelines

### Zig Coding Conventions

1. **Naming Rules**
   - Functions: `camelCase` (e.g., `handleRequest`)
   - Types: `PascalCase` (e.g., `HttpServer`)
   - Constants: `SCREAMING_SNAKE_CASE` (e.g., `MAX_CONNECTIONS`)
   - Variables: `snake_case` (e.g., `request_count`)
   - File names: `camelCase` (e.g., `loggingMiddleware.zig`) *Test files should end with `_test.zig`

2. **Error Handling**
   - Actively use Zig's error handling features
   - Use `!` type to handle errors explicitly
   - Use `try` and `catch` appropriately

3. **Memory Management**
   - Be conscious of explicit memory management
   - Choose allocators appropriately (`std.heap.page_allocator`, `std.heap.ArenaAllocator`, etc.)
   - Avoid memory leaks

4. **Comments**
   - Use `///` for documentation comments on public APIs
   - Add inline comments for complex logic
   - Write all comments in English

5. **Other**
    - Refer to `.editorconfig` for indentation and other EditorConfig settings

### File Structure Example

```
src/
├── horizon.zig               # Module base file
└── horizon/
    ├── middleware.zig        # Middleware implementation
    ├── request.zig           # Request handler
    ├── response.zig          # Response handler
    ├── router.zig            # Routing processing
    ├── server.zig            # HTTP server implementation
    ├── session.zig           # Session implementation
    ├── libs/                 # Libraries directory
    ├── middlewares/          # Middlewares directory
    └── utils/                # Utilities
```


## Dependencies

### External Libraries

This project uses the following external libraries:

- **PCRE2** (libpcre2-dev): For regular expression processing
  - Used for path parameter regex matching
  - Included in Docker container
  - Linked as a C library

### Build Configuration

Configured in `build.zig` as follows:

```zig
// Link C library
example_exe.linkLibC();
example_exe.linkSystemLibrary("pcre2-8");
```

When adding new dependencies, manage them appropriately in `build.zig` or `build.zig.zon`.


## Debugging

### Log Output

Check Docker Compose logs:

```bash
make logs app
```

### Debugging in Container

```bash
# Zig debug build
make zig build -Doptimize=Debug
```


## Performance

- Use `-Doptimize=ReleaseFast` or `-Doptimize=ReleaseSafe` for release builds
- Use appropriate tools for profiling when needed


## Formatter

Use Zig's standard formatter:

```bash
# Run formatter
make zig fmt .
```


## Testing

Use Zig's standard testing framework:

```bash
# Run tests
make zig build test
```


## AI Agent Roles

### Understanding Specifications
- **Role**: Read and understand specifications from specification documents
- **Target**: Files under `/docs` directory

### Development Support

#### Feature Implementation Agent
- **Role**: Implement features based on specification documents
- **Target**: Feature implementation
- **Execution Command**: Run `make zig fmt .` after implementation
- **Note**: No need to consider backward compatibility at this point. Remove unnecessary parts
- **Note**: Comment should be written in English
- **Note**: Increment version numbers as well. Version numbers are specified in `build.zig.zon`, `README.md`, and `docs/index.html`, so update these files

#### Test Implementation Agent
- **Role**: Create unit tests and integration tests
- **Target**: Test files in `/src/tests` directory
- **Execution Command**: `make zig build test` for all tests, `make zig test [target file]` for individual test files

### Documentation Updates
- **Role**: Update documentation about implemented features
- **Target**: Files in `/documents` directory and `/README.md` and Github pages `/docs` directory
- **Note**: Documentation should be written in English


## Notes

1. **Zig Version**: This project is developed with Zig 0.15.2
2. **Docker Environment**: It is recommended to develop in Docker containers
3. **Memory Safety**: Zig does not guarantee memory safety, so careful coding is required


## Reference Resources

- [Zig Official Documentation](https://ziglang.org/documentation/)
- [Zig Standard Library](https://ziglang.org/documentation/master/std/)
- [Zig Learn](https://ziglearn.org/)


## Instructions for AI Agents

When assisting with this project, please note the following:

1. Understand Zig's type system and memory management model
2. Use error handling patterns appropriately
3. Suggest performance-conscious code
4. Prioritize the use of standard library functions
5. Consider operation in container environments
