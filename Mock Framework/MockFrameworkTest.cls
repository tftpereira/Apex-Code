/**
 * @description Comprehensive test suite for the mocking framework
 */
@isTest
private class MockFrameworkTest {
    
    @TestSetup
    static void setup() {
        MockRegistry.clear();
    }
    
    // ========== thenReturn Tests ==========
    
    @isTest
    static void testThenReturn_SingleValue() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock).method('sum', 2, 3).thenReturn(5);
        
        Integer result = mock.sum(2, 3);
        System.assertEquals(5, result, 'Should return stubbed value');
    }
    
    @isTest
    static void testThenReturn_MultipleValuesWithRollover() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock).method('getValue').thenReturn('first', 'second', 'third');
        
        System.assertEquals('first', mock.getValue(), 'First call');
        System.assertEquals('second', mock.getValue(), 'Second call');
        System.assertEquals('third', mock.getValue(), 'Third call');
        System.assertEquals('third', mock.getValue(), 'Fourth call should rollover to last');
        System.assertEquals('third', mock.getValue(), 'Fifth call should rollover to last');
    }
    
    // ========== thenThrow Tests ==========
    
    @isTest
    static void testThenThrow_SingleException() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        DmlException ex = new DmlException('Test error');
        
        When.when(mock).method('save', Matchers.any()).thenThrow(ex);
        
        try {
            mock.save(new Account());
            System.assert(false, 'Should have thrown exception');
        } catch (DmlException e) {
            System.assertEquals('Test error', e.getMessage());
        }
    }
    
    @isTest
    static void testThenThrow_MultipleExceptionsWithRollover() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        DmlException ex1 = new DmlException('Error 1');
        DmlException ex2 = new DmlException('Error 2');
        
        When.when(mock).method('save', Matchers.any()).thenThrow(ex1, ex2);
        
        try {
            mock.save(new Account());
            System.assert(false, 'Should have thrown exception');
        } catch (DmlException e) {
            System.assertEquals('Error 1', e.getMessage());
        }
        
        try {
            mock.save(new Account());
            System.assert(false, 'Should have thrown exception');
        } catch (DmlException e) {
            System.assertEquals('Error 2', e.getMessage());
        }
        
        try {
            mock.save(new Account());
            System.assert(false, 'Should have thrown exception');
        } catch (DmlException e) {
            System.assertEquals('Error 2', e.getMessage(), 'Should rollover to last exception');
        }
    }
    
    // ========== thenAnswer Tests ==========
    
    @isTest
    static void testThenAnswer_DynamicReturn() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock).method('lookup', Matchers.any()).thenAnswer(new LookupAnswer());
        
        System.assertEquals('Alpha', mock.lookup('A'), 'Should return Alpha for A');
        System.assertEquals('Other', mock.lookup('B'), 'Should return Other for B');
    }
    
    @isTest
    static void testThenAnswer_ConditionalException() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock).method('process', Matchers.any(), Matchers.any()).thenAnswer(new ConditionalExceptionAnswer());
        
        System.assertEquals('OK', mock.process('valid', 1), 'Should return OK for valid input');
        
        try {
            mock.process('invalid', 1);
            System.assert(false, 'Should have thrown exception');
        } catch (IllegalArgumentException e) {
            System.assertEquals('Invalid input', e.getMessage());
        }
    }
    
    // ========== Matchers Tests ==========
    
    @isTest
    static void testMatchers_Any() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock).method('sum', Matchers.any(), Matchers.any()).thenReturn(10);
        
        System.assertEquals(10, mock.sum(1, 2));
        System.assertEquals(10, mock.sum(100, 200));
    }
    
    @isTest
    static void testMatchers_Eq() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock).method('sum', Matchers.eq(2), Matchers.eq(3)).thenReturn(5);
        When.when(mock).method('sum', Matchers.any(), Matchers.any()).thenReturn(0);
        
        System.assertEquals(5, mock.sum(2, 3), 'Should match eq matchers');
        System.assertEquals(0, mock.sum(1, 1), 'Should fall back to any matchers');
    }
    
    @isTest
    static void testMatchers_IsNull() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock).method('lookup', Matchers.isNull()).thenReturn('null-key');
        When.when(mock).method('lookup', Matchers.any()).thenReturn('other');
        
        System.assertEquals('null-key', mock.lookup(null));
        System.assertEquals('other', mock.lookup('test'));
    }
    
    @isTest
    static void testMatchers_Matches() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        Function isPositive = new PositivePredicate();
        When.when(mock).method('sum', Matchers.matches(isPositive), Matchers.any()).thenReturn(100);
        When.when(mock).method('sum', Matchers.any(), Matchers.any()).thenReturn(0);
        
        System.assertEquals(100, mock.sum(5, 1), 'Should match positive predicate');
        System.assertEquals(0, mock.sum(-1, 1), 'Should not match negative');
    }
    
    // ========== Precedence Tests ==========
    
    @isTest
    static void testPrecedence_EqBeatsAny() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        // Register any() first
        When.when(mock).method('sum', Matchers.any(), Matchers.any()).thenReturn(0);
        // Register eq() second (more specific)
        When.when(mock).method('sum', Matchers.eq(2), Matchers.eq(3)).thenReturn(5);
        
        System.assertEquals(5, mock.sum(2, 3), 'eq should beat any');
        System.assertEquals(0, mock.sum(1, 1), 'any should match others');
    }
    
    // ========== Mixed Literals and Matchers Tests ==========
    
    @isTest
    static void testMixedLiteralsAndMatchers() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock).method('process', 'prefix', Matchers.any()).thenReturn('matched');
        When.when(mock).method('process', Matchers.any(), Matchers.any()).thenReturn('default');
        
        System.assertEquals('matched', mock.process('prefix', 1));
        System.assertEquals('default', mock.process('other', 1));
    }
    
    // ========== Verification Tests ==========
    
    @isTest
    static void testVerify_Times() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock).method('save', Matchers.any()).thenReturn(null);
        
        mock.save(new Account());
        mock.save(new Account());
        
        Verify.verify(mock).method('save', Matchers.any()).times(2);
    }
    
    @isTest
    static void testVerify_Never() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock).method('doNothing').thenReturn(null);
        
        Verify.verify(mock).method('doNothing').never();
    }
    
    @isTest
    static void testVerify_AtLeast() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock).method('save', Matchers.any()).thenReturn(null);
        
        mock.save(new Account());
        mock.save(new Account());
        mock.save(new Account());
        
        Verify.verify(mock).method('save', Matchers.any()).atLeast(2);
        Verify.verify(mock).method('save', Matchers.any()).atLeast(3);
    }
    
    @isTest
    static void testVerify_WithMatchers() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock).method('sum', Matchers.any(), Matchers.any()).thenReturn(0);
        
        mock.sum(2, 3);
        mock.sum(2, 3);
        
        Verify.verify(mock).method('sum', Matchers.eq(2), Matchers.eq(3)).times(2);
    }
    
    // ========== InOrder Tests ==========
    
    @isTest
    static void testInOrder_BasicSequence() {
        TestInterface mock1 = (TestInterface) MockService.createMock(TestInterface.class);
        TestInterface mock2 = (TestInterface) MockService.createMock(TestInterface.class);
        
        When.when(mock1).method('getValue').thenReturn('first');
        When.when(mock2).method('getValue').thenReturn('second');
        
        String val1 = mock1.getValue();
        String val2 = mock2.getValue();
        
        Verify.InOrderVerifier verifier = Verify.inOrder(mock1, mock2);
        verifier.verifySequence(
            new Verify.VerificationStep(mock1, 'getValue', new List<Object>()),
            new Verify.VerificationStep(mock2, 'getValue', new List<Object>())
        );
    }
    
    // ========== Error Cases Tests ==========
    
    @isTest
    static void testError_NoStubMatched() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        // No stub registered
        try {
            mock.sum(1, 2);
            System.assert(false, 'Should have thrown exception');
        } catch (MockProvider.MockException e) {
            System.assert(e.getMessage().contains('No stub matched'), 'Should have clear error message');
        }
    }
    
    @isTest
    static void testError_MixingThenReturnAndThenThrow() {
        TestInterface mock = (TestInterface) MockService.createMock(TestInterface.class);
        
        StubbingBuilder builder = When.when(mock).method('getValue');
        builder.thenReturn('value');
        
        try {
            builder.thenThrow(new DmlException('error'));
            System.assert(false, 'Should have thrown exception');
        } catch (StubbingBuilder.MockException e) {
            System.assert(e.getMessage().contains('Cannot mix'), 'Should prevent mixing');
        }
    }
    
    // ========== Helper Classes ==========
    
    private class LookupAnswer implements Function {
        public Object call(List<Object> args) {
            InvocationContext ctx = (InvocationContext) args[0];
            String key = (String) ctx.arg(0);
            return key == 'A' ? 'Alpha' : 'Other';
        }
    }
    
    private class ConditionalExceptionAnswer implements Function {
        public Object call(List<Object> args) {
            InvocationContext ctx = (InvocationContext) args[0];
            String input = (String) ctx.arg(0);
            if (input == 'invalid') {
                throw new IllegalArgumentException('Invalid input');
            }
            return 'OK';
        }
    }
    
    private class PositivePredicate implements Function {
        public Object call(List<Object> args) {
            Integer value = (Integer) args[0];
            return value > 0;
        }
    }
}

