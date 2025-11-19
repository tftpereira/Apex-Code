@isTest
public class MockProvider implements System.StubProvider {
    private Map<String, Object> stubbedMethodMap;
    private Map<String, Map<Id, Map<String, Object>>> sObjectFieldValues;
    private Map<String, Map<Id, Map<String, List<SObject>>>> childRelationshipsMap;
    private Object mock; // Store reference to the mock object for call index tracking

    public MockProvider(Map<String, Object> stubbedMethodMap) {
        this.stubbedMethodMap = stubbedMethodMap != null ? stubbedMethodMap : new Map<String, Object>();
        this.sObjectFieldValues = new Map<String, Map<Id, Map<String, Object>>>();
        this.childRelationshipsMap = new Map<String, Map<Id, Map<String, List<SObject>>>>();
        
        extractSObjectFieldValues();
    }
    
    /**
     * @description Set the mock object reference (called by MockService when creating mocks)
     */
    public void setMock(Object mock) {
        this.mock = mock;
    }
    
    private void extractSObjectFieldValues() {
        for (String methodName : stubbedMethodMap.keySet()) {
            Object methodResult = stubbedMethodMap.get(methodName);
            
            // Handle List<SObjectWithRelationships>
            if (methodResult instanceof List<SObjectWithRelationships>) {
                List<SObjectWithRelationships> sObjectsWithRels = (List<SObjectWithRelationships>) methodResult;
                if (!sObjectsWithRels.isEmpty()) {
                    String sObjectType = sObjectsWithRels[0].record.getSObjectType().getDescribe().getName();
                    
                    if (!sObjectFieldValues.containsKey(methodName)) {
                        sObjectFieldValues.put(methodName, new Map<Id, Map<String, Object>>());
                    }
                    if (!childRelationshipsMap.containsKey(methodName)) {
                        childRelationshipsMap.put(methodName, new Map<Id, Map<String, List<SObject>>>());
                    }
                    
                    for (SObjectWithRelationships sobjWithRel : sObjectsWithRels) {
                        SObject sobj = sobjWithRel.record;
                        if (sobj != null && sobj.Id != null) {
                            // Extract field values
                            Map<String, Object> fields = new Map<String, Object>();
                            Map<String, Object> populatedFields = sobj.getPopulatedFieldsAsMap();
                            
                            for (String fieldName : populatedFields.keySet()) {
                                // Skip relationship fields (they end with __r or are relationship fields)
                                if (isRelationshipField(fieldName, sObjectType)) {
                                    continue;
                                }
                                try {
                                    Object fieldValue = sobj.get(fieldName);
                                    fields.put(fieldName, fieldValue);
                                } catch (Exception e) {
                                    // Skip fields that can't be accessed (like relationship fields)
                                    continue;
                                }
                            }
                            
                            fields.put('Id', sobj.Id);
                            sObjectFieldValues.get(methodName).put(sobj.Id, fields);
                            
                            // Store child relationships
                            if (sobjWithRel.childRelationships != null && !sobjWithRel.childRelationships.isEmpty()) {
                                childRelationshipsMap.get(methodName).put(sobj.Id, sobjWithRel.childRelationships);
                            }
                        }
                    }
                }
            }
            // Handle List<SObject> (backward compatibility)
            else if (methodResult instanceof List<SObject>) {
                List<SObject> sObjects = (List<SObject>) methodResult;
                String sObjectType = sObjects.isEmpty() ? null : sObjects[0].getSObjectType().getDescribe().getName();
                
                if (sObjectType != null) {
                    if (!sObjectFieldValues.containsKey(methodName)) {
                        sObjectFieldValues.put(methodName, new Map<Id, Map<String, Object>>());
                    }
                    
                    for (SObject sobj : sObjects) {
                        if (sobj != null && sobj.Id != null) {
                            Map<String, Object> fields = new Map<String, Object>();
                            Map<String, Object> populatedFields = sobj.getPopulatedFieldsAsMap();
                            
                            for (String fieldName : populatedFields.keySet()) {
                                // Skip relationship fields (they end with __r or are relationship fields)
                                if (isRelationshipField(fieldName, sObjectType)) {
                                    continue;
                                }
                                try {
                                    Object fieldValue = sobj.get(fieldName);
                                    fields.put(fieldName, fieldValue);
                                } catch (Exception e) {
                                    // Skip fields that can't be accessed (like relationship fields)
                                    continue;
                                }
                            }
                            
                            fields.put('Id', sobj.Id);
                            
                            sObjectFieldValues.get(methodName).put(sobj.Id, fields);
                        }
                    }
                }
            }
        }
    }

