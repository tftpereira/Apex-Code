/**
 * @description Service class to simplify mock creation using Salesforce Stub API
 * Works with MockProvider to create mocks for any interface
 */
@isTest
public class MockService {
    private MockService() {}

    public static MockProvider getInstance(Map<String, Object> stubbedMethodMap) {
        return new MockProvider(stubbedMethodMap);
    }
    
    public static Object createMock(Type typeToMock, Map<String, Object> stubbedMethodMap) {
        MockProvider provider = getInstance(stubbedMethodMap);
        Object mock = Test.createStub(typeToMock, provider);
        provider.setMock(mock);
        return mock;
    }
    
    /**
     * @description Create a mock for the new fluent API (no stubs required upfront)
     */
    public static Object createMock(Type typeToMock) {
        MockProvider provider = new MockProvider(new Map<String, Object>());
        Object mock = Test.createStub(typeToMock, provider);
        provider.setMock(mock);
        return mock;
    }
    
    /**
     * @deprecated No longer needed - stubbing is done directly with when(). This method is a no-op for backward compatibility.
     */
    @Deprecated
    public static void startStubbing() {
        // No-op - deprecated
    }
    
    /**
     * @deprecated No longer needed - stubbing is done directly with when(). This method is a no-op for backward compatibility.
     */
    @Deprecated
    public static void stopStubbing() {
        // No-op - deprecated
    }
}

