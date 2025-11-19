# Mock Framework

Mocking framework for Apex tests based on Salesforce's Stub API. Provides a fluent and intuitive API (`when/thenReturn/thenThrow/verify`) for creating mocks and verifying interactions in unit tests.

## Overview

The Mock Framework simplifies the creation of mocks and stubs for Apex interfaces, allowing code units to be isolated during testing. The API is inspired by popular frameworks like Mockito, but adapted for the limitations and capabilities of the Salesforce platform.

### Key Features

- **Fluent API**: Intuitive `when().method().thenReturn()` syntax
- **Flexible Matchers**: Support for matchers like `any()`, `eq()`, `isNull()`, etc.
- **Interaction Verification**: Verify how many times a method was called
- **Advanced Stubbing**: Support for `thenReturn`, `thenThrow`, and `thenAnswer`
- **Stub API Based**: Uses Salesforce's native API for maximum compatibility

## Main Components

- **MockService**: Entry point for creating mocks
- **When**: Initiates the stubbing process
- **StubbingBuilder**: Configures mock behavior
- **Verify**: Verifies interactions with the mock
- **Matchers**: Utilities for argument matching

## Basic Usage

### Creating a Mock

```apex
@isTest
private class MyServiceTest {
    @isTest
    static void testWithMock() {
        // Create a mock of an interface
        IMyService mockService = (IMyService) MockService.createMock(IMyService.class);
        
        // Configure behavior
        when(mockService).method('calculate', eq(5), eq(10)).thenReturn(15);
        
        // Use the mock
        Integer result = mockService.calculate(5, 10);
        System.assertEquals(15, result);
        
        // Verify interaction
        verify(mockService).method('calculate', eq(5), eq(10)).times(1);
    }
}
```

### Stubbing with Different Behaviors

```apex
// Return a value
when(mockService).method('getName').thenReturn('Test Name');

// Throw an exception
when(mockService).method('process', anyString()).thenThrow(new CustomException('Error'));

// Execute custom code
when(mockService).method('transform', anyString()).thenAnswer(new Answer() {
    public Object answer(InvocationContext ctx) {
        String input = (String) ctx.getArgument(0);
        return input.toUpperCase();
    }
});
```

## Matchers

### Available Matchers

```apex
// Any value of the type
anyString()
anyInteger()
anyBoolean()
anyId()
any(Type.class)  // For custom types

// Equality
eq(value)        // Exact value
isNull()         // Null value
isNotNull()      // Non-null value

// Strings
contains(substring)
startsWith(prefix)
endsWith(suffix)
matches(pattern)  // Regex (if supported)
```

### Matcher Usage Examples

```apex
// Accept any string
when(mockService).method('process', anyString()).thenReturn(true);

// Accept any ID
when(mockService).method('findById', anyId()).thenReturn(new Account());

// Accept specific value
when(mockService).method('calculate', eq(10), eq(20)).thenReturn(30);

// Accept null
when(mockService).method('handle', isNull()).thenReturn('null-handled');

// Combine matchers and literal values
when(mockService).method('update', any(Account.class), eq('Active')).thenReturn(true);
```

## Interaction Verification

### Verifying Calls

```apex
// Verify it was called at least once
verify(mockService).method('process', anyString());

// Verify exact number of calls
verify(mockService).method('calculate', eq(5), eq(10)).times(2);

// Verify it was never called
verify(mockService).method('delete', anyId()).never();

// Verify it was called at least N times
verify(mockService).method('update', any(Account.class)).atLeast(1);

// Verify it was called at most N times
verify(mockService).method('send', anyString()).atMost(3);
```

### Complete Verification Example

```apex
@isTest
static void testServiceInteraction() {
    IMyService mockService = (IMyService) MockService.createMock(IMyService.class);
    MyController controller = new MyController(mockService);
    
    // Execute action
    controller.processAccount('001xx000003DGbQAAW');
    
    // Verify interactions
    verify(mockService).method('findById', eq('001xx000003DGbQAAW')).times(1);
    verify(mockService).method('update', any(Account.class)).times(1);
    verify(mockService).method('sendEmail', anyString()).never();
}
```

## Advanced Stubbing

### Multiple Returns (Sequence)

```apex
// Return different values on consecutive calls
when(mockService).method('getNext').thenReturn(1).thenReturn(2).thenReturn(3);

Integer first = mockService.getNext();   // 1
Integer second = mockService.getNext();  // 2
Integer third = mockService.getNext();   // 3
```

