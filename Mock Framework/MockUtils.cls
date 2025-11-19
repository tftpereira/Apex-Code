/**
 * @description       : Utility class for test mocks and helper methods
 * @author            : 
 * @group             : 
 * @last modified on  : 
 * @last modified by  : 
**/
@isTest
public class MockUtils {
    
    // Counter for generating unique fake IDs
    private static Integer s_num = 1;
    
    /**
     * Generates a fake ID for a given SObject type (following fflib pattern)
     * @param sObjectType The SObject type to generate an ID for
     * @return A fake Id with the correct key prefix
     */
    public static Id getFakeId(Schema.SObjectType sObjectType) {
        String keyPrefix = sObjectType.getDescribe().getKeyPrefix();
        String uniqueNumber = String.valueOf(s_num++);
        String uniqueId = keyPrefix + 
            '0'.repeat(12 - uniqueNumber.length()) + 
            uniqueNumber;
        return Id.valueOf(uniqueId);
    }
    
    /**
     * Sets read-only fields on an SObject using JSON serialization (following fflib pattern)
     * This allows setting values on fields that are normally read-only in tests
     * @param record The SObject to modify
     * @param fieldValues Map of SObjectField to Object values to set
     * @return The modified SObject
     */
    public static SObject setReadOnlyFields(SObject record, Map<Schema.SObjectField, Object> fieldValues) {
        if (fieldValues == null || fieldValues.isEmpty()) {
            return record;
        }
        
        Map<String, Object> fieldNameMap = new Map<String, Object>();
        for (Schema.SObjectField field : fieldValues.keySet()) {
            fieldNameMap.put(field.getDescribe().getName(), fieldValues.get(field));
        }
        
        Type deserializeType = Type.forName(record.getSObjectType().getDescribe().getName());
        return (SObject) setReadOnlyFields(record, deserializeType, fieldNameMap);
    }
    
    /**
     * Helper method to set read-only fields using JSON serialization
     * @param objInstance The SObject instance to modify
     * @param deserializeType The Type to deserialize to
     * @param properties Map of field names to values
     * @return The modified SObject
     */
    private static Object setReadOnlyFields(SObject objInstance, Type deserializeType, Map<String, Object> properties) {
        if (properties == null || properties.isEmpty()) {
            return objInstance;
        }
        
        Map<String, Object> mergedMap = new Map<String, Object>();
        if (objInstance != null) {
            Map<String, Object> populatedFields = objInstance.getPopulatedFieldsAsMap();
            if (populatedFields != null && !populatedFields.isEmpty()) {
                mergedMap.putAll(populatedFields);
            }
        }
        mergedMap.putAll(properties);
        
        if (mergedMap.isEmpty()) {
            return objInstance;
        }
        
        String jsonString = JSON.serializePretty(mergedMap);
        return (SObject) JSON.deserialize(jsonString, deserializeType);
    }
    
    /**
     * Overload to set a single read-only field
     * @param record The SObject to modify
     * @param field The SObjectField to set
     * @param value The value to set
     * @return The modified SObject
     */
    public static SObject setReadOnlyField(SObject record, Schema.SObjectField field, Object value) {
        Map<Schema.SObjectField, Object> fieldValues = new Map<Schema.SObjectField, Object>{field => value};
        return setReadOnlyFields(record, fieldValues);
    }
}

