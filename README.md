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

- **Mocking Framework** - DX-first mocking with `when/thenReturn/thenThrow/thenAnswer` syntax and essential matchers. Built on Salesforce's Stub API for reliable test isolation.

- **UoW Helpers** - Thin wrappers for batched DML operations with automatic error aggregation. Simplifies transaction management without heavyweight frameworks.

- **SOQL Builders** - Safe query builder with bind-style variables and field allowlists. Prevents SOQL injection while maintaining query flexibility.

- **Selector/Service Scaffolds** - fflib-style base classes and interfaces for consistent data access and business logic patterns. Promotes separation of concerns.

- **Validation and Guard Utils** - Fluent validation checks with contextual error messages. Reduces boilerplate in validation logic and improves error handling.

- **SObject Test Data Factory** - Deterministic test data creation with relationship support and anonymization helpers. Enables fast, isolated unit tests.

- **Retry & Circuit-Breaker** - Governor-aware retry policies and simple circuit breaker pattern. Handles transient failures gracefully within Salesforce limits.

- **Platform Event Test Helpers** - Publish/subscribe stubs for unit testing Platform Events. Enables test-driven development for event-driven architectures.

- **JSON & Type Utils** - Safe JSON parse/serialize utilities, deep copy operations, and lightweight Option/Either types. Reduces null pointer exceptions and improves type safety.

- **Logging & Telemetry** - Pluggable logging interface with no-op default implementation. Supports debug traces and can be extended with custom adapters.

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
IMyService mockService = (IMyService) Test.createStub(
    IMyService.class, 
    new MockService()
);

// Configure behavior
when(mockService.sum(eq(2), eq(3))).thenReturn(5);
when(mockService.process(anyString())).thenThrow(new CustomException('Error'));

// Use in test
Integer result = mockService.sum(2, 3);
System.assertEquals(5, result);

// Verify interactions
verify(mockService).sum(eq(2), eq(3)).times(1);
```

### UoW Helpers

```apex
UnitOfWork uow = new UnitOfWork();

// Register operations
uow.registerNew(new Account(Name = 'Acme Corp'));
uow.registerUpdate(existingContact);
uow.registerDelete(oldRecord);

// Commit with error aggregation
UoWResult result = uow.commit();
if (!result.isSuccess()) {
    for (UoWError error : result.getErrors()) {
        System.debug('Error: ' + error.getMessage());
    }
}
```

### Selector Pattern

```apex
// In your selector class
public class AccountSelector extends SelectorBase {
    public List<Account> selectByIds(Set<Id> accountIds) {
        return (List<Account>) selectSObjectsById(accountIds);
    }
}

// Usage
AccountSelector selector = new AccountSelector();
List<Account> accounts = selector.selectByIds(new Set<Id>{'001...'});
```

### Retry

```apex
RetryResult result = Retry.run(
    maxAttempts = 3,
    backoffMs = 50,
    operation = () -> {
        HttpRequest req = new HttpRequest();
        // ... configure request
        return http.send(req);
    }
);

if (result.isSuccess()) {
    HttpResponse response = (HttpResponse) result.getResult();
} else {
    System.debug('Failed after retries: ' + result.getError());
}
```

### Test Data Factory

```apex
// Create accounts with related contacts
List<Account> accounts = Accounts
    .withContacts(3)
    .named('Acme')
    .buildList(5);

// Create with custom fields
Account acc = Accounts
    .withIndustry('Technology')
    .withBillingCity('San Francisco')
    .build();

// Create with relationships
Opportunity opp = Opportunities
    .forAccount(acc)
    .withAmount(10000)
    .build();