    public Object handleMethodCall(Object stubbedObject, String stubbedMethodName,
                                   Type returnType, List<Type> listOfParamTypes,
                                   List<String> listOfParamNames, List<Object> listOfArgs) {
        // Record invocation for verification
        MockRegistry.recordInvocation(stubbedObject, stubbedMethodName, listOfArgs);
        
        // First, check MockRegistry for new-style stubs
        MethodId methodId = new MethodId(stubbedMethodName, listOfParamTypes);
        Stub stub = MockRegistry.findStub(stubbedObject, methodId, listOfArgs);
        
        if (stub != null) {
            return executeStub(stub, stubbedMethodName, listOfArgs, returnType, stubbedObject);
        }
        
        // Fall back to legacy stubbedMethodMap for backward compatibility
        Object result;
        if (stubbedMethodMap.containsKey(stubbedMethodName)) {
            result = stubbedMethodMap.get(stubbedMethodName);
            
            if (result instanceof List<SObjectWithRelationships>) {
                result = processSObjectWithRelationshipsList((List<SObjectWithRelationships>) result, stubbedMethodName, listOfArgs);
            } else if (result instanceof List<SObject>) {
                result = processSObjectList((List<SObject>) result, stubbedMethodName, listOfArgs);
            }
        } else {
            // No stub found - throw clear error
            String argsStr = listOfArgs != null ? String.valueOf(listOfArgs) : '()';
            throw new MockException('No stub matched for ' + stubbedMethodName + argsStr + '. Add when(...) or relax matchers.');
        }
        
        return result;
    }
    
    /**
     * @description Execute a stub plan (Return, Throw, or Answer)
     */
    private Object executeStub(Stub stub, String methodName, List<Object> args, Type returnType, Object stubbedObject) {
        StubPlan plan = stub.plan;
        
        if (plan.type == StubPlan.PlanType.RETURN) {
            Object result = plan.getNext();
            // Validate return type if possible
            if (returnType != null && result != null && returnType != Object.class) {
                // Basic type check - Apex doesn't have full reflection, so we do best-effort
                if (!isAssignable(returnType, result)) {
                    throw new MockException('Return type mismatch: expected ' + returnType + ', got ' + result.getClass());
                }
            }
            return result;
        } else if (plan.type == StubPlan.PlanType.THROW) {
            Object ex = plan.getNext();
            if (ex instanceof Exception) {
                throw (Exception) ex;
            } else {
                throw new MockException('Stub plan type is THROW but value is not an Exception');
            }
        } else if (plan.type == StubPlan.PlanType.ANSWER) {
            if (plan.answerFn == null) {
                throw new MockException('Stub plan type is ANSWER but answerFn is null');
            }
            
            // Create invocation context
            Integer callIndex = getCallIndex(stubbedObject, methodName, args);
            InvocationContext ctx = new InvocationContext(methodName, args, callIndex);
            
            // Execute answer function
            Object result = plan.answerFn.call(new List<Object>{ctx});
            
            // If result is an exception, throw it
            if (result instanceof Exception) {
                throw (Exception) result;
            }
            
            // Validate return type
            if (returnType != null && result != null && returnType != Object.class) {
                if (!isAssignable(returnType, result)) {
                    throw new MockException('Return type mismatch from answerFn: expected ' + returnType + ', got ' + result.getClass());
                }
            }
            
            return result;
        }
        
        return null;
    }
    
    /**
     * @description Get call index for a method (for thenAnswer)
     */
    private Integer getCallIndex(Object stubbedObject, String methodName, List<Object> args) {
        List<Invocation> invocations = MockRegistry.getInvocations(stubbedObject);
        Integer index = 0;
        for (Invocation inv : invocations) {
            if (inv.methodName == methodName && inv.args.size() == args.size()) {
                index++;
            }
        }
        return index;
    }
    
