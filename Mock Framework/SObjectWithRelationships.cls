/**
 * @description Wrapper class to represent an SObject with its child relationships
 * This allows specifying which child records should be associated with a parent object in mocks
 */
@isTest
public class SObjectWithRelationships {
    public SObject record;
    public Map<String, List<SObject>> childRelationships;
    
    /**
     * Constructor for SObject with child relationships
     * @param record The parent SObject
     * @param childRelationships Map of relationship field name to list of child records
     *                          Example: new Map<String, List<SObject>>{'Quotes' => quoteList}
     */
    public SObjectWithRelationships(SObject record, Map<String, List<SObject>> childRelationships) {
        this.record = record;
        this.childRelationships = childRelationships != null ? childRelationships : new Map<String, List<SObject>>();
    }
    
    /**
     * Constructor for SObject without child relationships
     * @param record The SObject
     */
    public SObjectWithRelationships(SObject record) {
        this(record, null);
    }
    
    /**
     * Helper method to create an SObject with a single child relationship
     * @param record The parent SObject
     * @param relationshipFieldName The name of the child relationship field (e.g., 'Quotes')
     * @param childRecords List of child records
     * @return SObjectWithRelationships instance
     */
    public static SObjectWithRelationships withChildRelationship(
        SObject record, 
        String relationshipFieldName, 
        List<SObject> childRecords
    ) {
        Map<String, List<SObject>> relationships = new Map<String, List<SObject>>{
            relationshipFieldName => childRecords != null ? childRecords : new List<SObject>()
        };
        return new SObjectWithRelationships(record, relationships);
    }
    
    /**
     * Helper method to create an SObject with multiple child relationships
     * @param record The parent SObject
     * @param relationshipFieldName1 First relationship field name
     * @param childRecords1 First list of child records
     * @param relationshipFieldName2 Second relationship field name
     * @param childRecords2 Second list of child records
     * @return SObjectWithRelationships instance
     */
    public static SObjectWithRelationships withChildRelationships(
        SObject record,
        String relationshipFieldName1,
        List<SObject> childRecords1,
        String relationshipFieldName2,
        List<SObject> childRecords2
    ) {
        Map<String, List<SObject>> relationships = new Map<String, List<SObject>>{
            relationshipFieldName1 => childRecords1 != null ? childRecords1 : new List<SObject>(),
            relationshipFieldName2 => childRecords2 != null ? childRecords2 : new List<SObject>()
        };
        return new SObjectWithRelationships(record, relationships);
    }
}

