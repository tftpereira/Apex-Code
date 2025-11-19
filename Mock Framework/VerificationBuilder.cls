/**
 * @description Builder for verifying method invocations
 */
@isTest
public class VerificationBuilder {
    private Object mock;
    private String methodName;
    private List<Object> matchers;
    private Integer callCount;
    
    public VerificationBuilder(Object mock, String methodName, List<Object> matchers) {
        this.mock = mock;
        this.methodName = methodName;
        this.matchers = matchers != null ? matchers : new List<Object>();
        this.callCount = countMatchingInvocations();
    }
    
    /**
     * @description Verify the method was called exactly n times
     */
    public void times(Integer n) {
        if (callCount != n) {
            throw new VerificationException('Expected ' + methodName + ' to be called ' + n + ' time(s), but was called ' + callCount + ' time(s)');
        }
    }
    
    /**
     * @description Verify the method was never called
     */
    public void never() {
        times(0);
    }
    
    /**
     * @description Verify the method was called at least n times
     */
    public void atLeast(Integer n) {
        if (callCount < n) {
            throw new VerificationException('Expected ' + methodName + ' to be called at least ' + n + ' time(s), but was called ' + callCount + ' time(s)');
        }
    }
    
    /**
     * @description Count invocations matching the method name and arguments
     */
    private Integer countMatchingInvocations() {
        List<Invocation> invocations = MockRegistry.getInvocations(mock, methodName);
        Integer count = 0;
        
        for (Invocation inv : invocations) {
            if (matches(inv.args)) {
                count++;
            }
        }
        
        return count;
    }
    
    /**
     * @description Check if invocation args match the matchers
     */
    private Boolean matches(List<Object> args) {
        if (matchers.size() != args.size()) {
            return false;
        }
        
        for (Integer i = 0; i < matchers.size(); i++) {
            Object matcher = matchers[i];
            Object arg = args[i];
            
            if (matcher instanceof IMatcher) {
                IMatcher m = (IMatcher) matcher;
                if (!m.matches(arg)) {
                    return false;
                }
            } else {
                // Literal value
                if (matcher == null && arg == null) {
                    continue;
                } else if (matcher != null && matcher.equals(arg)) {
                    continue;
                } else {
                    return false;
                }
            }
        }
        
        return true;
    }
    
    /**
     * @description Custom exception for verification failures
     */
    public class VerificationException extends Exception {}
}

