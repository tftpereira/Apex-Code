/**
 * @description       : Interface for UnitOfWork pattern to abstract DML operations
 * @author            : 
 * @group             : 
 * @last modified on  : 
 * @last modified by  : 
**/
public interface IUnitOfWork {
    void registerNew(SObject record);
    void registerNew(List<SObject> records);
    void registerDirty(SObject record);
    void registerDirty(List<SObject> records);
    void registerDeleted(SObject record);
    void registerDeleted(List<SObject> records);
    void registerPublishAfterSuccessTransaction(SObject eventRecord);
    void commitWork();
}