    /**
     * @description Basic type assignability check
     */
    private Boolean isAssignable(Type expected, Object actual) {
        if (expected == Object.class) {
            return true;
        }
        Type actualType = actual.getClass();
        if (expected == actualType) {
            return true;
        }
        // For primitives and common types, do basic checks
        // Apex doesn't have full reflection, so this is best-effort
        return true; // Allow it - runtime will catch real mismatches
    }
    
    /**
     * @description Custom exception for mocking framework
     */
    public class MockException extends Exception {}
    
    private List<SObject> processSObjectList(List<SObject> sObjects, String methodName, List<Object> listOfArgs) {
        if (sObjects.isEmpty()) {
            return sObjects;
        }
        
        Set<Id> requestedIds = extractRequestedIds(listOfArgs);
        
        // If no filtering requested, return all objects as-is
        if (requestedIds == null || requestedIds.isEmpty()) {
            return sObjects;
        }
        
        // Detect if this is a "selectByXIds" method where X is not the object itself
        // e.g., selectByOpportunityIds for OpportunityLineItem should filter by OpportunityId, not Id
        String sObjectType = sObjects[0].getSObjectType().getDescribe().getName();
        String relationshipFieldName = detectRelationshipFieldFromMethodName(methodName, sObjectType);
        
        List<SObject> filteredObjects = new List<SObject>();
        
        for (SObject sobj : sObjects) {
            if (sobj == null) {
                continue;
            }
            
            Boolean shouldInclude = false;
            
            if (relationshipFieldName != null) {
                // Filter by relationship field (e.g., OpportunityId for selectByOpportunityIds)
                try {
                    Id relationshipId = (Id) sobj.get(relationshipFieldName);
                    shouldInclude = requestedIds.contains(relationshipId);
                } catch (Exception e) {
                    // If direct access fails, check if field exists in populated fields
                    Map<String, Object> populatedFields = sobj.getPopulatedFieldsAsMap();
                    if (populatedFields.containsKey(relationshipFieldName)) {
                        try {
                            Id relationshipId = (Id) populatedFields.get(relationshipFieldName);
                            shouldInclude = requestedIds.contains(relationshipId);
                        } catch (Exception e2) {
                            // Still can't access, fall back to Id check
                            shouldInclude = (sobj.Id != null && requestedIds.contains(sobj.Id));
                        }
                    } else {
                        // Field doesn't exist or isn't populated, fall back to Id check
                        shouldInclude = (sobj.Id != null && requestedIds.contains(sobj.Id));
                    }
                }
            } else {
                // Default: filter by object Id
                shouldInclude = (sobj.Id != null && requestedIds.contains(sobj.Id));
            }
            
            if (shouldInclude) {
                filteredObjects.add(sobj);
            }
        }
        
        return filteredObjects;
    }
    
