/**
 * Standalone UnitOfWork implementation (no fflib dependency)
 *
 * Features:
 *  - Bulkified DML for insert/update/delete
 *  - Dependency-aware relationship resolution (including external ID lookups)
 *  - Platform Event publish phases (before, after success, after failure)
 *  - Generic work execution and queued email sending
 *  - Pluggable DML strategy (default system mode or user mode)
 */
public virtual class UnitOfWork implements IUnitOfWork {
    // Tracked SObject types (dependency order: least dependent first)
    protected List<Schema.SObjectType> sObjectTypes;

    // Work queues by type
    protected Map<String, List<SObject>> newListByType = new Map<String, List<SObject>>();
    protected Map<String, Map<Id, SObject>> dirtyMapByType = new Map<String, Map<Id, SObject>>();
    protected Map<String, Map<Id, SObject>> deletedMapByType = new Map<String, Map<Id, SObject>>();
    protected Map<String, Map<Id, SObject>> emptyRecycleBinMapByType = new Map<String, Map<Id, SObject>>();

    // Relationships to resolve per type and for email
    protected Map<String, Relationships> relationshipsByType = new Map<String, Relationships>();

    // Platform event publish queues
    protected Map<String, List<SObject>> publishBeforeListByType = new Map<String, List<SObject>>();
    protected Map<String, List<SObject>> publishAfterSuccessListByType = new Map<String, List<SObject>>();
    protected Map<String, List<SObject>> publishAfterFailureListByType = new Map<String, List<SObject>>();

    // Arbitrary work items (executed after DML)
    protected List<IDoWork> workList = new List<IDoWork>();
    @TestVisible protected IEmailWork emailWork = new SendEmailWork();

    // DML strategy
    protected IDML dml;

    // ---------- Interfaces ----------
    public interface IDoWork {
        void doWork();
    }

    public interface IDML {
        void dmlInsert(List<SObject> records);
        void dmlUpdate(List<SObject> records);
        void dmlDelete(List<SObject> records);
        void eventPublish(List<SObject> eventRecords);
        void emptyRecycleBin(List<SObject> deletedRecords);
    }

    public virtual class SimpleDML implements IDML {
        public virtual void dmlInsert(List<SObject> records) {
            if (records == null || records.isEmpty()) return;
            insert records;
        }
        public virtual void dmlUpdate(List<SObject> records) {
            if (records == null || records.isEmpty()) return;
            update records;
        }
        public virtual void dmlDelete(List<SObject> records) {
            if (records == null || records.isEmpty()) return;
            delete records;
        }
        public virtual void eventPublish(List<SObject> eventRecords) {
            if (eventRecords == null || eventRecords.isEmpty()) return;
            EventBus.publish(eventRecords);
        }
        public virtual void emptyRecycleBin(List<SObject> deletedRecords) {
            if (deletedRecords == null || deletedRecords.isEmpty()) return;
            Database.emptyRecycleBin(deletedRecords);
        }
    }

    public virtual class UserModeDML extends SimpleDML {
        @TestVisible private System.AccessLevel accessLevel;
        public UserModeDML() {
            this(System.AccessLevel.USER_MODE);
        }
        public UserModeDML(System.AccessLevel level) {
            accessLevel = level;
        }
        public override void dmlInsert(List<SObject> records) {
            if (records == null || records.isEmpty()) return;
            Database.insert(records, accessLevel);
        }
        public override void dmlUpdate(List<SObject> records) {
            if (records == null || records.isEmpty()) return;
            Database.update(records, accessLevel);
        }
        public override void dmlDelete(List<SObject> records) {
            if (records == null || records.isEmpty()) return;
            Database.delete(records, accessLevel);
        }
    }

    // ---------- Construction ----------
    public UnitOfWork(List<Schema.SObjectType> types) {
        this(types, new SimpleDML());
    }
    public UnitOfWork(List<Schema.SObjectType> types, IDML dmlStrategy) {
        sObjectTypes = types == null ? new List<Schema.SObjectType>() : types.clone();
        for (Schema.SObjectType t : sObjectTypes) {
            registerTypeInternal(t);
        }
        relationshipsByType.put(Messaging.SingleEmailMessage.class.getName(), new Relationships());
        dml = dmlStrategy == null ? new SimpleDML() : dmlStrategy;
    }

    // ---------- Hooks (override in subclasses) ----------
    public virtual void onRegisterType(Schema.SObjectType sObjectType) {}
    public virtual void onCommitWorkStarting() {}
    public virtual void onPublishBeforeEventsStarting() {}
    public virtual void onPublishBeforeEventsFinished() {}
    public virtual void onDMLStarting() {}
    public virtual void onDMLFinished() {}
    public virtual void onDoWorkStarting() {}
    public virtual void onDoWorkFinished() {}
    public virtual void onPublishAfterSuccessEventsStarting() {}
    public virtual void onPublishAfterSuccessEventsFinished() {}
    public virtual void onPublishAfterFailureEventsStarting() {}
    public virtual void onPublishAfterFailureEventsFinished() {}
    public virtual void onCommitWorkFinishing() {}
    public virtual void onCommitWorkFinished(Boolean wasSuccessful) {}

    // ---------- Public API ----------
    public void registerWork(IDoWork work) {
        if (work == null) return;
        workList.add(work);
    }

    public void registerEmail(Messaging.Email email) {
        emailWork.registerEmail(email);
    }

    public void registerEmptyRecycleBin(SObject record) {
        if (record == null) return;
        String typeName = record.getSObjectType().getDescribe().getName();
        assertForSupportedSObjectType(emptyRecycleBinMapByType, typeName);
        emptyRecycleBinMapByType.get(typeName).put(record.Id, record);
    }
    public void registerEmptyRecycleBin(List<SObject> records) {
        if (records == null) return;
        for (SObject r : records) registerEmptyRecycleBin(r);
    }

    public void registerNew(SObject record) {
        registerNew(record, null, null);
    }
    public void registerNew(List<SObject> records) {
        if (records == null) return;
        for (SObject r : records) registerNew(r, null, null);
    }
    public void registerNew(SObject record, Schema.SObjectField relatedToParentField, SObject relatedToParent) {
        if (record == null) return;
        if (record.Id != null) throw new UnitOfWorkException('Only new records can be registered as new');
        String typeName = record.getSObjectType().getDescribe().getName();
        assertForNonEventSObjectType(typeName);
        assertForSupportedSObjectType(newListByType, typeName);
        newListByType.get(typeName).add(record);
        if (relatedToParentField != null && relatedToParent != null) {
            registerRelationship(record, relatedToParentField, relatedToParent);
        }
    }

    public void registerRelationship(SObject record, Schema.SObjectField relatedToField, SObject relatedTo) {
        if (record == null || relatedToField == null || relatedTo == null) return;
        String typeName = record.getSObjectType().getDescribe().getName();
        assertForNonEventSObjectType(typeName);
        assertForSupportedSObjectType(newListByType, typeName);
        relationshipsByType.get(typeName).add(record, relatedToField, relatedTo);
    }

    public void registerRelationship(Messaging.SingleEmailMessage email, SObject relatedTo) {
        if (email == null || relatedTo == null) return;
        relationshipsByType.get(Messaging.SingleEmailMessage.class.getName()).add(email, relatedTo);
    }

    public void registerRelationship(SObject record, Schema.SObjectField relatedToField, Schema.SObjectField externalIdField, Object externalId) {
        if (record == null || relatedToField == null || externalIdField == null) return;
        String typeName = record.getSObjectType().getDescribe().getName();
        assertForSupportedSObjectType(newListByType, typeName);
        relationshipsByType.get(typeName).add(record, relatedToField, externalIdField, externalId);
    }

    public void registerDirty(SObject record) {
        registerDirty(record, new List<Schema.SObjectField>());
    }
    public void registerDirty(List<SObject> records) {
        if (records == null) return;
        for (SObject r : records) registerDirty(r);
    }
    public void registerDirty(List<SObject> records, List<Schema.SObjectField> dirtyFields) {
        if (records == null) return;
        for (SObject r : records) registerDirty(r, dirtyFields);
    }
    public void registerDirty(SObject record, List<Schema.SObjectField> dirtyFields) {
        if (record == null) return;
        if (record.Id == null) throw new UnitOfWorkException('New records cannot be registered as dirty');
        String typeName = record.getSObjectType().getDescribe().getName();
        assertForNonEventSObjectType(typeName);
        assertForSupportedSObjectType(dirtyMapByType, typeName);
        if (!dirtyMapByType.get(typeName).containsKey(record.Id) || dirtyFields == null || dirtyFields.isEmpty()) {
            dirtyMapByType.get(typeName).put(record.Id, record);
        } else {
            SObject registered = dirtyMapByType.get(typeName).get(record.Id);
            for (Schema.SObjectField f : dirtyFields) {
                registered.put(f, record.get(f));
            }
            dirtyMapByType.get(typeName).put(record.Id, registered);
        }
    }
    public void registerDirty(SObject record, Schema.SObjectField relatedToParentField, SObject relatedToParent) {
        registerDirty(record);
        if (relatedToParentField != null && relatedToParent != null) {
            registerRelationship(record, relatedToParentField, relatedToParent);
        }
    }

    public void registerDeleted(SObject record) {
        if (record == null) return;
        if (record.Id == null) throw new UnitOfWorkException('New records cannot be registered for deletion');
        String typeName = record.getSObjectType().getDescribe().getName();
        assertForNonEventSObjectType(typeName);
        assertForSupportedSObjectType(deletedMapByType, typeName);
        deletedMapByType.get(typeName).put(record.Id, record);
    }
    public void registerDeleted(List<SObject> records) {
        if (records == null) return;
        for (SObject r : records) registerDeleted(r);
    }

    public void registerPermanentlyDeleted(SObject record) {
        registerEmptyRecycleBin(record);
        registerDeleted(record);
    }
    public void registerPermanentlyDeleted(List<SObject> records) {
        if (records == null) return;
        registerEmptyRecycleBin(records);
        registerDeleted(records);
    }

    public void registerUpsert(SObject record) {
        if (record == null) return;
        if (record.Id == null) registerNew(record);
        else registerDirty(record);
    }
    public void registerUpsert(List<SObject> records) {
        if (records == null) return;
        for (SObject r : records) registerUpsert(r);
    }

    public void registerPublishBeforeTransaction(SObject eventRecord) {
        if (eventRecord == null) return;
        String typeName = eventRecord.getSObjectType().getDescribe().getName();
        assertForEventSObjectType(typeName);
        assertForSupportedSObjectType(publishBeforeListByType, typeName);
        publishBeforeListByType.get(typeName).add(eventRecord);
    }
    public void registerPublishBeforeTransaction(List<SObject> eventRecords) {
        if (eventRecords == null) return;
        for (SObject r : eventRecords) registerPublishBeforeTransaction(r);
    }

    public void registerPublishAfterSuccessTransaction(SObject eventRecord) {
        if (eventRecord == null) return;
        String typeName = eventRecord.getSObjectType().getDescribe().getName();
        assertForEventSObjectType(typeName);
        assertForSupportedSObjectType(publishAfterSuccessListByType, typeName);
        publishAfterSuccessListByType.get(typeName).add(eventRecord);
    }
    public void registerPublishAfterSuccessTransaction(List<SObject> eventRecords) {
        if (eventRecords == null) return;
        for (SObject r : eventRecords) registerPublishAfterSuccessTransaction(r);
    }

    public void registerPublishAfterFailureTransaction(SObject eventRecord) {
        if (eventRecord == null) return;
        String typeName = eventRecord.getSObjectType().getDescribe().getName();
        assertForEventSObjectType(typeName);
        assertForSupportedSObjectType(publishAfterFailureListByType, typeName);
        publishAfterFailureListByType.get(typeName).add(eventRecord);
    }
    public void registerPublishAfterFailureTransaction(List<SObject> eventRecords) {
        if (eventRecords == null) return;
        for (SObject r : eventRecords) registerPublishAfterFailureTransaction(r);
    }

    // ---------- Accessors (read staged data) ----------
    public List<SObject> getRegisteredNew(String typeName) {
        assertForSupportedSObjectType(newListByType, typeName);
        return newListByType.get(typeName).clone();
    }
    public List<SObject> getRegisteredNew(Schema.SObjectType typeRef) {
        return getRegisteredNew(typeRef.getDescribe().getName());
    }

    public List<SObject> getRegisteredDirty(String typeName) {
        assertForSupportedSObjectType(dirtyMapByType, typeName);
        return new List<SObject>(dirtyMapByType.get(typeName).values());
    }
    public List<SObject> getRegisteredDirty(Schema.SObjectType typeRef) {
        return getRegisteredDirty(typeRef.getDescribe().getName());
    }

    public List<SObject> getRegisteredDeleted(String typeName) {
        assertForSupportedSObjectType(deletedMapByType, typeName);
        return new List<SObject>(deletedMapByType.get(typeName).values());
    }
    public List<SObject> getRegisteredDeleted(Schema.SObjectType typeRef) {
        return getRegisteredDeleted(typeRef.getDescribe().getName());
    }

    public SObject tryGetDirtyById(String typeName, Id id) {
        assertForSupportedSObjectType(dirtyMapByType, typeName);
        return dirtyMapByType.get(typeName).get(id);
    }
    public SObject tryGetDirtyById(Schema.SObjectType typeRef, Id id) {
        return tryGetDirtyById(typeRef.getDescribe().getName(), id);
    }

    // ---------- Commit ----------
    public void commitWork() {
        Savepoint sp = Database.setSavepoint();
        Boolean wasSuccessful = false;
        try {
            doCommitWork();
            wasSuccessful = true;
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        } finally {
            doAfterCommitWorkSteps(wasSuccessful);
        }
    }

    private void doCommitWork() {
        onCommitWorkStarting();
        onPublishBeforeEventsStarting();
        publishBeforeEventsStarting();
        onPublishBeforeEventsFinished();

        onDMLStarting();
        insertDmlByType();
        updateDmlByType();
        deleteDmlByType();
        emptyRecycleBinByType();
        resolveEmailRelationships();
        onDMLFinished();

        onDoWorkStarting();
        doWork();
        onDoWorkFinished();
        onCommitWorkFinishing();
    }

    private void doAfterCommitWorkSteps(Boolean wasSuccessful) {
        if (wasSuccessful) {
            onPublishAfterSuccessEventsStarting();
            publishAfterSuccessEvents();
            onPublishAfterSuccessEventsFinished();
        } else {
            onPublishAfterFailureEventsStarting();
            publishAfterFailureEvents();
            onPublishAfterFailureEventsFinished();
        }
        onCommitWorkFinished(wasSuccessful);
    }

    private void publishBeforeEventsStarting() {
        for (Schema.SObjectType t : sObjectTypes) {
            dml.eventPublish(publishBeforeListByType.get(t.getDescribe().getName()));
        }
    }
    private void insertDmlByType() {
        for (Schema.SObjectType t : sObjectTypes) {
            relationshipsByType.get(t.getDescribe().getName()).resolve();
            dml.dmlInsert(newListByType.get(t.getDescribe().getName()));
        }
    }
    private void updateDmlByType() {
        for (Schema.SObjectType t : sObjectTypes) {
            dml.dmlUpdate(dirtyMapByType.get(t.getDescribe().getName()).values());
        }
    }
    private void deleteDmlByType() {
        Integer idx = sObjectTypes.size() - 1;
        while (idx >= 0) {
            dml.dmlDelete(deletedMapByType.get(sObjectTypes[idx--].getDescribe().getName()).values());
        }
    }
    private void emptyRecycleBinByType() {
        Integer idx = sObjectTypes.size() - 1;
        while (idx >= 0) {
            dml.emptyRecycleBin(emptyRecycleBinMapByType.get(sObjectTypes[idx--].getDescribe().getName()).values());
        }
    }
    private void resolveEmailRelationships() {
        relationshipsByType.get(Messaging.SingleEmailMessage.class.getName()).resolve();
    }
    private void doWork() {
        workList.add(emailWork);
        for (IDoWork w : workList) w.doWork();
    }
    private void publishAfterSuccessEvents() {
        for (Schema.SObjectType t : sObjectTypes) {
            dml.eventPublish(publishAfterSuccessListByType.get(t.getDescribe().getName()));
        }
    }
    private void publishAfterFailureEvents() {
        for (Schema.SObjectType t : sObjectTypes) {
            dml.eventPublish(publishAfterFailureListByType.get(t.getDescribe().getName()));
        }
    }

    // ---------- Assertions & helpers ----------
    @TestVisible private void assertForNonEventSObjectType(String typeName) {
        if (typeName != null && typeName.length() > 3 && typeName.right(3) == '__e') {
            throw new UnitOfWorkException('Use registerPublish* methods for platform events');
        }
    }
    @TestVisible private void assertForEventSObjectType(String typeName) {
        if (typeName != null && typeName.length() > 3 && typeName.right(3) != '__e') {
            throw new UnitOfWorkException('Provided SObject type is not a platform event');
        }
    }
    @TestVisible private void assertForSupportedSObjectType(Map<String, Object> mapByType, String typeName) {
        if (String.isBlank(typeName) || !mapByType.containsKey(typeName)) {
            throw new UnitOfWorkException('SObject type ' + typeName + ' is not supported by this unit of work');
        }
    }

    private void registerTypeInternal(Schema.SObjectType sObjectType) {
        String name = sObjectType.getDescribe().getName();
        newListByType.put(name, new List<SObject>());
        dirtyMapByType.put(name, new Map<Id, SObject>());
        deletedMapByType.put(name, new Map<Id, SObject>());
        emptyRecycleBinMapByType.put(name, new Map<Id, SObject>());
        relationshipsByType.put(name, new Relationships());
        publishBeforeListByType.put(name, new List<SObject>());
        publishAfterSuccessListByType.put(name, new List<SObject>());
        publishAfterFailureListByType.put(name, new List<SObject>());
        onRegisterType(sObjectType);
    }

    // ---------- Relationships ----------
    private class Relationships {
        private List<IRelationship> relationships = new List<IRelationship>();
        public void resolve() {
            for (IRelationship r : relationships) r.resolve();
        }
        public void add(SObject record, Schema.SObjectField relatedToField, Schema.SObjectField externalIdField, Object externalId) {
            if (relatedToField == null) throw new UnitOfWorkException('Invalid argument: relatedToField');
            String relationshipName = relatedToField.getDescribe().getRelationshipName();
            if (String.isBlank(relationshipName)) throw new UnitOfWorkException('relatedToField is not a relationship field');
            List<Schema.SObjectType> relatedList = relatedToField.getDescribe().getReferenceTo();
            Schema.SObjectType relatedType = relatedList[0];

            String externalIdFieldName = externalIdField.getDescribe().getName();
            Boolean relatedHasField = relatedType.getDescribe().fields.getMap().keySet().contains(externalIdFieldName.toLowerCase());
            Boolean isExternalId = externalIdField.getDescribe().isExternalId();
            if (!relatedHasField) throw new UnitOfWorkException('externalIdField is not a field on the target sObject');
            if (!isExternalId) throw new UnitOfWorkException('externalIdField is not marked External Id');

            RelationshipByExternalId r = new RelationshipByExternalId();
            r.record = record;
            r.relatedToField = relatedToField;
            r.relatedTo = relatedType;
            r.relationshipName = relationshipName;
            r.externalIdField = externalIdField;
            r.externalId = externalId;
            relationships.add(r);
        }
        public void add(SObject record, Schema.SObjectField relatedToField, SObject relatedTo) {
            Relationship r = new Relationship();
            r.record = record;
            r.relatedToField = relatedToField;
            r.relatedTo = relatedTo;
            relationships.add(r);
        }
        public void add(Messaging.SingleEmailMessage email, SObject relatedTo) {
            EmailRelationship r = new EmailRelationship();
            r.email = email;
            r.relatedTo = relatedTo;
            relationships.add(r);
        }
    }

    private interface IRelationship { void resolve(); }

    private class RelationshipByExternalId implements IRelationship {
        public SObject record;
        public Schema.SObjectField relatedToField;
        public Schema.SObjectType relatedTo;
        public String relationshipName;
        public Schema.SObjectField externalIdField;
        public Object externalId;
        public void resolve() {
            SObject lookup = relatedTo.newSObject();
            lookup.put(externalIdField.getDescribe().getName(), externalId);
            record.putSObject(relationshipName, lookup);
        }
    }

    private class Relationship implements IRelationship {
        public SObject record;
        public Schema.SObjectField relatedToField;
        public SObject relatedTo;
        public void resolve() {
            record.put(relatedToField, relatedTo.Id);
        }
    }

    private class EmailRelationship implements IRelationship {
        public Messaging.SingleEmailMessage email;
        public SObject relatedTo;
        public void resolve() {
            email.setWhatId(relatedTo.Id);
        }
    }

    // ---------- Email Work ----------
    public class UnitOfWorkException extends Exception {}

    public interface IEmailWork extends IDoWork {
        void registerEmail(Messaging.Email email);
    }

    private class SendEmailWork implements IEmailWork {
        private List<Messaging.Email> emails = new List<Messaging.Email>();
        public void registerEmail(Messaging.Email email) {
            if (email == null) return;
            emails.add(email);
        }
        public void doWork() {
            if (!emails.isEmpty()) Messaging.sendEmail(emails);
        }
    }
}


