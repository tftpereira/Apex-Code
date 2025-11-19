@IsTest
private with sharing class UnitOfWorkAccessorsTest {

	@IsTest
	private static void testAccessors_New_Dirty_Deleted_And_TryGet() {
		UnitOfWork uow = new UnitOfWork(new List<Schema.SObjectType>{ Account.SObjectType, Contact.SObjectType });

		// New
		Contact c = new Contact(LastName = 'A');
		uow.registerNew(c);
		System.assertEquals(1, uow.getRegisteredNew('Contact').size());
		System.assertEquals(1, uow.getRegisteredNew(Contact.SObjectType).size());

		// Dirty
		Account a = new Account(Name = 'X');
		insert a;
		Account aChanges = new Account(Id = a.Id, Name = 'Y');
		uow.registerDirty(aChanges, new List<Schema.SObjectField>{ Account.Name });
		System.assertNotEquals(null, uow.tryGetDirtyById('Account', a.Id));
		System.assertEquals(1, uow.getRegisteredDirty(Account.SObjectType).size());

		// Deleted
		uow.registerDeleted(a);
		System.assertEquals(1, uow.getRegisteredDeleted('Account').size());
		System.assertEquals(1, uow.getRegisteredDeleted(Account.SObjectType).size());
	}
}