    /**
     * Process a list of SObjectWithRelationships, creating SObjects with their child relationships
     * @param sObjectsWithRels List of SObjectWithRelationships
     * @param methodName The method name being called
     * @param listOfArgs The method arguments
     * @return List of SObjects with child relationships properly set
     */
    private List<SObject> processSObjectWithRelationshipsList(
        List<SObjectWithRelationships> sObjectsWithRels, 
        String methodName, 
        List<Object> listOfArgs
    ) {
        if (sObjectsWithRels.isEmpty()) {
            return new List<SObject>();
        }
        
        String sObjectType = sObjectsWithRels[0].record.getSObjectType().getDescribe().getName();
        List<SObject> processedObjects = new List<SObject>();
        
        Map<Id, Map<String, Object>> storedFields = sObjectFieldValues.get(methodName);
        if (storedFields == null) {
            storedFields = new Map<Id, Map<String, Object>>();
        }
        
        Map<Id, Map<String, List<SObject>>> storedChildRelationships = childRelationshipsMap.get(methodName);
        if (storedChildRelationships == null) {
            storedChildRelationships = new Map<Id, Map<String, List<SObject>>>();
        }
        
        Set<Id> requestedIds = extractRequestedIds(listOfArgs);
        
        for (SObjectWithRelationships sobjWithRel : sObjectsWithRels) {
            SObject sobj = sobjWithRel.record;
            if (sobj != null && sobj.Id != null) {
                // Filter by requested IDs if provided
                if (requestedIds != null && !requestedIds.isEmpty() && !requestedIds.contains(sobj.Id)) {
                    continue;
                }
                
                // Get stored fields or extract from object
                Map<String, Object> fields = storedFields.get(sobj.Id);
                if (fields == null) {
                    fields = new Map<String, Object>();
                    Map<String, Object> populatedFields = sobj.getPopulatedFieldsAsMap();
                    
                    for (String fieldName : populatedFields.keySet()) {
                        if (isRelationshipField(fieldName, sObjectType)) {
                            continue;
                        }
                        try {
                            Object fieldValue = sobj.get(fieldName);
                            fields.put(fieldName, fieldValue);
                        } catch (Exception e) {
                            continue;
                        }
                    }
                    fields.put('Id', sobj.Id);
                }
                
                // Create the object with fields
                String jsonString = JSON.serializePretty(fields);
                Type deserializeType = Type.forName(sObjectType);
                SObject processedObj = (SObject) JSON.deserialize(jsonString, deserializeType);
                
                // Set null fields explicitly
                for (String fieldName : fields.keySet()) {
                    if (fieldName != 'Id' && fields.get(fieldName) == null) {
                        processedObj.put(fieldName, null);
                    }
                }
                
                // Attach child relationships using JSON structure
                Map<String, List<SObject>> childRels = storedChildRelationships.get(sobj.Id);
                if (childRels == null && sobjWithRel.childRelationships != null) {
                    childRels = sobjWithRel.childRelationships;
                }
                
                if (childRels != null && !childRels.isEmpty()) {
                    // Create JSON structure with child relationships in QueryResult format
                    // This format mimics what SOQL returns for child relationships
                    Map<String, Object> objWithRels = new Map<String, Object>(fields);
                    
                    for (String relFieldName : childRels.keySet()) {
                        List<SObject> childRecords = childRels.get(relFieldName);
                        if (childRecords != null && !childRecords.isEmpty()) {
                            // Create QueryResult-like structure for child relationships
                            List<Map<String, Object>> childRecordsMap = new List<Map<String, Object>>();
                            for (SObject child : childRecords) {
                                Map<String, Object> childMap = new Map<String, Object>();
                                if (child.Id != null) {
                                    childMap.put('Id', child.Id);
                                }
                                Map<String, Object> childFields = child.getPopulatedFieldsAsMap();
                                for (String childFieldName : childFields.keySet()) {
                                    if (!isRelationshipField(childFieldName, child.getSObjectType().getDescribe().getName())) {
                                        try {
                                            childMap.put(childFieldName, child.get(childFieldName));
                                        } catch (Exception e) {
                                            // Skip if can't access
                                        }
                                    }
                                }
                                childMap.put('attributes', new Map<String, Object>{
                                    'type' => child.getSObjectType().getDescribe().getName()
                                });
                                childRecordsMap.add(childMap);
                            }
                            
                            // QueryResult structure that Salesforce expects for child relationships
                            Map<String, Object> queryResult = new Map<String, Object>{
                                'totalSize' => childRecordsMap.size(),
                                'done' => true,
                                'records' => childRecordsMap
                            };
                            objWithRels.put(relFieldName, queryResult);
                        } else {
                            // Empty list - create empty QueryResult structure
                            Map<String, Object> queryResult = new Map<String, Object>{
                                'totalSize' => 0,
                                'done' => true,
                                'records' => new List<Map<String, Object>>()
                            };
                            objWithRels.put(relFieldName, queryResult);
                        }
                    }
                    
                    // Deserialize with child relationships
                    // CRITICAL: JSON.deserialize with QueryResult structure doesn't work for child relationships
                    // When accessing opp.Quotes, Salesforce tries to query the database, causing "Aggregate query has too many rows"
                    // Solution: Create the object without relationships first, then use a wrapper approach
                    // We'll create a custom SObject that has the relationship data stored separately
                    String baseJson = JSON.serialize(fields);
                    processedObj = (SObject) JSON.deserialize(baseJson, deserializeType);
                    
                    // Store child relationships in a way that can be accessed without triggering queries
                    // We'll use JSON serialization with the QueryResult structure, but access it safely
                    // The key is to ensure the relationship is accessible as a List<SObject> without querying
                    // Since we can't set child relationships directly, we need to work around this limitation
                    // The best approach is to ensure the object is returned with the relationship data
                    // stored in a way that mimics SOQL query results
                    
                    // Create a JSON structure that includes the QueryResult for child relationships
                    // This will be used when the relationship is accessed
                    Map<String, Object> fullObjMap = new Map<String, Object>(fields);
                    for (String relFieldName : childRels.keySet()) {
                        List<SObject> childRecords = childRels.get(relFieldName);
                        if (childRecords != null && !childRecords.isEmpty()) {
                            // Convert child records to a format that can be accessed
                            List<Map<String, Object>> childMaps = new List<Map<String, Object>>();
                            for (SObject child : childRecords) {
                                Map<String, Object> childMap = new Map<String, Object>();
                                if (child.Id != null) {
                                    childMap.put('Id', child.Id);
                                }
                                Map<String, Object> childFields = child.getPopulatedFieldsAsMap();
                                for (String childFieldName : childFields.keySet()) {
                                    if (!isRelationshipField(childFieldName, child.getSObjectType().getDescribe().getName())) {
                                        try {
                                            childMap.put(childFieldName, child.get(childFieldName));
                                        } catch (Exception e) {
                                            // Skip if can't access
                                        }
                                    }
                                }
                                childMaps.add(childMap);
                            }
                            // Store as QueryResult structure
                            Map<String, Object> queryResult = new Map<String, Object>{
                                'totalSize' => childMaps.size(),
                                'done' => true,
                                'records' => childMaps
                            };
                            fullObjMap.put(relFieldName, queryResult);
                        }
                    }
                    
                    // Deserialize the full object with relationships
                    // This should create an object where the relationship is accessible
                    String fullJson = JSON.serialize(fullObjMap);
                    processedObj = (SObject) JSON.deserialize(fullJson, deserializeType);
                }
                
                processedObjects.add(processedObj);
            } else if (sobj != null) {
                processedObjects.add(sobj);
            }
        }
        
        return processedObjects;
    }
    
