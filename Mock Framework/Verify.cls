/**
 * @description Entry point for verifying method invocations
 * Usage: verify(mock).method('methodName', arg1, arg2, ...).times(1)
 */
@isTest
public class Verify {
    
    private Object mock;
    
    private Verify(Object mock) {
        this.mock = mock;
    }
    
    /**
     * @description Start verification for a mock object
     */
    public static Verify verify(Object mock) {
        return new Verify(mock);
    }
    
    /**
     * @description Verify a method with no arguments
     */
    public VerificationBuilder method(String methodName) {
        return method(methodName, new List<Object>());
    }
    
    /**
     * @description Verify a method with arguments (can mix literals and matchers)
     */
    public VerificationBuilder method(String methodName, Object arg1) {
        return method(methodName, new List<Object>{arg1});
    }
    
    /**
     * @description Verify a method with arguments
     */
    public VerificationBuilder method(String methodName, Object arg1, Object arg2) {
        return method(methodName, new List<Object>{arg1, arg2});
    }
    
    /**
     * @description Verify a method with arguments
     */
    public VerificationBuilder method(String methodName, Object arg1, Object arg2, Object arg3) {
        return method(methodName, new List<Object>{arg1, arg2, arg3});
    }
    
    /**
     * @description Verify a method with arguments
     */
    public VerificationBuilder method(String methodName, Object arg1, Object arg2, Object arg3, Object arg4) {
        return method(methodName, new List<Object>{arg1, arg2, arg3, arg4});
    }
    
    /**
     * @description Verify a method with arguments (list version)
     */
    public VerificationBuilder method(String methodName, List<Object> args) {
        return new VerificationBuilder(mock, methodName, args);
    }
    
    /**
     * @description Verify invocations occurred in order across multiple mocks
     * Usage: Verify.inOrder(mock1, mock2).verifySequence(
     *   new VerificationStep(mock1, 'method1', args1),
     *   new VerificationStep(mock2, 'method2', args2)
     * )
     */
    public static InOrderVerifier inOrder(Object mock1, Object mock2) {
        return new InOrderVerifier(new List<Object>{mock1, mock2});
    }
    
    /**
     * @description Verify invocations occurred in order across multiple mocks
     */
    public static InOrderVerifier inOrder(Object mock1, Object mock2, Object mock3) {
        return new InOrderVerifier(new List<Object>{mock1, mock2, mock3});
    }
    
    /**
     * @description Verify invocations occurred in order across multiple mocks
     */
    public static InOrderVerifier inOrder(List<Object> mocks) {
        return new InOrderVerifier(mocks);
    }
    
    /**
     * @description Helper class for in-order verification
     */
    public class InOrderVerifier {
        private List<Object> mocks;
        
        public InOrderVerifier(List<Object> mocks) {
            this.mocks = mocks;
        }
        
        /**
         * @description Verify that invocations occurred in the specified sequence
         */
        public void verifySequence(VerificationStep step1, VerificationStep step2) {
            verifySequence(new List<VerificationStep>{step1, step2});
        }
        
        /**
         * @description Verify that invocations occurred in the specified sequence
         */
        public void verifySequence(VerificationStep step1, VerificationStep step2, VerificationStep step3) {
            verifySequence(new List<VerificationStep>{step1, step2, step3});
        }
        
        /**
         * @description Verify that invocations occurred in the specified sequence
         */
        public void verifySequence(List<VerificationStep> steps) {
            List<Invocation> allInvocations = MockRegistry.getAllInvocations();
            List<Invocation> relevantInvocations = new List<Invocation>();
            
            // Filter to only invocations from our mocks
            for (Invocation inv : allInvocations) {
                if (mocks.contains(inv.mock)) {
                    relevantInvocations.add(inv);
                }
            }
            
            // Sort by timestamp
            relevantInvocations.sort(new InvocationComparator());
            
            // Check if steps appear in order
            Integer stepIndex = 0;
            for (Invocation inv : relevantInvocations) {
                if (stepIndex >= steps.size()) {
                    break;
                }
                
                VerificationStep step = steps[stepIndex];
                if (step.matches(inv)) {
                    stepIndex++;
                }
            }
            
            if (stepIndex < steps.size()) {
                throw new VerificationException('Expected sequence not found. Step ' + (stepIndex + 1) + ' (' + steps[stepIndex].methodName + ') was not called in order.');
            }
        }
    }
    
    /**
     * @description Represents a step in the verification sequence
     */
    public class VerificationStep {
        public Object mock;
        public String methodName;
        public List<Object> matchers;
        
        public VerificationStep(Object mock, String methodName, List<Object> matchers) {
            this.mock = mock;
            this.methodName = methodName;
            this.matchers = matchers != null ? matchers : new List<Object>();
        }
        
        public Boolean matches(Invocation inv) {
            if (inv.mock != mock || inv.methodName != methodName) {
                return false;
            }
            
            if (matchers.size() != inv.args.size()) {
                return false;
            }
            
            for (Integer i = 0; i < matchers.size(); i++) {
                Object matcher = matchers[i];
                Object arg = inv.args[i];
                
                if (matcher instanceof IMatcher) {
                    IMatcher m = (IMatcher) matcher;
                    if (!m.matches(arg)) {
                        return false;
                    }
                } else {
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
    }
    
    /**
     * @description Comparator for sorting invocations by timestamp
     */
    private class InvocationComparator implements Comparator<Invocation> {
        public Integer compare(Invocation a, Invocation b) {
            if (a.timestamp < b.timestamp) {
                return -1;
            } else if (a.timestamp > b.timestamp) {
                return 1;
            }
            return 0;
        }
    }
    
    /**
     * @description Custom exception for verification failures
     */
    public class VerificationException extends Exception {}
}

