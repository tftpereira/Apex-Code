# UnitOfWork Module

Standalone implementation of the Unit of Work pattern for managing batched DML operations, relationship resolution, Platform Events publishing, and generic work execution within a transaction.

## Overview

The `UnitOfWork` module provides a powerful abstraction for managing multiple DML operations efficiently and organized. It's inspired by the fflib pattern, but implemented as a standalone solution without external dependencies.

### Key Features

- **Batched DML**: Groups DML operations by object type for efficiency
- **Relationship Resolution**: Automatically resolves relationships between objects, including External IDs
- **Platform Events**: Support for publishing events at different phases (before, after success, after failure)
- **Pluggable DML Strategies**: Support for System Mode and User Mode
- **Generic Work**: Interface for executing custom work after DML
- **Email Sending**: Automatic email queue management

## Components

- **UnitOfWork**: Main class that implements the pattern
- **IUnitOfWork**: Public interface for abstraction
- **Application**: Factory for creating configured instances

## Basic Usage

### Initial Configuration

First, configure the object types that will be managed (in dependency order):

```apex
// In Application.cls
public static final Application.UnitOfWorkFactory unitOfWork =
    new Application.UnitOfWorkFactory(new List<Schema.SObjectType>{
        QuoteLineItem.SObjectType,  // Least dependent first
        Quote.SObjectType            // More dependent later
    });
```

### Simple Usage

```apex
// Get UnitOfWork instance
IUnitOfWork uow = Application.unitOfWork.newInstance();

// Register operations
Account acc = new Account(Name = 'Acme Corp');
uow.registerNew(acc);

Contact con = new Contact(LastName = 'Doe');
uow.registerNew(con, Contact.AccountId, acc);  // Automatic relationship

// Execute everything in a transaction
uow.commitWork();
```

## DML Operations

### Register New Records

```apex
// Simple registration
Account acc = new Account(Name = 'Test');
uow.registerNew(acc);

// Bulk registration
List<Account> accounts = new List<Account>{
    new Account(Name = 'Account 1'),
    new Account(Name = 'Account 2')
};
uow.registerNew(accounts);

// With relationship
Contact con = new Contact(LastName = 'Doe');
uow.registerNew(con, Contact.AccountId, acc);
```

### Register Updates

```apex
// Simple update
Account acc = [SELECT Id, Name FROM Account LIMIT 1];
acc.Name = 'Updated Name';
uow.registerDirty(acc);

// Bulk update
List<Account> accounts = [SELECT Id FROM Account LIMIT 10];
for (Account a : accounts) {
    a.Name = 'Updated';
}
uow.registerDirty(accounts);

// Update with specific fields
Account acc = [SELECT Id, Name, BillingCity FROM Account LIMIT 1];
acc.BillingCity = 'New York';
uow.registerDirty(acc, new List<Schema.SObjectField>{Account.BillingCity});

// With relationship
uow.registerDirty(con, Contact.AccountId, acc);
```

### Register Deletions

```apex
// Simple deletion
Account acc = [SELECT Id FROM Account LIMIT 1];
uow.registerDeleted(acc);

// Bulk deletion
List<Account> accounts = [SELECT Id FROM Account LIMIT 10];
uow.registerDeleted(accounts);

// Permanent deletion (empty recycle bin)
uow.registerPermanentlyDeleted(acc);
```

### Upsert

```apex
// Automatic upsert (insert if Id null, update if Id exists)
SObject record = /* your object */;
uow.registerUpsert(record);

List<SObject> records = /* your list */;
uow.registerUpsert(records);
```

## Relationships

### Relationship by SObject

```apex
Account acc = new Account(Name = 'Parent');
Contact con = new Contact(LastName = 'Child');

// Relate after registration
uow.registerNew(acc);
uow.registerNew(con);
uow.registerRelationship(con, Contact.AccountId, acc);
```

### Relationship by External ID

```apex
// When you have an External ID instead of Id
Contact con = new Contact(LastName = 'Doe');
uow.registerNew(con);

// Relate using External ID
uow.registerRelationship(
    con, 
    Contact.AccountId,           // Relationship field
    Account.ExternalId__c,      // External ID field on Account
    'EXT-12345'                  // External ID value
);
```

### Relationship with Email

```apex
Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
email.setSubject('Test');
email.setPlainTextBody('Body');

Account acc = new Account(Name = 'Test');
uow.registerNew(acc);
uow.registerEmail(email);
uow.registerRelationship(email, acc);  // Sets WhatId automatically
```

## Platform Events

### Publish Before Transaction

```apex
MyEvent__e event = new MyEvent__e(Data__c = 'Before transaction');
uow.registerPublishBeforeTransaction(event);

// Events will be published BEFORE any DML
uow.commitWork();
```

### Publish After Success

```apex
MyEvent__e event = new MyEvent__e(Data__c = 'After success');
uow.registerPublishAfterSuccessTransaction(event);

// Events will be published ONLY if transaction is successful
uow.commitWork();
```

### Publish After Failure

```apex
MyEvent__e event = new MyEvent__e(Data__c = 'After failure');
uow.registerPublishAfterFailureTransaction(event);

// Events will be published ONLY if transaction fails
uow.commitWork();
```

## Custom Work

### Register Generic Work

```apex
// Implement IDoWork interface
public class MyCustomWork implements UnitOfWork.IDoWork {
    public void doWork() {
        // Your custom code here
        System.debug('Executing custom work');
    }
}

// Register and execute
uow.registerWork(new MyCustomWork());
uow.commitWork();  // doWork() will be called after DML
```

## DML Strategies