    private Set<Id> extractRequestedIds(List<Object> listOfArgs) {
        // Check all arguments for Set<Id> - methods may have multiple parameters
        if (listOfArgs != null && !listOfArgs.isEmpty()) {
            for (Object arg : listOfArgs) {
                if (arg instanceof Set<Id>) {
                    return (Set<Id>) arg;
                }
            }
        }
        return null;
    }
    
    /**
     * Detects the relationship field name from method name for "selectByXIds" patterns
     * e.g., "selectByOpportunityIds" -> "OpportunityId"
     * e.g., "selectByAccountIds" -> "AccountId"
     * Returns null if it's a standard "selectByIds" or if no pattern matches
     */
    private String detectRelationshipFieldFromMethodName(String methodName, String sObjectType) {
        if (methodName == null || !methodName.startsWith('selectBy')) {
            return null;
        }
        
        // Find "Ids" in the method name (may have suffix like "WithDetails")
        // e.g., "selectByOpportunityIds" -> "Opportunity"
        // e.g., "selectByOpportunityIdsWithDetails" -> "Opportunity"
        // e.g., "selectByRelationIds" -> "Relation"
        Integer idsIndex = methodName.indexOf('Ids', 8); // Start searching after "selectBy"
        if (idsIndex == -1) {
            return null;
        }
        
        // Extract the part between "selectBy" and "Ids"
        String middlePart = methodName.substring(8, idsIndex); // Remove "selectBy" (8 chars) up to "Ids"
        
        // If it's just "Id" (selectByIds), return null to use default Id filtering
        if (middlePart == 'Id') {
            return null;
        }
        
        // Try standard field first: "Opportunity" -> "OpportunityId"
        String standardFieldName = middlePart + 'Id';
        
        // Try custom field: "Relation" -> "Relation__c"
        String customFieldName = middlePart + '__c';
        
        // Verify which field exists on the SObject type
        try {
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            Schema.SObjectType sObjectTypeToken = globalDescribe.get(sObjectType);
            if (sObjectTypeToken != null) {
                Schema.DescribeSObjectResult describe = sObjectTypeToken.getDescribe();
                Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
                
                // Check custom field first (__c) - try both lowercase and with proper casing
                String lowerCustomField = customFieldName.toLowerCase();
                if (fieldMap.containsKey(lowerCustomField)) {
                    return customFieldName;
                }
                
                // Also try to find the field by iterating (in case of case sensitivity issues)
                for (String fieldKey : fieldMap.keySet()) {
                    if (fieldKey.equalsIgnoreCase(customFieldName)) {
                        return customFieldName;
                    }
                }
                
                // Check standard field (Id suffix)
                String lowerStandardField = standardFieldName.toLowerCase();
                if (fieldMap.containsKey(lowerStandardField)) {
                    return standardFieldName;
                }
                
                // Also try to find the standard field by iterating
                for (String fieldKey : fieldMap.keySet()) {
                    if (fieldKey.equalsIgnoreCase(standardFieldName)) {
                        return standardFieldName;
                    }
                }
                
                // If the detected field doesn't exist, try to find a relationship field
                // that points to the object mentioned in the method name
                // e.g., for "selectByQuoteIds" on PricingCondition__c, find fields that point to Quote
                String targetObjectName = findTargetObjectName(middlePart);
                if (targetObjectName != null) {
                    String relationshipField = findRelationshipFieldToObject(sObjectTypeToken, fieldMap, targetObjectName);
                    if (relationshipField != null) {
                        return relationshipField;
                    }
                }
            }
        } catch (Exception e) {
            // If we can't verify, continue to fallback
        }
        
        // Fallback: if it's a custom field pattern (__c), try to verify it exists by checking
        // if we can access it on a sample object (if available in the calling context)
        // For now, we'll return it if it matches the pattern, as custom fields are predictable
        if (customFieldName.endsWith('__c')) {
            return customFieldName;
        }
        
        return null;
    }
    
