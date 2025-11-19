@IsTest
private with sharing class UnitOfWorkSimpleDMLTest {

	@IsTest
	private static void testSimpleDML_InsertUpdateDelete_And_EmptyRecycleBin() {
		UnitOfWork.SimpleDML dml = new UnitOfWork.SimpleDML();

		// Insert
		Account a = new Account(Name = 'SIMPLE DML');
		dml.dmlInsert(new List<SObject>{ a });
		System.assertNotEquals(null, a.Id);

		// Update
		Account aChanges = new Account(Id = a.Id, Name = 'SIMPLE DML UPDATED');
		dml.dmlUpdate(new List<SObject>{ aChanges });
		Account aDb = [SELECT Id, Name FROM Account WHERE Id = :a.Id];
		System.assertEquals('SIMPLE DML UPDATED', aDb.Name);

		// Delete
		dml.dmlDelete(new List<SObject>{ aDb });
		List<Account> aAll = [SELECT Id, IsDeleted FROM Account WHERE Id = :a.Id ALL ROWS];
		System.assertEquals(1, aAll.size());
		System.assertEquals(true, aAll[0].IsDeleted);

		// Empty Recycle Bin (may or may not hard-delete in this org; just ensure call succeeds)
		dml.emptyRecycleBin(new List<SObject>{ aAll[0] });
	}

	@IsTest
	private static void testSimpleDML_Guards_NullAndEmpty() {
		UnitOfWork.SimpleDML dml = new UnitOfWork.SimpleDML();
		// Should no-op without exceptions
		dml.dmlInsert(null);
		dml.dmlInsert(new List<SObject>());
		dml.dmlUpdate(null);
		dml.dmlUpdate(new List<SObject>());
		dml.dmlDelete(null);
		dml.dmlDelete(new List<SObject>());
		dml.eventPublish(null);
		dml.eventPublish(new List<SObject>());
		dml.emptyRecycleBin(null);
		dml.emptyRecycleBin(new List<SObject>());
		System.assert(true);
	}
}


