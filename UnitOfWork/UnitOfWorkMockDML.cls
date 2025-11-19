/**
 * @description       : Mock DML implementation for UnitOfWork testing
 * @author            : 
 * @group             : 
 * @last modified on  : 
 * @last modified by  : 
**/
@IsTest
public class UnitOfWorkMockDML implements UnitOfWork.IDML {
    public List<SObject> recordsForInsert = new List<SObject>();
    public List<SObject> recordsForUpdate = new List<SObject>();
    public List<SObject> recordsForDelete = new List<SObject>();
    public List<SObject> recordsForRecycleBin = new List<SObject>();
    public List<SObject> recordsForEventPublish = new List<SObject>();

    public void dmlInsert(List<SObject> objList) { 
        if (objList != null) {
            this.recordsForInsert.addAll(objList); 
        }
    }
    
    public void dmlUpdate(List<SObject> objList) { 
        if (objList != null) {
            this.recordsForUpdate.addAll(objList); 
        }
    }
    
    public void dmlDelete(List<SObject> objList) { 
        system.debug(objList);
        if (objList != null) {
            this.recordsForDelete.addAll(objList); 
        }
    }
    
    public void eventPublish(List<SObject> objList) { 
        if (objList != null) {
            this.recordsForEventPublish.addAll(objList); 
        }
    }
    
    public void emptyRecycleBin(List<SObject> objList) { 
        if (objList != null) {
            this.recordsForRecycleBin.addAll(objList); 
        }
    }
}

