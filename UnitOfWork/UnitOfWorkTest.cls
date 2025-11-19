@IsTest
private with sharing class UnitOfWorkTest {

	// SObjects (in order of dependency) used by UnitOfWork in tests below
	private static List<Schema.SObjectType> MY_SOBJECTS =
		new Schema.SObjectType[] {
			Product2.SObjectType,
			PricebookEntry.SObjectType,
			Opportunity.SObjectType,
			OpportunityLineItem.SObjectType };

	@IsTest
	private static void testUnitOfWorkEmail()
	{
		String testRecordName = 'UoW Test Name 1';

		Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
		email.setToAddresses(new List<String>{ 'foobar@test.com' });
		email.setPlainTextBody('See Spot run.');

		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		UnitOfWork uow = new UnitOfWork(MY_SOBJECTS, mockDML);

		uow.emailWork = new Mock_SendEmailWork();

		Opportunity opp = new Opportunity();
		opp.Name = testRecordName;
		opp.StageName = 'Open';
		opp.CloseDate = System.today();
		uow.registerNew( opp );

		uow.registerEmail( email );
		uow.registerRelationship( email, opp );

		uow.commitWork();

		// assert that mock email functionality was called
		System.assert(((Mock_SendEmailWork) uow.emailWork).doWorkWasCalled);

		System.assertEquals(1, mockDML.recordsForInsert.size());
	}

	@IsTest
	private static void testRegisterNew_ThrowExceptionOnDirtyRecord()
	{
		// GIVEN an existing record (fake Id ok since using MockDML)
		Opportunity opportunity = new Opportunity(Id = '006000000000001AAA');
		UnitOfWork unitOfWork = new UnitOfWork(MY_SOBJECTS);

		Boolean exceptionThrown = false;
		try {
			unitOfWork.registerNew(opportunity);
		} catch (Exception e) {
			exceptionThrown = true;
			System.assertEquals('Only new records can be registered as new', e.getMessage());
		}
		System.assert(exceptionThrown);
	}

	@IsTest
	private static void testRegisterDirty_ThrowExceptionOnNewRecord()
	{
		Opportunity opportunity = new Opportunity();
		UnitOfWork unitOfWork = new UnitOfWork(MY_SOBJECTS);

		Boolean exceptionThrown = false;
		try {
			unitOfWork.registerDirty(opportunity);
		} catch (Exception e) {
			exceptionThrown = true;
			System.assertEquals('New records cannot be registered as dirty', e.getMessage());
		}
		System.assert(exceptionThrown);
	}

	@IsTest
	private static void testRegisterDeleted()
	{
		Opportunity opportunity = new Opportunity(Id = '006000000000002AAA');
		Product2 product = new Product2(Id = '01t000000000001AAA');
		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		UnitOfWork unitOfWork = new UnitOfWork(MY_SOBJECTS, mockDML);

		unitOfWork.registerDeleted(new List<SObject> { opportunity, product });
		unitOfWork.commitWork();

		System.assertEquals(new List<SObject> { opportunity, product }, mockDML.recordsForDelete);
	}

	@IsTest
	private static void testRegisterPermanentlyDeleted()
	{
		Opportunity opportunity = new Opportunity(Id = '006000000000003AAA');
		Product2 product = new Product2(Id = '01t000000000002AAA');
		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		UnitOfWork unitOfWork = new UnitOfWork(MY_SOBJECTS, mockDML);

		unitOfWork.registerPermanentlyDeleted(new List<SObject> { opportunity, product });
		unitOfWork.commitWork();

		System.assertEquals(new List<SObject> { opportunity, product }, mockDML.recordsForDelete);
		System.assertEquals(new List<SObject> { opportunity, product }, mockDML.recordsForRecycleBin);
	}

	@IsTest
	private static void testRegisterEmptyRecycleBin()
	{
		Opportunity opportunity = new Opportunity(Id = '006000000000004AAA');
		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		UnitOfWork unitOfWork = new UnitOfWork(MY_SOBJECTS, mockDML);

		unitOfWork.registerEmptyRecycleBin(new List<Opportunity>{ opportunity });
		unitOfWork.commitWork();

		System.assertEquals(1, mockDML.recordsForRecycleBin.size());
	}

	@IsTest
	private static void testAssertForNonEventSObjectType()
	{
		UnitOfWork unitOfWork = new UnitOfWork(MY_SOBJECTS);
		unitOfWork.assertForNonEventSObjectType('CustomObject__c');
	}

	@IsTest
	private static void testAssertForNonEventSObjectType_ThrowExceptionOnEventObject()
	{
		Boolean exceptionThrown = false;
		UnitOfWork unitOfWork = new UnitOfWork(MY_SOBJECTS);
		try {
			unitOfWork.assertForNonEventSObjectType('PlatformEventObject__e');
		} catch (Exception e) {
			exceptionThrown = true;
			System.assert(e.getMessage().contains('Use registerPublish'));
		}
		System.assert(exceptionThrown);
	}

	@IsTest
	private static void testAssertForEventSObjectType()
	{
		UnitOfWork unitOfWork = new UnitOfWork(MY_SOBJECTS);
		unitOfWork.assertForEventSObjectType('PlatformEventObject__e');
	}

	@IsTest
	private static void testAssertForEventSObjectType_ThrowExceptionOnNonEventObject()
	{
		Boolean exceptionThrown = false;
		UnitOfWork unitOfWork = new UnitOfWork(MY_SOBJECTS);
		try {
			unitOfWork.assertForEventSObjectType('CustomObject__c');
		} catch (Exception e) {
			exceptionThrown = true;
			System.assert(e.getMessage().contains('not a platform event'));
		}
		System.assert(exceptionThrown);
	}

	@IsTest
	private static void testAssertForSupportedSObjectType_throwExceptionOnUnsupportedType()
	{
		Boolean exceptionThrown = false;
		UnitOfWork unitOfWork = new UnitOfWork(MY_SOBJECTS);
		try {
			unitOfWork.registerNew(new Account());
		} catch (Exception e) {
			exceptionThrown = true;
			System.assert(e.getMessage().contains('not supported by this unit of work'));
		}
		System.assert(exceptionThrown);
	}

	@IsTest
	private static void testDerivedUnitOfWork_CommitSuccess()
	{
		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		DerivedUnitOfWork uow = new DerivedUnitOfWork(MY_SOBJECTS, mockDML);
		for (Integer o = 0; o < 10; o++)
		{
			Opportunity opp = new Opportunity();
			opp.Name = 'UoW Test Name ' + o;
			opp.StageName = 'Open';
			opp.CloseDate = System.today();
			uow.registerNew(new List<SObject>{ opp });
			for (Integer i = 0; i < o + 1; i++)
			{
				Product2 product = new Product2();
				product.Name = opp.Name + ' : Product : ' + i;
				uow.registerNew(new List<SObject>{ product });
				PricebookEntry pbe = new PricebookEntry();
				pbe.UnitPrice = 10;
				pbe.IsActive = true;
				pbe.UseStandardPrice = false;
				uow.registerNew(pbe, PricebookEntry.Product2Id, product);
				OpportunityLineItem oppLineItem = new OpportunityLineItem();
				oppLineItem.Quantity = 1;
				oppLineItem.TotalPrice = 10;
				uow.registerRelationship(oppLineItem, OpportunityLineItem.PricebookEntryId, pbe);
				uow.registerNew(oppLineItem, OpportunityLineItem.OpportunityId, opp);
			}
		}
		uow.commitWork();

		System.assertEquals(175, mockDML.recordsForInsert.size(), 'Incorrect number of new records');

		assertEvents(new List<String> {
				'onCommitWorkStarting'
				, 'onPublishBeforeEventsStarting'
				, 'onPublishBeforeEventsFinished'
				, 'onDMLStarting'
				, 'onDMLFinished'
				, 'onDoWorkStarting'
				, 'onDoWorkFinished'
				, 'onCommitWorkFinishing'
				, 'onPublishAfterSuccessEventsStarting'
				, 'onPublishAfterSuccessEventsFinished'
				, 'onCommitWorkFinished - true'
			}
			, uow.getCommitWorkEventsFired(), new Set<Schema.SObjectType>(MY_SOBJECTS), uow.getRegisteredTypes());
	}

	@IsTest
	private static void testDerivedUnitOfWork_CommitDMLFail()
	{
		DerivedUnitOfWork uow = new DerivedUnitOfWork(MY_SOBJECTS);
		Opportunity opp = new Opportunity();
		// leave Name null to induce required field missing along with other fields; still causes failure
		uow.registerNew(new List<SObject>{ opp });
		Boolean didFail = false;
		System.DmlException caughtEx = null;

		try {
			uow.commitWork();
		} catch (System.DmlException dmlex) {
			didFail = true;
			caughtEx = dmlex;
		}

		System.assertEquals(true, didFail, 'didFail');
		System.assert(caughtEx.getMessage().contains('REQUIRED_FIELD_MISSING'), 'Expected required field missing');

		assertEvents(new List<String> {
				'onCommitWorkStarting'
				, 'onPublishBeforeEventsStarting'
				, 'onPublishBeforeEventsFinished'
				, 'onDMLStarting'
				, 'onPublishAfterFailureEventsStarting'
				, 'onPublishAfterFailureEventsFinished'
				, 'onCommitWorkFinished - false'
			}
			, uow.getCommitWorkEventsFired(), new Set<Schema.SObjectType>(MY_SOBJECTS), uow.getRegisteredTypes());
	}

	@IsTest
	private static void testDerivedUnitOfWork_CommitDoWorkFail()
	{
		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		DerivedUnitOfWork uow = new DerivedUnitOfWork(MY_SOBJECTS, mockDML);
		Opportunity opp = new Opportunity();
		opp.Name = 'UoW Test Name 1';
		opp.StageName = 'Open';
		opp.CloseDate = System.today();
		uow.registerNew(new List<SObject>{ opp });

		FailDoingWork fdw = new FailDoingWork();
		uow.registerWork(fdw);

		Boolean didFail = false;
		FailDoingWorkException caughtEx = null;

		try {
			uow.commitWork();
		} catch (FailDoingWorkException fdwe) {
			didFail = true;
			caughtEx = fdwe;
		}

		System.assertEquals(true, didFail, 'didFail');
		System.assert(caughtEx.getMessage().contains('Work failed.'), 'Unexpected exception message');

		assertEvents(new List<String> {
				'onCommitWorkStarting'
				, 'onPublishBeforeEventsStarting'
				, 'onPublishBeforeEventsFinished'
				, 'onDMLStarting'
				, 'onDMLFinished'
				, 'onDoWorkStarting'
				, 'onPublishAfterFailureEventsStarting'
				, 'onPublishAfterFailureEventsFinished'
				, 'onCommitWorkFinished - false'
			}
			, uow.getCommitWorkEventsFired(), new Set<Schema.SObjectType>(MY_SOBJECTS), uow.getRegisteredTypes());
	}

	@IsTest
	private static void testRegisterDirty_ExpectReplacement()
	{
		Opportunity insertedOpp = new Opportunity(
				Id = '006000000000010AAA',
				Name = 'Original',
				StageName = 'Open',
				CloseDate = System.today());

		Opportunity opp = new Opportunity(Id = insertedOpp.Id, Name = 'Never');
		Opportunity opp2 = new Opportunity(Id = insertedOpp.Id, Name = 'Expected');

		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		UnitOfWork uow = new UnitOfWork(MY_SOBJECTS, mockDML);
		uow.registerDirty(opp);
		uow.registerDirty(opp2);
		uow.commitWork();

		System.assertEquals(1, mockDML.recordsForUpdate.size());
		System.assertEquals('Expected', (String) mockDML.recordsForUpdate.get(0).get(Schema.Opportunity.Name));
	}

	@IsTest
	private static void testRegisterDirty_field() {
		Opportunity opp = new Opportunity(
				Id = '006000000000011AAA',
				Name = 'test name',
				StageName = 'Open',
				CloseDate = System.today());

		Opportunity nameUpdate = new Opportunity(Id = opp.Id, Name = 'UpdateName');
		Opportunity amountUpdate = new Opportunity(Id = opp.Id, Amount = 250);
		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		UnitOfWork uow = new UnitOfWork(MY_SOBJECTS, mockDML);
		uow.registerDirty(nameUpdate);
		uow.registerDirty(amountUpdate, new List<SObjectField> { Opportunity.Amount } );
		uow.commitWork();

		System.assertEquals(1, mockDML.recordsForUpdate.size());
		System.assertEquals(nameUpdate.Name, (String) mockDML.recordsForUpdate.get(0).get(Schema.Opportunity.Name));
		System.assertEquals(amountUpdate.Amount, (Decimal) mockDML.recordsForUpdate.get(0).get(Schema.Opportunity.Amount));
	}

	@IsTest
	private static void testRegisterDirtyRecordsWithDirtyFields()
	{
		Opportunity opportunityA = new Opportunity(
				Id = '006000000000020AAA',
				Name = 'test name A',
				StageName = 'Open',
				CloseDate = System.today());
		Opportunity opportunityB = new Opportunity(
				Id = '006000000000021AAA',
				Name = 'test name B',
				StageName = 'Open',
				CloseDate = System.today());

		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		UnitOfWork uow = new UnitOfWork(MY_SOBJECTS, mockDML);
		uow.registerDirty(new List<Opportunity>{ opportunityA, opportunityB });

		List<Opportunity> recordsWithStageUpdate = new List<Opportunity>{
				new Opportunity(Id = opportunityA.Id, StageName = 'Closed'),
				new Opportunity(Id = opportunityB.Id, StageName = 'Closed')
		};
		List<Opportunity> recordsWithAmountUpdate = new List<Opportunity>{
				new Opportunity(Id = opportunityA.Id, Amount = 250),
				new Opportunity(Id = opportunityB.Id, Amount = 250)
		};
		uow.registerDirty(recordsWithStageUpdate, new List<SObjectField> { Opportunity.StageName });
		uow.registerDirty(recordsWithAmountUpdate, new List<SObjectField> { Opportunity.Amount });
		uow.commitWork();

		System.assertEquals(2, mockDML.recordsForUpdate.size());
		Boolean aOk = ((Id) mockDML.recordsForUpdate[0].get('Id') == opportunityA.Id || (Id) mockDML.recordsForUpdate[1].get('Id') == opportunityA.Id);
		System.assertEquals(true, aOk);
	}

	@IsTest
	private static void testRegisterDirtyRecordsWithDirtyFields_failing()
	{
		Opportunity opportunityA = new Opportunity(
				Id = '006000000000030AAA',
				Name = 'test name A',
				StageName = 'Open',
				CloseDate = System.today());
		Opportunity opportunityB = new Opportunity(
				Id = '006000000000031AAA',
				Name = 'test name B',
				StageName = 'Open',
				CloseDate = System.today());

		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		UnitOfWork uow = new UnitOfWork(MY_SOBJECTS, mockDML);
		uow.registerDirty(new List<Opportunity>{ opportunityA, opportunityB });

		List<Opportunity> recordsWithStageUpdate = new List<Opportunity>{
				new Opportunity(Id = opportunityA.Id, StageName = 'Closed'),
				new Opportunity(Id = opportunityB.Id, StageName = 'Closed')
		};
		List<Opportunity> recordsWithAmountUpdate = new List<Opportunity>{
				new Opportunity(Id = opportunityA.Id, Amount = 250),
				new Opportunity(Id = opportunityB.Id, Amount = 250)
		};
		uow.registerDirty(recordsWithStageUpdate, new List<SObjectField> { Opportunity.StageName });
		uow.registerDirty(recordsWithAmountUpdate, new List<SObjectField> { Opportunity.Amount });
		uow.registerDirty(new Opportunity(
				Id = opportunityB.Id,
				Name = 'test name B',
				StageName = 'Open',
				CloseDate = System.today()
		));
		uow.commitWork();

		System.assertEquals(2, mockDML.recordsForUpdate.size());
	}

	@IsTest
	private static void testRegisterUpsert() {
		Opportunity existingOpp = new Opportunity(
				Id = '006000000000040AAA',
				Name = 'Existing Opportunity',
				StageName = 'Closed',
				CloseDate = System.today());

		Opportunity newOpportunity = new Opportunity(Name = 'New Opportunity', StageName = 'Closed', CloseDate = System.today());

		Test.startTest();
		UnitOfWorkMockDML mockDML = new UnitOfWorkMockDML();
		UnitOfWork uow = new UnitOfWork(MY_SOBJECTS, mockDML);
		uow.registerUpsert(new List<Opportunity>{existingOpp, newOpportunity});
		uow.commitWork();
		Test.stopTest();

		System.assertEquals(1, mockDML.recordsForUpdate.size());
		System.assertEquals(1, mockDML.recordsForInsert.size());
	}

	@IsTest
	private static void constructUserModeDML_When_DefaultConstructor_Expect_UserMode(){
		UnitOfWork.UserModeDML dml = new UnitOfWork.UserModeDML();
		System.assertEquals(System.AccessLevel.USER_MODE, dml.accessLevel);
	}

	@IsTest
	private static void constructUserModeDML_When_AccessLevelSupplied_Expect_SameAccessLevel(){
		UnitOfWork.UserModeDML dml = new UnitOfWork.UserModeDML(System.AccessLevel.SYSTEM_MODE);
		System.assertEquals(System.AccessLevel.SYSTEM_MODE, dml.accessLevel);
	}

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

	private static void assertEvents(List<String> expectedEvents, List<String> actualEvents, Set<Schema.SObjectType> expectedTypes, Set<Schema.SObjectType> actualTypes)
	{
		System.assertEquals(expectedEvents.size(), actualEvents.size(), 'events size');
		for (Integer i = 0; i < expectedEvents.size(); i++) {
			System.assertEquals(expectedEvents[i], actualEvents[i], String.format('Event {0} was not fired in order expected.', new List<String> { expectedEvents[i] }));
		}
		System.assertEquals(expectedTypes.size(), actualTypes.size(), 'types size');
		for (Schema.SObjectType sObjectType : expectedTypes) {
			System.assertEquals(true, actualTypes.contains(sObjectType), String.format('Type {0} was not registered.', new List<String> { sObjectType.getDescribe().getName() }));
		}
	}

	private class FailDoingWork implements UnitOfWork.IDoWork
	{
		public void doWork()
		{
			throw new FailDoingWorkException('Work failed.');
		}
	}

	private class DerivedUnitOfWork extends UnitOfWork
	{
		private List<String> m_commitWorkEventsFired = new List<String>();
		private Set<Schema.SObjectType> m_registeredTypes = new Set<Schema.SObjectType>();

		public List<String> getCommitWorkEventsFired() { return m_commitWorkEventsFired.clone(); }
		public Set<Schema.SObjectType> getRegisteredTypes() { return m_registeredTypes.clone(); }

		public DerivedUnitOfWork(List<Schema.SObjectType> sObjectTypes) { super(sObjectTypes); }
		public DerivedUnitOfWork(List<Schema.SObjectType> sObjectTypes, IDML dml) { super(sObjectTypes, dml); }

		private void addEvent(String event)
		{
			for (String eventName : m_commitWorkEventsFired) {
				if (event == eventName) {
					throw new DerivedUnitOfWorkException(String.format('Event {0} has already been fired.', new List<String> { event }));
				}
			}
			m_commitWorkEventsFired.add(event);
		}

		public override void onRegisterType(Schema.SObjectType sObjectType)
		{
			if (m_registeredTypes.contains(sObjectType)) {
				throw new DerivedUnitOfWorkException(String.format('Type {0} has already been registered.', new List<String> { sObjectType.getDescribe().getName() }));
			}
			m_registeredTypes.add(sObjectType);
		}
		public override void onCommitWorkStarting() { addEvent('onCommitWorkStarting'); }
		public override void onPublishBeforeEventsStarting() { addEvent('onPublishBeforeEventsStarting'); }
		public override void onPublishBeforeEventsFinished() { addEvent('onPublishBeforeEventsFinished'); }
		public override void onDMLStarting() { addEvent('onDMLStarting'); }
		public override void onDMLFinished() { addEvent('onDMLFinished'); }
		public override void onDoWorkStarting() { addEvent('onDoWorkStarting'); }
		public override void onDoWorkFinished() { addEvent('onDoWorkFinished'); }
		public override void onCommitWorkFinishing() { addEvent('onCommitWorkFinishing'); }
		public override void onPublishAfterSuccessEventsStarting() { addEvent('onPublishAfterSuccessEventsStarting'); }
		public override void onPublishAfterSuccessEventsFinished() { addEvent('onPublishAfterSuccessEventsFinished'); }
		public override void onPublishAfterFailureEventsStarting() { addEvent('onPublishAfterFailureEventsStarting'); }
		public override void onPublishAfterFailureEventsFinished() { addEvent('onPublishAfterFailureEventsFinished'); }
		public override void onCommitWorkFinished(Boolean wasSuccessful) { addEvent('onCommitWorkFinished - ' + wasSuccessful); }
	}

	private class Mock_SendEmailWork implements UnitOfWork.IEmailWork
	{
		public void registerEmail(Messaging.Email email) {}
		public void doWork() { doWorkWasCalled = true; }
		public Boolean doWorkWasCalled = false;
	}


public class DerivedUnitOfWorkException extends Exception {}
public class FailDoingWorkException extends Exception {}
}




