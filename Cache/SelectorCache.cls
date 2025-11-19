/**
 * @description       : Utility class to manage cache of selector results
 * @author            : 
 * @group             : 
 * @last modified on  : 
 * @last modified by  : 
**/
public with sharing class SelectorCache {
    
    // Static map to store cache by key
    private static Map<String, Object> cache = new Map<String, Object>();
    
    private static String currentTransactionId;
    
    /**
     * @description Gets the current transaction ID or creates a new one if necessary
     * @return String Transaction ID
     */
    private static String getTransactionId() {
        if (currentTransactionId == null) {
            currentTransactionId = String.valueOf(Crypto.getRandomLong());
        }
        return currentTransactionId;
    }
    
    /**
     * @description Generates a unique cache key based on selector, method and parameters
     * @param selectorName Selector class name
     * @param methodName Selector method name
     * @param params Method parameters (Set<Id>, Set<String>, etc.)
     * @return String Unique cache key
     */
    public static String generateCacheKey(String selectorName, String methodName, Object params) {
        String transactionId = getTransactionId();
        String paramsKey = serializeParams(params);
        return selectorName + '|' + methodName + '|' + paramsKey + '|' + transactionId;
    }
    
    /**
     * @description Generates a cache key dynamically by automatically detecting the class and method
     * @param selectorInstance Selector instance (use 'this' inside the selector method)
     * @param methodName Method name (can be obtained dynamically or passed manually)
     * @param params Method parameters
     * @return String Unique cache key
     */
    public static String generateCacheKey(Object selectorInstance, String methodName, Object params) {
        String selectorName = getClassName(selectorInstance);
        return generateCacheKey(selectorName, methodName, params);
    }
    
    /**
     * @description Generates a cache key in a fully dynamic way (detects class and method)
     * @param selectorInstance Selector instance (use 'this' inside the selector method)
     * @param params Method parameters
     * @return String Unique cache key
     * @note The method name will be obtained from the stack trace, so it must be called directly from the method
     */
    public static String generateCacheKey(Object selectorInstance, Object params) {
        String selectorName = getClassName(selectorInstance);
        String methodName = getCurrentMethodName();
        return generateCacheKey(selectorName, methodName, params);
    }
    
    /**
     * @description Gets the class name from an instance
     * @param instance Object instance
     * @return String Class name
     */
    private static String getClassName(Object instance) {
        if (instance == null) {
            return 'Unknown';
        }
        String className = String.valueOf(instance);
        if (className.contains(':')) {
            className = className.split(':')[0];
        }
        return className;
    }
    
    /**
     * @description Gets the class name from an instance (public method)
     * @param instance Object instance
     * @return String Class name
     */
    public static String getSelectorName(Object instance) {
        return getClassName(instance);
    }
    
    /**
     * @description Gets the current method name from the stack trace
     * @return String Method name
     */
    private static String getCurrentMethodName() {
        try {
            String stackTrace = new DmlException().getStackTraceString();
            if (String.isNotBlank(stackTrace)) {
                List<String> lines = stackTrace.split('\n');
                if (lines.size() > 2) {
                    String methodLine = lines[2].trim();
                    if (methodLine.contains('.')) {
                        String methodPart = methodLine.substring(methodLine.lastIndexOf('.') + 1);
                        if (methodPart.contains(':')) {
                            return methodPart.split(':')[0];
                        }
                        return methodPart;
                    }
                }
            }
        } catch (Exception e) {
        }
        return 'unknownMethod';
    }
    
    /**
     * @description Serializes parameters to create a unique key
     * @param params Parameters to be serialized
     * @return String Serialized representation of the parameters
     */
    private static String serializeParams(Object params) {
        if (params == null) {
            return 'null';
        }
        
        if (params instanceof Map<String, Object>) {
            Map<String, Object> paramMap = (Map<String, Object>) params;
            List<String> sortedKeys = new List<String>(paramMap.keySet());
            sortedKeys.sort();
            List<String> serializedValues = new List<String>();
            for (String key : sortedKeys) {
                serializedValues.add(key + ':' + serializeParams(paramMap.get(key)));
            }
            return String.join(serializedValues, '|');
        }
        
        if (params instanceof Set<Id>) {
            Set<Id> idSet = (Set<Id>) params;
            List<Id> sortedIds = new List<Id>(idSet);
            sortedIds.sort();
            return String.join(sortedIds, ',');
        }
        
        if (params instanceof Set<String>) {
            Set<String> stringSet = (Set<String>) params;
            List<String> sortedStrings = new List<String>(stringSet);
            sortedStrings.sort();
            return String.join(sortedStrings, ',');
        }
        
        if (params instanceof List<Object>) {
            return JSON.serialize(params);
        }
        
        return String.valueOf(params);
    }
    
    /**
     * @description Gets a value from the cache
     * @param cacheKey Cache key
     * @return Object Value stored in cache or null if it doesn't exist
     */
    public static Object get(String cacheKey) {
        return cache.get(cacheKey);
    }
    
    /**
     * @description Stores a value in the cache
     * @param cacheKey Cache key
     * @param value Value to be stored
     */
    public static void put(String cacheKey, Object value) {
        if (cacheKey != null && value != null) {
            cache.put(cacheKey, value);
        }
    }
    
    /**
     * @description Checks if a key exists in the cache
     * @param cacheKey Cache key
     * @return Boolean True if the key exists, false otherwise
     */
    public static Boolean containsKey(String cacheKey) {
        return cache.containsKey(cacheKey);
    }
    
    /**
     * @description Finds a cache entry that contains a superset of the requested IDs
     * @param selectorName Selector class name
     * @param methodName Method name
     * @param requestedIds Set of IDs being requested
     * @return String Cache key of the superset, or null if not found
     */
    public static String findSupersetCacheKey(String selectorName, String methodName, Set<Id> requestedIds) {
        if (requestedIds == null || requestedIds.isEmpty()) {
            return null;
        }
        
        String prefix = selectorName + '|' + methodName + '|';
        
        // Procura por chaves que correspondem ao seletor e método
        for (String cacheKey : cache.keySet()) {
            if (cacheKey.startsWith(prefix)) {
                // Extrai os IDs da chave do cache
                // Formato: selectorName|methodName|params|transactionId
                String paramsPart = cacheKey.substring(prefix.length());
                
                // Remove o transactionId do final (última parte após o último |)
                Integer lastPipeIndex = paramsPart.lastIndexOf('|');
                if (lastPipeIndex > 0) {
                    paramsPart = paramsPart.substring(0, lastPipeIndex);
                }
                
                // Parse dos IDs da chave
                Set<Id> cachedIds = parseIdsFromKey(paramsPart);
                
                // Verifica se os IDs em cache contêm todos os IDs solicitados (superconjunto)
                if (cachedIds != null && !cachedIds.isEmpty() && cachedIds.containsAll(requestedIds)) {
                    return cacheKey;
                }
            }
        }
        
        return null;
    }
    
    /**
     * @description Parses a comma-separated string of IDs into a Set
     * @param idsString Comma-separated string of IDs
     * @return Set<Id> Set of parsed IDs
     */
    private static Set<Id> parseIdsFromKey(String idsString) {
        if (String.isBlank(idsString) || idsString == 'null') {
            return new Set<Id>();
        }
        
        Set<Id> ids = new Set<Id>();
        for (String idStr : idsString.split(',')) {
            if (String.isNotBlank(idStr)) {
                ids.add(idStr.trim());
            }
        }
        return ids;
    }
    
    /**
     * @description Filters a list of SObjects to include only those matching the requested IDs
     * This is a generic method that works with any SObject type
     * @param results List of SObjects from cache
     * @param requestedIds Set of IDs to filter by
     * @param idFieldName Name of the ID field to check (e.g., 'Id', 'Proposal__c', 'QuoteId')
     * @return List<SObject> Filtered list of SObjects
     */
    public static List<SObject> filterResultsByIds(List<SObject> results, Set<Id> requestedIds, String idFieldName) {
        if (results == null || results.isEmpty() || requestedIds == null || requestedIds.isEmpty()) {
            return new List<SObject>();
        }
        
        List<SObject> filtered = new List<SObject>();
        for (SObject obj : results) {
            Object fieldValue = obj.get(idFieldName);
            if (fieldValue != null && requestedIds.contains((Id)fieldValue)) {
                filtered.add(obj);
            }
        }
        return filtered;
    }
    
    /**
     * @description Filters results by checking multiple ID fields (for complex queries with OR conditions)
     * Supports both direct fields and relationship fields (e.g., 'Proposal__c' or 'ProposalLineItem__r.QuoteId')
     * @param results List of SObjects from cache
     * @param requestedIds Set of IDs to filter by
     * @param idFieldNames List of field names to check (can include relationship fields like 'RelatedObject__r.Field__c')
     * @return List<SObject> Filtered list of SObjects
     */
    public static List<SObject> filterResultsByMultipleIdFields(List<SObject> results, Set<Id> requestedIds, List<String> idFieldNames) {
        if (results == null || results.isEmpty() || requestedIds == null || requestedIds.isEmpty()) {
            return new List<SObject>();
        }
        
        List<SObject> filtered = new List<SObject>();
        for (SObject obj : results) {
            Boolean matches = false;
            for (String fieldName : idFieldNames) {
                try {
                    Object fieldValue = null;
                    
                    // Se o campo contém '__r.', é um relacionamento
                    if (fieldName.contains('__r.')) {
                        // Divide o campo em relação e campo do relacionamento
                        List<String> parts = fieldName.split('\\.');
                        if (parts.size() == 2) {
                            String relationshipName = parts[0];
                            String relatedFieldName = parts[1];
                            
                            // Acessa o SObject relacionado
                            SObject relatedObj = obj.getSObject(relationshipName);
                            if (relatedObj != null) {
                                fieldValue = relatedObj.get(relatedFieldName);
                            }
                        }
                    } else {
                        // Campo direto
                        fieldValue = obj.get(fieldName);
                    }
                    
                    if (fieldValue != null && requestedIds.contains((Id)fieldValue)) {
                        matches = true;
                        break;
                    }
                } catch (Exception e) {
                    // Field might not exist or be null, continue checking other fields
                }
            }
            if (matches) {
                filtered.add(obj);
            }
        }
        return filtered;
    }
    
    /**
     * @description Removes a specific entry from the cache
     * @param cacheKey Cache key to be removed
     */
    public static void remove(String cacheKey) {
        cache.remove(cacheKey);
    }
    
    /**
     * @description Clears the entire cache
     */
    public static void clear() {
        cache.clear();
        currentTransactionId = null;
    }
    
    /**
     * @description Clears the cache for a specific selector
     * @param selectorName Selector class name
     */
    public static void clearSelectorCache(String selectorName) {
        List<String> keysToRemove = new List<String>();
        for (String key : cache.keySet()) {
            if (key.startsWith(selectorName + '|')) {
                keysToRemove.add(key);
            }
        }
        for (String key : keysToRemove) {
            cache.remove(key);
        }
    }
    
    /**
     * @description Removes a specific cache entry based on selector, method and parameters
     * @param selectorName Selector class name
     * @param methodName Method name
     * @param params Method parameters
     */
    public static void removeCacheEntry(String selectorName, String methodName, Object params) {
        String cacheKey = generateCacheKey(selectorName, methodName, params);
        remove(cacheKey);
    }
    
    /**
     * @description Removes a specific cache entry dynamically
     * @param selectorInstance Selector instance
     * @param methodName Method name
     * @param params Method parameters
     */
    public static void removeCacheEntry(Object selectorInstance, String methodName, Object params) {
        String cacheKey = generateCacheKey(selectorInstance, methodName, params);
        remove(cacheKey);
    }
    
    /**
     * @description Clears the cache for a specific method of a selector
     * @param selectorName Selector class name
     * @param methodName Method name
     */
    public static void clearMethodCache(String selectorName, String methodName) {
        String prefix = selectorName + '|' + methodName + '|';
        List<String> keysToRemove = new List<String>();
        for (String key : cache.keySet()) {
            if (key.startsWith(prefix)) {
                keysToRemove.add(key);
            }
        }
        for (String key : keysToRemove) {
            cache.remove(key);
        }
    }
    
    /**
     * @description Resets the transaction ID (useful for tests or when needed)
     */
    public static void resetTransaction() {
        currentTransactionId = null;
    }
}

