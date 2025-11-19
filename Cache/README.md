# Cache Module

In-memory caching system to optimize selector queries, reducing database calls and improving transaction performance.

## Overview

The `Cache` module provides a lightweight and efficient solution for caching selector results during a transaction. The cache is automatically cleared between transactions, ensuring data doesn't become stale.

### Key Features

- **Transaction-Based Cache**: Each transaction has its own isolated cache
- **Automatic Key Generation**: Automatic key generation based on selector, method, and parameters
- **Superset Support**: Intelligent search for caches that contain supersets of requested IDs
- **Advanced Filtering**: Methods to filter results by IDs or multiple fields
- **Selective Cleanup**: Granular cache cleanup (by entry, method, or complete selector)

## Components

### SelectorCache

Main class that manages the cache of selector results.

## Basic Usage

### Example 1: Simple Method with Set<Id>

```apex
public List<Quote> selectByOpportunityIds(Set<Id> opportunityIds) {
    if (opportunityIds == null || opportunityIds.isEmpty()) {
        return new List<Quote>();
    }

    // Generate cache key
    String cacheKey = SelectorCache.generateCacheKey('QuotesSelector', 'selectByOpportunityIds', opportunityIds);
    
    // Check if exists in cache
    if (SelectorCache.containsKey(cacheKey)) {
        return (List<Quote>) SelectorCache.get(cacheKey);
    }

    // Execute query
    List<Quote> results = [
        SELECT Id, OpportunityId 
        FROM Quote 
        WHERE OpportunityId IN :opportunityIds
    ];
    
    // Store in cache and return
    SelectorCache.put(cacheKey, results);
    return results;
}
```

### Example 2: Method with Multiple Parameters

```apex
public List<Quote> selectByOpportunityIdsAndRecordType(Set<Id> opportunityIds, Id recordTypeId, Set<Id> excludeIds) {
    if (opportunityIds == null || opportunityIds.isEmpty()) {
        return new List<Quote>();
    }

    // Create a Map with all parameters
    Map<String, Object> params = new Map<String, Object>{
        'opportunityIds' => opportunityIds,
        'recordTypeId' => recordTypeId,
        'excludeIds' => excludeIds
    };
    
    String cacheKey = SelectorCache.generateCacheKey('QuotesSelector', 'selectByOpportunityIdsAndRecordType', params);
    
    if (SelectorCache.containsKey(cacheKey)) {
        return (List<Quote>) SelectorCache.get(cacheKey);
    }

    // Execute query...
    List<Quote> results = [/* your query here */];
    
    SelectorCache.put(cacheKey, results);
    return results;
}
```

### Example 3: Automatic Key Generation

```apex
public List<Account> selectByIds(Set<Id> accountIds) {
    // Using 'this' to automatically detect the class name
    String cacheKey = SelectorCache.generateCacheKey(this, 'selectByIds', accountIds);
    
    if (SelectorCache.containsKey(cacheKey)) {
        return (List<Account>) SelectorCache.get(cacheKey);
    }

    List<Account> results = [SELECT Id, Name FROM Account WHERE Id IN :accountIds];
    SelectorCache.put(cacheKey, results);
    return results;
}
```

## Advanced Features

### Superset Lookup

When you request a set of IDs, the cache can check if there's already a cache that contains all those IDs (and possibly more):

```apex
// Check if there's a cache that contains all requested IDs
String supersetKey = SelectorCache.findSupersetCacheKey('QuotesSelector', 'selectByOpportunityIds', requestedIds);

if (supersetKey != null) {
    List<Quote> cachedResults = (List<Quote>) SelectorCache.get(supersetKey);
    // Filter to return only requested IDs
    return SelectorCache.filterResultsByIds(cachedResults, requestedIds, 'OpportunityId');
}
```

### Filtering by Multiple Fields

For complex queries with OR conditions:

```apex
List<String> idFieldNames = new List<String>{
    'Proposal__c',
    'ProposalLineItem__r.QuoteId'
};

List<SObject> filtered = SelectorCache.filterResultsByMultipleIdFields(
    cachedResults, 
    requestedIds, 
    idFieldNames
);
```

## Cache Management

### Clear Specific Entry

```apex
Set<Id> quoteIds = new Set<Id>{'001xx000003DGbQAAW'};
SelectorCache.removeCacheEntry('QuotesSelector', 'selectByOpportunityIds', quoteIds);
```

### Clear Method Cache

```apex
SelectorCache.clearMethodCache('QuotesSelector', 'selectByOpportunityIds');
```

### Clear Complete Selector Cache

```apex
SelectorCache.clearSelectorCache('QuotesSelector');
```

### Clear All Cache

```apex
SelectorCache.clear();
```

### Reset Transaction

```apex
// Useful in tests to ensure isolation
SelectorCache.resetTransaction();
```

## API Reference

### Main Static Methods

#### `generateCacheKey(String selectorName, String methodName, Object params)`
Generates a unique cache key based on selector, method, and parameters.

#### `generateCacheKey(Object selectorInstance, String methodName, Object params)`
Generates key automatically detecting the selector class name.

#### `generateCacheKey(Object selectorInstance, Object params)`
Generates key automatically detecting class and method (via stack trace).

#### `get(String cacheKey)`
Returns the value stored in cache or `null` if it doesn't exist.

#### `put(String cacheKey, Object value)`
Stores a value in the cache.

#### `containsKey(String cacheKey)`
Checks if a key exists in the cache.

#### `findSupersetCacheKey(String selectorName, String methodName, Set<Id> requestedIds)`
Searches for a cache that contains a superset of the requested IDs.

#### `filterResultsByIds(List<SObject> results, Set<Id> requestedIds, String idFieldName)`
Filters results to include only objects with matching IDs.

#### `filterResultsByMultipleIdFields(List<SObject> results, Set<Id> requestedIds, List<String> idFieldNames)`
Filters results by checking multiple fields (supports relationships).

#### `remove(String cacheKey)`
Removes a specific entry from the cache.

#### `clear()`
Clears all cache and resets the transaction.

#### `clearSelectorCache(String selectorName)`
Clears all cache for a specific selector.

#### `clearMethodCache(String selectorName, String methodName)`
Clears the cache for a specific method of a selector.

#### `removeCacheEntry(String selectorName, String methodName, Object params)`
Removes a specific cache entry based on selector, method, and parameters.

## Supported Parameter Types

The `SelectorCache` supports the following parameter types:

- `Set<Id>` - Automatically sorted to ensure consistency
- `Set<String>` - Automatically sorted
- `Map<String, Object>` - Keys sorted alphabetically
- `List<Object>` - Serialized as JSON
- Primitive types - Converted to String

## Best Practices

1. **Always validate parameters** before generating the cache key
2. **Use cache for frequent queries** that are called multiple times in the same transaction
3. **Clear cache when necessary** after DML operations that affect the data
4. **Use superset when appropriate** to reduce redundant queries
5. **Avoid caching very large queries** that may consume too much memory

## Limitations

- The cache is **per transaction** and is automatically cleared between transactions
- The cache is stored in static memory, so it doesn't persist between different execution contexts
- For very large queries, consider pagination instead of caching everything

## Complete Examples

See the `SelectorCacheExample.cls` class for detailed implementation examples.

## Compatibility

- **API Version**: 60.0+
- **Namespaces**: Works in orgs with and without namespace
- **Governor Limits**: Doesn't consume additional limits beyond memory usage
