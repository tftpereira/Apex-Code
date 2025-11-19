# Apex Utilities for Salesforce

A curated set of Apex utilities, patterns, and productivity tools for Salesforce development. This repository provides battle-tested, lightweight, dependency-free code that can be used in both managed packages and Enterprise Orgs. Designed for Admin, Developer, and Architect audiences who need pragmatic solutions without heavy framework dependencies.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI Status](https://img.shields.io/badge/CI-TODO-blue)](https://github.com/your-org/apex-utilities)
[![Code Coverage](https://img.shields.io/badge/Coverage-TODO-green)](https://github.com/your-org/apex-utilities)
[![API Version](https://img.shields.io/badge/API-60.0-orange)](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/)

## Table of Contents

- [Key Features](#key-features)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Configuration](#configuration)
- [Quick Examples](#quick-examples)
- [Architecture and Principles](#architecture-and-principles)
- [Module Catalog](#module-catalog)
- [Documentation](#documentation)
- [Testing](#testing)
- [Contributing](#contributing)
- [Versioning and Support](#versioning-and-support)
- [Roadmap](#roadmap)
- [FAQ](#faq)
- [License](#license)
- [Credits](#credits)

## Key Features

- **Mocking Framework** - DX-first mocking with `when/thenReturn/thenThrow/thenAnswer` syntax and essential matchers. Built on Salesforce's Stub API for reliable test isolation. See [Mock Framework README](Mock%20Framework/README.md) for details.

- **UnitOfWork** - Standalone implementation of the Unit of Work pattern for batched DML operations, relationship resolution, Platform Events, and generic work execution. Simplifies transaction management without heavyweight frameworks. See [UnitOfWork README](UnitOfWork/README.md) for details.

- **Cache** - In-memory caching system for selector results, reducing database queries and improving transaction performance. Supports superset lookups and advanced filtering. See [Cache README](Cache/README.md) for details.

All modules are independent and can be adopted à la carte. Mix and match based on your project needs.

## Getting Started

### Prerequisites

- Salesforce org (Developer, Sandbox, or Production)
- Salesforce CLI (SFDX CLI) v7.0 or later
- API version 60.0 or later
- Basic familiarity with Apex development

### Installation

#### Option 1: SFDX (Recommended for Development)

1. Clone the repository:
```bash
git clone https://github.com/your-org/apex-utilities.git
cd apex-utilities
```

2. Authenticate with your Salesforce org:
```bash
sfdx auth:web:login -a myorg
```

3. Deploy source to your org:
```bash
sfdx project deploy start --source-dir force-app/main/default/classes
```

4. Or deploy to a scratch org:
```bash
sfdx org create scratch -f config/project-scratch-def.json -a apex-utils-scratch
sfdx project deploy start
```

#### Option 2: Unlocked Package (Coming Soon)

Unlocked packages will be available for easier installation:

```bash
sfdx package install --package apex-utilities@latest -w 10
```

#### Option 3: Manual Deployment (Metadata API)

Use your preferred IDE (VS Code with Salesforce Extensions, Illuminated Cloud, etc.) or the Metadata API to deploy the classes to your org.

### Configuration

- **API Version**: Set the API version in each class's `-meta.xml` file. Recommended: 60.0 or later.

- **Namespace**: For managed packages, add your namespace prefix to class references. The utilities are designed to work in both namespaced and non-namespaced contexts.

- **Permissions**: Most utilities require no special permissions. Some modules (like Platform Event helpers) may require specific object permissions for testing.

## Quick Examples

### Mocking Framework

```apex
// Create a mock
IMyService mockService = (IMyService) MockService.createMock(IMyService.class);

// Configure behavior
when(mockService).method('sum', eq(2), eq(3)).thenReturn(5);
when(mockService).method('process', anyString()).thenThrow(new CustomException('Error'));

// Use in test
Integer result = mockService.sum(2, 3);
System.assertEquals(5, result);

// Verify interactions
verify(mockService).method('sum', eq(2), eq(3)).times(1);
```

See [Mock Framework README](Mock%20Framework/README.md) for complete documentation.

### UnitOfWork

```apex
// Get UnitOfWork instance
IUnitOfWork uow = Application.unitOfWork.newInstance();

// Register operations
Account acc = new Account(Name = 'Acme Corp');
uow.registerNew(acc);

Contact con = new Contact(LastName = 'Doe');
uow.registerNew(con, Contact.AccountId, acc);  // Automatic relationship

// Commit all operations in a transaction
uow.commitWork();
```

See [UnitOfWork README](UnitOfWork/README.md) for complete documentation.

### Cache

```apex
// In your selector
public List<Account> selectByIds(Set<Id> accountIds) {
    String cacheKey = SelectorCache.generateCacheKey('AccountSelector', 'selectByIds', accountIds);
    
    if (SelectorCache.containsKey(cacheKey)) {
        return (List<Account>) SelectorCache.get(cacheKey);
    }

    List<Account> results = [SELECT Id, Name FROM Account WHERE Id IN :accountIds];
    SelectorCache.put(cacheKey, results);
    return results;
}
```

See [Cache README](Cache/README.md) for complete documentation.

## Architecture and Principles

This repository follows several core design principles:

- **Dependency-Free Core**: No external dependencies between modules. Each utility can stand alone.

- **Clear Interfaces**: Public APIs are well-defined with minimal surface area. Internal implementation details are hidden.

- **Small, Focused Classes**: Each class has a single responsibility. Avoids monolithic utilities that are hard to test and maintain.

- **Governor-Aware Patterns**: All utilities respect Salesforce governor limits and provide mechanisms to work within them.

- **Testability First**: Every module is designed to be easily testable. Mocking framework enables isolation, and factories simplify test data creation.

- **Enterprise Pattern Consistency**: Aligns with common enterprise patterns (like fflib-style architecture) without strict coupling. You can adopt patterns incrementally.

- **Managed Package Friendly**: Code works in both namespaced and non-namespaced contexts. No hardcoded assumptions about package structure.

## Module Catalog

| Module | Purpose | Namespace Impact | Status | Documentation |
|--------|---------|------------------|--------|---------------|
| [Mock Framework](Mock%20Framework/) | Test isolation via Stub API with fluent `when/thenReturn` syntax | None | Stable | [Mock Framework README](Mock%20Framework/README.md) |
| [UnitOfWork](UnitOfWork/) | Batched DML operations, relationship resolution, Platform Events | None | Stable | [UnitOfWork README](UnitOfWork/README.md) |
| [Cache](Cache/) | In-memory caching for selector results with superset support | None | Stable | [Cache README](Cache/README.md) |

## Documentation

Module-specific documentation is available in each module's directory:

- **[Mock Framework](Mock%20Framework/README.md)** - Mocking framework usage, matchers, and verification
- **[UnitOfWork](UnitOfWork/README.md)** - Unit of Work pattern, DML operations, and Platform Events
- **[Cache](Cache/README.md)** - Selector caching, superset lookups, and cache management

Each README includes:
- Overview and use cases
- API reference
- Code examples
- Best practices
- Common pitfalls

To run module-specific examples, deploy the example classes to a scratch org and execute the test methods.

## Testing

### Running Tests

Run all tests via Salesforce CLI:

```bash
sfdx apex run test --result-format human --code-coverage
```

Run specific test classes:

```bash
sfdx apex run test --class-names MockingFrameworkTest --result-format human
```

### Test Guidelines

When writing tests for this repository or using its utilities:

- **Given-When-Then Structure**: Organize tests with clear arrange/act/assert sections.

- **Isolation**: Each test should be independent. Use `@TestSetup` for shared data, but avoid test interdependencies.

- **No DML in Pure Unit Tests**: Use the mocking framework and test data factory. Only use actual DML when testing DML-specific behavior.

- **Use Factories**: Leverage the test data factory for consistent, maintainable test data. Avoid hardcoded record creation.

- **Mock External Dependencies**: Use the mocking framework for callouts, service layers, and complex dependencies.

- **Coverage Thresholds**: Aim for 90%+ code coverage. Focus on covering edge cases and error paths.

## Contributing

We welcome contributions! Here's how to get involved:

### Opening Issues

- **Bug Reports**: Include steps to reproduce, expected vs actual behavior, and Salesforce org details.
- **Feature Requests**: Describe the use case and proposed solution.
- **Questions**: Use GitHub Discussions for general questions.

### Submitting Pull Requests

1. Fork the repository and create a feature branch.
2. Make your changes following the coding standards below.
3. Add or update tests for new functionality.
4. Ensure all tests pass and coverage remains high.
5. Submit a PR with a clear description of changes.

### Coding Standards

- **Naming**: Use descriptive names. Classes: PascalCase. Methods/Variables: camelCase. Constants: UPPER_SNAKE_CASE.

- **Class Size**: Keep classes focused. If a class exceeds 500 lines, consider splitting responsibilities.

- **No Static Singletons**: Avoid global state. Prefer dependency injection and interfaces.

- **Mock via Interfaces**: Design classes to depend on interfaces, not concrete implementations. This enables testing.

- **Avoid Global State**: Minimize static variables. Use instance state and dependency injection.

- **Documentation**: Add JSDoc-style comments for public methods. Include parameter descriptions and return values.

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat: add retry policy for callouts`
- `fix: correct SOQL injection in query builder`
- `docs: update mocking framework examples`
- `test: add coverage for edge cases`

### PR Checklist

- [ ] Code follows style guidelines
- [ ] Tests added/updated and passing
- [ ] Documentation updated
- [ ] No linter errors
- [ ] Commit messages follow convention

## Versioning and Support

### Semantic Versioning

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes to public APIs
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Supported Salesforce Versions

- **Minimum API Version**: 60.0
- **Tested On**: API versions 60.0 through 62.0
- **Salesforce Editions**: Developer, Professional, Enterprise, Unlimited, Performance

### Compatibility

- **Namespaced Orgs**: All utilities work in managed packages. Use namespace prefixes when referencing classes.
- **Non-Namespaced Orgs**: Works out of the box. No configuration needed.
- **Multi-Currency**: Utilities respect org currency settings where applicable.
- **Person Accounts**: Compatible with orgs that have Person Accounts enabled.

## Roadmap

Upcoming enhancements and features:

- **Unlocked Package**: Official unlocked package for easy installation
- **Additional Matchers**: More matcher types for the mocking framework (regex, custom predicates)
- **Cache Enhancements**: TTL support, cache size limits, and eviction policies
- **UnitOfWork Enhancements**: Additional hooks, batch size configuration, and performance optimizations
- **Documentation Site**: Hosted documentation with interactive examples

## FAQ

### Why another mocking framework?

While Salesforce provides the Stub API, it requires boilerplate code. This framework provides a DX-first API (`when/thenReturn`) that reduces test setup time while leveraging the Stub API under the hood. It's lightweight and doesn't require external dependencies.

### How do I use this without fflib?

All modules are independent. The UnitOfWork module is inspired by fflib patterns but is a standalone implementation. You can use it independently or alongside other frameworks.

### Does this work in managed packages?

Yes. All utilities are designed to work in both namespaced and non-namespaced contexts. When used in a managed package, simply prefix class names with your namespace (e.g., `MyNamespace__UnitOfWork`).

### Are there limits with the Stub API?

The Stub API has a limit of 10 stubs per test method. For complex scenarios, consider breaking tests into smaller units or using dependency injection to reduce stub count.

### How do utilities handle governor limits?

Utilities are governor-aware and provide mechanisms to work within limits. For example, the UnitOfWork batches DML operations to minimize DML statements, and the Cache reduces SOQL queries within a transaction. Always monitor your usage in production.

### Can I use individual modules without the rest?

Absolutely. Each module is independent. You can use:
- Only the Mock Framework for testing
- Only the UnitOfWork for DML management
- Only the Cache for selector optimization
- Or any combination that fits your needs

Copy only the classes you need, or use the entire repository. The architecture supports à la carte adoption.

### What's the performance impact?

Utilities are designed to be lightweight with minimal overhead. The mocking framework adds negligible performance cost in tests. The Cache module reduces database queries, and the UnitOfWork optimizes DML operations by batching them efficiently.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Credits

This repository draws inspiration from several community patterns and projects:

- **fflib-apex-common**: Unit of Work and Selector patterns (UnitOfWork module is inspired by but independent from fflib)
- **Apex Stub API**: Foundation for the mocking framework
- **Mockito**: API design inspiration for the mocking framework
- **Salesforce Community**: Various utility patterns shared by the community

Special thanks to the Salesforce developer community for sharing patterns, best practices, and feedback that shaped these utilities.