```

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
| Mocking Framework | Test isolation via Stub API | None | Stable | [docs/mocking.md](docs/mocking.md) |
| UoW Helpers | Batched DML with error handling | None | Stable | [docs/uow.md](docs/uow.md) |
| SOQL Builders | Safe query construction | None | Stable | [docs/soql-builders.md](docs/soql-builders.md) |
| Selector/Service Scaffolds | Base classes for data/business layers | Optional | Stable | [docs/selector-service.md](docs/selector-service.md) |
| Validation and Guard Utils | Fluent validation checks | None | Stable | [docs/validation.md](docs/validation.md) |
| SObject Test Data Factory | Deterministic test data creation | None | Stable | [docs/test-factory.md](docs/test-factory.md) |
| Retry & Circuit-Breaker | Governor-aware retry policies | None | Stable | [docs/retry.md](docs/retry.md) |
| Platform Event Test Helpers | Event publish/subscribe stubs | None | Stable | [docs/platform-events.md](docs/platform-events.md) |
| JSON & Type Utils | Safe JSON and type operations | None | Stable | [docs/json-types.md](docs/json-types.md) |
| Logging & Telemetry | Pluggable logging interface | None | Stable | [docs/logging.md](docs/logging.md) |

## Documentation

Module-specific documentation is available in the `docs/` directory:

- `docs/mocking.md` - Mocking framework usage and matchers
- `docs/uow.md` - Unit of Work pattern and error handling
- `docs/soql-builders.md` - Query builder API and security
- `docs/selector-service.md` - Selector and Service base classes
- `docs/validation.md` - Validation utilities and guard clauses
- `docs/test-factory.md` - Test data factory patterns
- `docs/retry.md` - Retry policies and circuit breaker
- `docs/platform-events.md` - Platform Event testing
- `docs/json-types.md` - JSON utilities and type helpers
- `docs/logging.md` - Logging interface and adapters

Each documentation file includes:
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
- **Telemetry Adapters**: Additional adapters for logging (Splunk, DataDog, etc.)
- **Additional Matchers**: More matcher types for the mocking framework (regex, custom predicates)
- **Async Utilities**: Helpers for Queueable, Batchable, and Schedulable patterns
- **SOQL Pagination Helpers**: Utilities for handling large result sets with pagination
- **Enhanced Test Factory**: More relationship builders and bulk creation optimizations
- **Documentation Site**: Hosted documentation with interactive examples

## FAQ

### Why another mocking framework?

While Salesforce provides the Stub API, it requires boilerplate code. This framework provides a DX-first API (`when/thenReturn`) that reduces test setup time while leveraging the Stub API under the hood. It's lightweight and doesn't require external dependencies.

### How do I use this without fflib?

All modules are independent. You can use the Selector/Service scaffolds as a starting point, or implement your own patterns using the utilities (SOQL builders, UoW helpers) without adopting the full fflib architecture.

### Does this work in managed packages?

Yes. All utilities are designed to work in both namespaced and non-namespaced contexts. When used in a managed package, simply prefix class names with your namespace (e.g., `MyNamespace__UnitOfWork`).

### Are there limits with the Stub API?

The Stub API has a limit of 10 stubs per test method. For complex scenarios, consider breaking tests into smaller units or using dependency injection to reduce stub count.

### How do utilities handle governor limits?

Utilities are governor-aware and provide mechanisms to work within limits. For example, the UoW helpers batch DML operations, and the retry utilities respect callout limits. Always monitor your usage in production.

### Can I use individual modules without the rest?

Absolutely. Each module is independent. Copy only the classes you need, or use the entire repository. The architecture supports à la carte adoption.

### What's the performance impact?

Utilities are designed to be lightweight with minimal overhead. The mocking framework adds negligible performance cost in tests. Production utilities (like retry policies) are optimized for minimal CPU time.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Credits

This repository draws inspiration from several community patterns and projects:

- **fflib-apex-common**: Selector and Service layer patterns
- **Apex Stub API**: Foundation for the mocking framework
- **Salesforce Community**: Various utility patterns shared by the community

Special thanks to the Salesforce developer community for sharing patterns, best practices, and feedback that shaped these utilities.