### System Mode (Default)

```apex
// Uses System Mode (ignores field/object permissions)
IUnitOfWork uow = Application.unitOfWork.newInstance();
```

### User Mode

```apex
// Configure to use User Mode
UnitOfWork.UserModeDML userModeDML = new UnitOfWork.UserModeDML();
UnitOfWork uow = new UnitOfWork(
    new List<Schema.SObjectType>{Account.SObjectType, Contact.SObjectType},
    userModeDML
);

// Or with specific access level
UnitOfWork.UserModeDML customDML = new UnitOfWork.UserModeDML(System.AccessLevel.USER_MODE);
```

## Execution Order

When `commitWork()` is called, operations are executed in this order:

1. **Hook**: `onCommitWorkStarting()`
2. **Publish Before Events**: `onPublishBeforeEventsStarting()` → Publish events → `onPublishBeforeEventsFinished()`
3. **DML Operations**: `onDMLStarting()` → Insert → Update → Delete → Empty Recycle Bin → Resolve Email Relationships → `onDMLFinished()`
4. **Custom Work**: `onDoWorkStarting()` → Execute `IDoWork` → Send emails → `onDoWorkFinished()`
5. **Hook**: `onCommitWorkFinishing()`
6. **After Commit**:
   - If success: `onPublishAfterSuccessEventsStarting()` → Publish events → `onPublishAfterSuccessEventsFinished()`
   - If failure: `onPublishAfterFailureEventsStarting()` → Publish events → `onPublishAfterFailureEventsFinished()`
7. **Final Hook**: `onCommitWorkFinished(Boolean wasSuccessful)`

## Custom Hooks

You can extend `UnitOfWork` and override hooks to add custom logic:

```apex
public class MyUnitOfWork extends UnitOfWork {
    public MyUnitOfWork(List<Schema.SObjectType> types) {
        super(types);
    }
    
    public override void onDMLStarting() {
        System.debug('Starting DML operations');
    }
    
    public override void onDMLFinished() {
        System.debug('DML operations completed');
    }
    
    public override void onCommitWorkFinished(Boolean wasSuccessful) {
        if (wasSuccessful) {
            System.debug('Transaction successful');
        } else {
            System.debug('Transaction failed');
        }
    }
}
```

## Complete Example

```apex
public class AccountService {
    public void createAccountWithContacts(String accountName, List<String> contactNames) {
        IUnitOfWork uow = Application.unitOfWork.newInstance();
        
        // Create Account
        Account acc = new Account(Name = accountName);
        uow.registerNew(acc);
        
        // Create related Contacts
        for (String contactName : contactNames) {
            Contact con = new Contact(LastName = contactName);
            uow.registerNew(con, Contact.AccountId, acc);
        }
        
        // Publish event after success
        AccountCreated__e event = new AccountCreated__e(AccountName__c = accountName);
        uow.registerPublishAfterSuccessTransaction(event);
        
        // Send email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setSubject('Account Created');
        email.setPlainTextBody('Account ' + accountName + ' was created');
        uow.registerEmail(email);
        uow.registerRelationship(email, acc);
        
        // Execute everything
        uow.commitWork();
    }
}
```

## API Reference

### IUnitOfWork Interface

```apex
void registerNew(SObject record);
void registerNew(List<SObject> records);
void registerDirty(SObject record);
void registerDirty(List<SObject> records);
void registerDeleted(SObject record);
void registerDeleted(List<SObject> records);
void registerPublishAfterSuccessTransaction(SObject eventRecord);
void commitWork();
```

### UnitOfWork Class (Additional Methods)

- `registerNew(SObject, Schema.SObjectField, SObject)` - Register new with relationship
- `registerDirty(SObject, List<Schema.SObjectField>)` - Update specific fields
- `registerDirty(SObject, Schema.SObjectField, SObject)` - Update with relationship
- `registerUpsert(SObject)` - Automatic upsert
- `registerPermanentlyDeleted(SObject)` - Permanent deletion
- `registerPublishBeforeTransaction(SObject)` - Event before transaction
- `registerPublishAfterFailureTransaction(SObject)` - Event after failure
- `registerWork(IDoWork)` - Custom work
- `registerEmail(Messaging.Email)` - Send email
- `registerRelationship(...)` - Various overloads for relationships
- `getRegisteredNew(String)` - Access registered records
- `getRegisteredDirty(String)` - Access dirty records
- `getRegisteredDeleted(String)` - Access deleted records

## Best Practices

1. **Dependency Order**: Configure object types in the correct order (least dependent first)
2. **One Transaction**: Use one `UnitOfWork` per logical transaction
3. **Automatic Rollback**: `commitWork()` uses savepoint and automatically rolls back on error
4. **Hooks for Logging**: Use hooks to add logging or telemetry
5. **User Mode When Appropriate**: Use User Mode DML to respect permissions in production

## Limitations

- **DML Limit**: Respects Salesforce limits (150 DML statements per transaction)
- **Object Types**: Must register object types in constructor
- **Platform Events**: Only objects ending with `__e`
- **Relationships**: External IDs must be marked as External ID in schema

## Compatibility

- **API Version**: 60.0+
- **Namespaces**: Works in orgs with and without namespace
- **Platform Events**: Requires Platform Event objects configured
- **External IDs**: Requires fields marked as External ID

## Tests

See the included test classes for usage examples:
- `UnitOfWorkTest.cls`
- `UnitOfWorkSimpleDMLTest.cls`
- `UnitOfWorkUserModeDMLTest.cls`
- `UnitOfWorkEventRegistrationTest.cls`
