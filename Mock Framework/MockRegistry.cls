/**
 * @description Central registry for stubs and invocations
 */
@isTest
public class MockRegistry {
    // Per-mock registry: Map<Object, Map<MethodId, List<Stub>>>
    private static Map<Object, Map<MethodId, List<Stub>>> stubRegistry = new Map<Object, Map<MethodId, List<Stub>>>();
    
    // Invocation log for verification
    private static List<Invocation> invocationLog = new List<Invocation>();
    
    /**
     * @description Register a stub for a mock
     */
    public static void registerStub(Object mock, Stub stub) {
        if (!stubRegistry.containsKey(mock)) {
            stubRegistry.put(mock, new Map<MethodId, List<Stub>>());
        }
        Map<MethodId, List<Stub>> mockStubs = stubRegistry.get(mock);
        if (!mockStubs.containsKey(stub.methodId)) {
            mockStubs.put(stub.methodId, new List<Stub>());
        }
        mockStubs.get(stub.methodId).add(stub);
    }
    
    /**
     * @description Find the best matching stub for an invocation
     */
    public static Stub findStub(Object mock, MethodId methodId, List<Object> args) {
        if (!stubRegistry.containsKey(mock)) {
            return null;
        }
        Map<MethodId, List<Stub>> mockStubs = stubRegistry.get(mock);
        if (!mockStubs.containsKey(methodId)) {
            return null;
        }
        
        List<Stub> candidates = mockStubs.get(methodId);
        Stub bestMatch = null;
        Integer bestScore = -1;
        
        for (Stub stub : candidates) {
            if (stub.matchers.size() != args.size()) {
                continue; // Arity mismatch
            }
            
            Integer score = calculateMatchScore(stub.matchers, args);
            if (score > bestScore || (score == bestScore && (bestMatch == null || stub.createdAt > bestMatch.createdAt))) {
                bestScore = score;
                bestMatch = stub;
            }
        }
        
        return bestMatch;
    }
    
    /**
     * @description Calculate match score based on specificity
     * literal/eq = 2, matches = 1, any = 0
     */
    private static Integer calculateMatchScore(List<Object> matchers, List<Object> args) {
        if (matchers.size() != args.size()) {
            return -1;
        }
        
        Integer totalScore = 0;
        for (Integer i = 0; i < matchers.size(); i++) {
            Object matcher = matchers[i];
            Object arg = args[i];
            
            if (matcher instanceof IMatcher) {
                IMatcher m = (IMatcher) matcher;
                if (m.matches(arg)) {
                    totalScore += m.getSpecificity();
                } else {
                    return -1; // No match
                }
            } else {
                // Literal value - highest specificity
                if (matcher == null && arg == null) {
                    totalScore += 3;
                } else if (matcher != null && matcher.equals(arg)) {
                    totalScore += 3;
                } else {
                    return -1; // No match
                }
            }
        }
        
        return totalScore;
    }
    
    /**
     * @description Record an invocation
     */
    public static void recordInvocation(Object mock, String methodName, List<Object> args) {
        invocationLog.add(new Invocation(mock, methodName, args));
    }
    
    /**
     * @description Get invocations for a mock and method
     */
    public static List<Invocation> getInvocations(Object mock, String methodName) {
        List<Invocation> result = new List<Invocation>();
        for (Invocation inv : invocationLog) {
            if (inv.mock == mock && inv.methodName == methodName) {
                result.add(inv);
            }
        }
        return result;
    }
    
    /**
     * @description Get all invocations for a mock
     */
    public static List<Invocation> getInvocations(Object mock) {
        List<Invocation> result = new List<Invocation>();
        for (Invocation inv : invocationLog) {
            if (inv.mock == mock) {
                result.add(inv);
            }
        }
        return result;
    }
    
    /**
     * @description Get all invocations (for inOrder)
     */
    public static List<Invocation> getAllInvocations() {
        return invocationLog.clone();
    }
    
    /**
     * @description Clear all stubs and invocations (for test cleanup)
     */
    public static void clear() {
        stubRegistry.clear();
        invocationLog.clear();
    }
    
    /**
     * @description Clear stubs for a specific mock
     */
    public static void clearMock(Object mock) {
        stubRegistry.remove(mock);
        // Remove invocations for this mock
        List<Invocation> toKeep = new List<Invocation>();
        for (Invocation inv : invocationLog) {
            if (inv.mock != mock) {
                toKeep.add(inv);
            }
        }
        invocationLog = toKeep;
    }
}