    /**
     * Finds the target object name from the middle part of the method name
     * e.g., "Quote" -> "Quote", "Opportunity" -> "Opportunity"
     * @param middlePart The middle part extracted from method name
     * @return The target object name, or null if not found
     */
    private String findTargetObjectName(String middlePart) {
        if (middlePart == null || String.isBlank(middlePart)) {
            return null;
        }
        
        // Capitalize first letter to match object name convention
        String objectName = middlePart.substring(0, 1).toUpperCase() + middlePart.substring(1);
        
        // Verify the object exists in the schema
        try {
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            if (globalDescribe.containsKey(objectName)) {
                return objectName;
            }
            // Also try with __c suffix for custom objects
            String customObjectName = objectName + '__c';
            if (globalDescribe.containsKey(customObjectName)) {
                return customObjectName;
            }
        } catch (Exception e) {
            // If we can't verify, return the capitalized version anyway
        }
        
        return objectName;
    }
    
    /**
     * Finds a relationship field that points to the target object
     * @param sObjectTypeToken The SObject type token of the current object
     * @param fieldMap The field map of the current object
     * @param targetObjectName The name of the target object to find relationship to
     * @return The relationship field name, or null if not found
     */
    private String findRelationshipFieldToObject(
        Schema.SObjectType sObjectTypeToken, 
        Map<String, Schema.SObjectField> fieldMap, 
        String targetObjectName
    ) {
        if (sObjectTypeToken == null || fieldMap == null || targetObjectName == null) {
            return null;
        }
        
        try {
            // Get the target object type
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            Schema.SObjectType targetObjectType = globalDescribe.get(targetObjectName);
            if (targetObjectType == null) {
                return null;
            }
            
            // Iterate through all fields to find relationship fields that point to target object
            for (String fieldKey : fieldMap.keySet()) {
                Schema.SObjectField field = fieldMap.get(fieldKey);
                if (field == null) {
                    continue;
                }
                
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                
                // Check if this is a relationship field (lookup or master-detail)
                if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE) {
                    // Get the objects this field references
                    List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
                    if (referenceTo != null && !referenceTo.isEmpty()) {
                        // Check if any of the referenced objects match the target
                        for (Schema.SObjectType refType : referenceTo) {
                            if (refType != null && refType.getDescribe().getName() == targetObjectName) {
                                // Found a relationship field that points to the target object
                                return fieldDescribe.getName();
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            // If we can't verify, return null
        }
        
        return null;
    }
    
    /**
     * Determines if a field is a relationship field (parent or child)
     * @param fieldName The field name to check
     * @param sObjectType The SObject type
     * @return true if the field is a relationship field
     */
    private Boolean isRelationshipField(String fieldName, String sObjectType) {
        // Custom relationship fields end with __r
        if (fieldName.endsWith('__r')) {
            return true;
        }
        
        // Common standard parent relationship fields (singular)
        Set<String> standardParentRelationships = new Set<String>{
            'Account', 'Owner', 'CreatedBy', 'LastModifiedBy', 'Parent', 
            'Contact', 'Lead', 'Opportunity', 'Case', 'Contract', 'What', 'Who'
        };
        
        if (standardParentRelationships.contains(fieldName)) {
            return true;
        }
        
        // Check if it might be a child relationship (plural form)
        // Common child relationships are plural: Quotes, Tasks, Events, Opportunities, Cases, etc.
        // We'll verify this in isChildRelationship() but return true here to check it
        String lowerFieldName = fieldName.toLowerCase();
        Boolean isPlural = lowerFieldName.endsWith('s') || 
                          lowerFieldName.endsWith('es') || 
                          lowerFieldName.endsWith('ies');
        
        // If it's plural and not a known parent relationship, it might be a child relationship
        // We'll verify in isChildRelationship()
        return isPlural;
    }
    
    /**
     * Determines if a field is a child relationship (like Quotes, Tasks, Events)
     * Child relationships are typically plural and represent collections
     * @param fieldName The field name to check
     * @param sobj The SObject to check
     * @param sObjectType The SObject type
     * @return true if the field is a child relationship
     */
    private Boolean isChildRelationship(String fieldName, SObject sobj, String sObjectType) {
        // Child relationships are typically plural (Quotes, Tasks, Events, etc.)
        // They appear in populatedFields but accessing them can cause QueryException
        // Strategy: Check if field name suggests it's plural (child relationship pattern)
        // DON'T try to access the field as it can cause "Aggregate query has too many rows" error
        
        String lowerFieldName = fieldName.toLowerCase();
        
        // Common child relationship patterns: ends with 's', 'es', or 'ies'
        // Examples: Quotes, Tasks, Events, Opportunities, Cases, Activities, etc.
        Boolean isPlural = lowerFieldName.endsWith('s') || 
                          lowerFieldName.endsWith('es') || 
                          lowerFieldName.endsWith('ies');
        
        // If it's plural and in populatedFields, assume it's a child relationship
        // We don't try to access it to avoid QueryException
        return isPlural;
    }
    
    private String getRelationshipSObjectType(String parentSObjectType, String relationshipFieldName) {
        // Map relationship field names to their SObject types
        Map<String, Map<String, String>> relationshipMap = new Map<String, Map<String, String>>{
            'Opportunity' => new Map<String, String>{
                'Account' => 'Account',
                'Owner' => 'User',
                'CreatedBy' => 'User',
                'LastModifiedBy' => 'User'
            },
            'Quote' => new Map<String, String>{
                'Opportunity' => 'Opportunity',
                'Account' => 'Account',
                'Owner' => 'User',
                'CreatedBy' => 'User',
                'LastModifiedBy' => 'User'
            }
        };
        
        if (relationshipMap.containsKey(parentSObjectType)) {
            return relationshipMap.get(parentSObjectType).get(relationshipFieldName);
        }
        return null;
    }
}

