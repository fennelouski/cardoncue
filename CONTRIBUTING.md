# Contributing to CardOnCue

Thank you for your interest in contributing to CardOnCue! This document provides guidelines for contributing to the project.

## Code of Conduct

Be respectful, inclusive, and constructive. We're all here to build something useful together.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/your-username/CardOnCue/issues)
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs. actual behavior
   - Screenshots (if applicable)
   - Environment (iOS version, Xcode version, etc.)

### Suggesting Features

1. Check if the feature has already been suggested
2. Create an issue with tag `enhancement`
3. Describe:
   - Use case and problem it solves
   - Proposed solution
   - Alternative solutions considered

### Pull Requests

1. **Fork** the repository
2. **Create a branch**: `git checkout -b feature/my-feature`
3. **Make your changes**:
   - Follow coding style (see below)
   - Add tests for new features
   - Update documentation
4. **Test thoroughly**:
   - Run unit tests: `npm test` (backend) / `xcodebuild test` (iOS)
   - Test manually on simulator and device
5. **Commit**: Use clear, descriptive commit messages
6. **Push**: `git push origin feature/my-feature`
7. **Open PR**: Provide clear description of changes

### Coding Style

**Backend (JavaScript)**:
- Use ES6+ syntax
- 2-space indentation
- Semicolons required
- Follow ESLint rules
- JSDoc comments for functions

**iOS (Swift)**:
- Swift 5.9+ features
- 4-space indentation
- Clear naming (no abbreviations)
- Mark functions with `// MARK:` comments
- Use `async/await` over completion handlers

## Development Setup

See [README.md](README.md#quick-start) for setup instructions.

## Testing

All contributions should include tests:
- **Backend**: Jest unit tests
- **iOS**: XCTest unit tests

Run tests before submitting PR:
```bash
# Backend
cd web && npm test

# iOS
cd ios && xcodebuild test -project CardOnCue.xcodeproj -scheme CardOnCue -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Documentation

Update documentation when:
- Adding new features
- Changing APIs
- Updating architecture

Relevant files:
- `docs/architecture.md` - System design
- `docs/api-spec.yaml` - API endpoints
- `README.md` - User-facing docs

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
