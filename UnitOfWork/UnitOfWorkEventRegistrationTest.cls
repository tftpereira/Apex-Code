@IsTest
private with sharing class UnitOfWorkEventRegistrationTest {

	private static Schema.SObjectType findAnyPlatformEvent() {
		for (Schema.SObjectType t : Schema.getGlobalDescribe().values()) {
			String name = t.getDescribe().getName();
			if (name != null && name.endsWith('__e')) return t;
		}
		return null;
	}

	@IsTest
	private static void testRegisterPublish_SuccessPhases() {
		Schema.SObjectType peType = findAnyPlatformEvent();
		if (peType == null) { System.assert(true); return; }

		List<Schema.SObjectType> types = new List<Schema.SObjectType>{ Account.SObjectType, peType };
		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		UnitOfWork uow = new UnitOfWork(types, mockDML);

		// Records for publishing
		SObject beforeEvt = peType.newSObject();
		SObject afterSuccessEvt = peType.newSObject();

		uow.registerPublishBeforeTransaction(beforeEvt);
		uow.registerPublishAfterSuccessTransaction(afterSuccessEvt);

		// Also add a simple successful DML so commit succeeds
		uow.registerNew(new Account(Name = 'OK'));

		uow.commitWork();

		// Expect 2 publishes (before + after success)
		System.assertEquals(2, mockDML.recordsForEventPublish.size());
	}

	@IsTest
	private static void testRegisterPublish_FailurePhases() {
		Schema.SObjectType peType = findAnyPlatformEvent();
		if (peType == null) { System.assert(true); return; }

		List<Schema.SObjectType> types = new List<Schema.SObjectType>{ Account.SObjectType, peType };
		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		UnitOfWork uow = new UnitOfWork(types, mockDML);

		SObject beforeEvt = peType.newSObject();
		SObject afterFailureEvt = peType.newSObject();

		uow.registerPublishBeforeTransaction(beforeEvt);
		uow.registerPublishAfterFailureTransaction(afterFailureEvt);

		// Force DML failure: Account.Name is required
		uow.registerNew(new Account());

		Boolean failed = false;
		try {
			uow.commitWork();
		} catch (DmlException ex) {
			failed = true;
		}
		System.assertEquals(true, failed);

		// Expect 2 publishes (before + after failure)
		System.assertEquals(2, mockDML.recordsForEventPublish.size());
	}
}