### Custom Responses with thenAnswer

```apex
when(mockService).method('transform', anyString()).thenAnswer(new Answer() {
    public Object answer(InvocationContext ctx) {
        String input = (String) ctx.getArgument(0);
        List<String> args = ctx.getArguments();
        
        // Custom logic
        if (input.startsWith('A')) {
            return input.toUpperCase();
        }
        return input.toLowerCase();
    }
});
```

### Accessing Arguments in thenAnswer

```apex
when(mockService).method('process', anyString(), anyInteger()).thenAnswer(new Answer() {
    public Object answer(InvocationContext ctx) {
        String name = (String) ctx.getArgument(0);
        Integer count = (Integer) ctx.getArgument(1);
        
        // Use arguments for custom logic
        return name + '-' + count;
    }
});
```

## Usage Patterns

### Testing Service with Dependencies

```apex
@isTest
private class AccountServiceTest {
    @isTest
    static void testCreateAccountWithValidation() {
        // Create mocks of dependencies
        IValidator mockValidator = (IValidator) MockService.createMock(IValidator.class);
        IRepository mockRepo = (IRepository) MockService.createMock(IRepository.class);
        
        // Configure behavior
        when(mockValidator).method('validate', any(Account.class)).thenReturn(true);
        when(mockRepo).method('save', any(Account.class)).thenReturn(new Account(Id = '001xx000003DGbQAAW'));
        
        // Create service with injected mocks
        AccountService service = new AccountService(mockValidator, mockRepo);
        
        // Execute
        Account acc = new Account(Name = 'Test');
        Account result = service.createAccount(acc);
        
        // Verify
        System.assertNotEquals(null, result.Id);
        verify(mockValidator).method('validate', any(Account.class)).times(1);
        verify(mockRepo).method('save', any(Account.class)).times(1);
    }
}
```

### Testing Exceptions

```apex
@isTest
static void testHandlesException() {
    IMyService mockService = (IMyService) MockService.createMock(IMyService.class);
    
    // Configure to throw exception
    when(mockService).method('process', anyString())
        .thenThrow(new CustomException('Processing failed'));
    
    // Test exception handling
    try {
        mockService.process('test');
        System.assert(false, 'Should have thrown exception');
    } catch (CustomException e) {
        System.assertEquals('Processing failed', e.getMessage());
    }
}
```

## API Reference

### MockService

#### `createMock(Type typeToMock)`
Creates a mock for the specified interface.

```apex
Object mock = MockService.createMock(IMyService.class);
```

### When

#### `when(Object mock)`
Initiates the stubbing process for a mock.

```apex
When when = when(mock);
```

#### `method(String methodName)`
Stub for method with no arguments.

#### `method(String methodName, Object... args)`
Stub for method with arguments (supports up to 4 arguments or a list).

### StubbingBuilder

#### `thenReturn(Object value)`
Configures the mock to return a specific value.

#### `thenThrow(Exception exception)`
Configures the mock to throw an exception.

#### `thenAnswer(Answer answer)`
Configures the mock to execute custom code.

### Verify

#### `verify(Object mock)`
Initiates interaction verification.

#### `times(Integer count)`
Verifies the method was called exactly N times.

#### `never()`
Verifies the method was never called.

#### `atLeast(Integer count)`
Verifies the method was called at least N times.

#### `atMost(Integer count)`
Verifies the method was called at most N times.

## Limitations

1. **Stub Limit**: Salesforce Stub API allows a maximum of 10 stubs per test method
2. **Interfaces Only**: Can only create mocks of interfaces, not concrete classes
3. **Static Methods**: Cannot mock static methods
4. **Primitive Types**: Some matchers may have limitations with primitive types

## Best Practices

1. **Use Interfaces**: Design your classes to depend on interfaces, making mocking easier
2. **One Mock per Test**: Try to limit the number of mocks per test to keep tests simple
3. **Verify Essentials**: Verify only critical interactions, not all calls
4. **Stub Minimum Necessary**: Configure only the behavior necessary for the test
5. **Descriptive Names**: Use clear names for mocks and test variables

## Additional Examples

See the `MockFrameworkTest.cls` class for complete framework usage examples.

## Compatibility

- **API Version**: 60.0+
- **Stub API**: Requires Salesforce Stub API (available since API 40.0)
- **Namespaces**: Works in orgs with and without namespace
- **Test Context**: Only available in `@isTest` methods
