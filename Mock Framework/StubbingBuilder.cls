/**
 * @description Builder for stubbing method behavior
 */
@isTest
public class StubbingBuilder {
    private Object mock;
    private MethodId methodId;
    private List<Object> matchers;
    private StubPlan.PlanType planType;
    private Boolean hasReturn = false;
    private Boolean hasThrow = false;
    
    public StubbingBuilder(Object mock, MethodId methodId, List<Object> matchers) {
        this.mock = mock;
        this.methodId = methodId;
        this.matchers = matchers != null ? matchers : new List<Object>();
    }
    
    /**
     * @description Stub to return value(s). After exhaustion, reuses the last value.
     */
    public void thenReturn(Object value) {
        thenReturn(new List<Object>{value});
    }
    
    /**
     * @description Stub to return multiple values. After exhaustion, reuses the last value.
     */
    public void thenReturn(Object value1, Object value2) {
        thenReturn(new List<Object>{value1, value2});
    }
    
    /**
     * @description Stub to return multiple values. After exhaustion, reuses the last value.
     */
    public void thenReturn(Object value1, Object value2, Object value3) {
        thenReturn(new List<Object>{value1, value2, value3});
    }
    
    /**
     * @description Stub to return multiple values. After exhaustion, reuses the last value.
     */
    public void thenReturn(List<Object> values) {
        if (hasThrow) {
            throw new MockException('Cannot mix thenReturn and thenThrow on same builder');
        }
        hasReturn = true;
        
        StubPlan plan = new StubPlan(StubPlan.PlanType.RETURN);
        if (values != null) {
            for (Object value : values) {
                plan.addToQueue(value);
            }
        }
        
        Stub stub = new Stub(methodId, matchers, plan);
        MockRegistry.registerStub(mock, stub);
    }
    
    /**
     * @description Stub to throw exception(s). After exhaustion, reuses the last exception.
     */
    public void thenThrow(Exception ex) {
        thenThrow(new List<Exception>{ex});
    }
    
    /**
     * @description Stub to throw multiple exceptions. After exhaustion, reuses the last exception.
     */
    public void thenThrow(Exception ex1, Exception ex2) {
        thenThrow(new List<Exception>{ex1, ex2});
    }
    
    /**
     * @description Stub to throw multiple exceptions. After exhaustion, reuses the last exception.
     */
    public void thenThrow(Exception ex1, Exception ex2, Exception ex3) {
        thenThrow(new List<Exception>{ex1, ex2, ex3});
    }
    
    /**
     * @description Stub to throw multiple exceptions. After exhaustion, reuses the last exception.
     */
    public void thenThrow(List<Exception> exceptions) {
        if (hasReturn) {
            throw new MockException('Cannot mix thenReturn and thenThrow on same builder');
        }
        hasThrow = true;
        
        StubPlan plan = new StubPlan(StubPlan.PlanType.THROW);
        if (exceptions != null) {
            for (Exception ex : exceptions) {
                plan.addToQueue(ex);
            }
        }
        
        Stub stub = new Stub(methodId, matchers, plan);
        MockRegistry.registerStub(mock, stub);
    }
    
    /**
     * @description Stub to execute a function that receives InvocationContext
     */
    public void thenAnswer(Function answerFn) {
        if (hasReturn || hasThrow) {
            throw new MockException('Cannot mix thenAnswer with thenReturn or thenThrow on same builder');
        }
        
        StubPlan plan = new StubPlan(StubPlan.PlanType.ANSWER);
        plan.answerFn = answerFn;
        
        Stub stub = new Stub(methodId, matchers, plan);
        MockRegistry.registerStub(mock, stub);
    }
    
    /**
     * @description Custom exception for mocking framework
     */
    public class MockException extends Exception {}
}

