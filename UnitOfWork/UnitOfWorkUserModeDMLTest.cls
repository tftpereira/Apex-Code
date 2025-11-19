@IsTest
private with sharing class UnitOfWorkUserModeDMLTest {

	@IsTest
	private static void testUserModeDML_InsertUpdateDelete_DefaultUserMode() {
		UnitOfWork.UserModeDML dml = new UnitOfWork.UserModeDML();

		// Insert
		Account a = new Account(Name = 'USER MODE DML');
		dml.dmlInsert(new List<SObject>{ a });
		System.assertNotEquals(null, a.Id);

		// Update
		Account aChanges = new Account(Id = a.Id, Name = 'USER MODE DML UPDATED');
		dml.dmlUpdate(new List<SObject>{ aChanges });
		Account aDb = [SELECT Id, Name FROM Account WHERE Id = :a.Id];
		System.assertEquals('USER MODE DML UPDATED', aDb.Name);

		// Delete
		dml.dmlDelete(new List<SObject>{ aDb });
		List<Account> aAll = [SELECT Id, IsDeleted FROM Account WHERE Id = :a.Id ALL ROWS];
		System.assertEquals(1, aAll.size());
		System.assertEquals(true, aAll[0].IsDeleted);
	}

	@IsTest
	private static void testUserModeDML_GuardsAndCustomAccessLevel() {
		// Guards
		UnitOfWork.UserModeDML dml = new UnitOfWork.UserModeDML(System.AccessLevel.SYSTEM_MODE);
		dml.dmlInsert(null);
		dml.dmlInsert(new List<SObject>());
		dml.dmlUpdate(null);
		dml.dmlUpdate(new List<SObject>());
		dml.dmlDelete(null);
		dml.dmlDelete(new List<SObject>());
		System.assert(true);

		// Also perform a simple op under SYSTEM_MODE to execute the Database.* path
		Account a = new Account(Name = 'SYSTEM MODE DML');
		dml.dmlInsert(new List<SObject>{ a });
		System.assertNotEquals(null, a.Id);
	}
}


