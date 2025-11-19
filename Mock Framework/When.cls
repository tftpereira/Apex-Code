/**
 * @description Entry point for stubbing method behavior
 * Usage: when(mock).method('methodName', arg1, arg2, ...).thenReturn(value)
 */
@isTest
public class When {
    
    private Object mock;
    
    private When(Object mock) {
        this.mock = mock;
    }
    
    /**
     * @description Start stubbing for a mock object
     */
    public static When when(Object mock) {
        return new When(mock);
    }
    
    /**
     * @description Stub a method with no arguments
     */
    public StubbingBuilder method(String methodName) {
        return method(methodName, new List<Type>(), new List<Object>());
    }
    
    /**
     * @description Stub a method with arguments (can mix literals and matchers)
     */
    public StubbingBuilder method(String methodName, Object arg1) {
        return method(methodName, inferTypes(new List<Object>{arg1}), new List<Object>{arg1});
    }
    
    /**
     * @description Stub a method with arguments
     */
    public StubbingBuilder method(String methodName, Object arg1, Object arg2) {
        return method(methodName, inferTypes(new List<Object>{arg1, arg2}), new List<Object>{arg1, arg2});
    }
    
    /**
     * @description Stub a method with arguments
     */
    public StubbingBuilder method(String methodName, Object arg1, Object arg2, Object arg3) {
        return method(methodName, inferTypes(new List<Object>{arg1, arg2, arg3}), new List<Object>{arg1, arg2, arg3});
    }
    
    /**
     * @description Stub a method with arguments
     */
    public StubbingBuilder method(String methodName, Object arg1, Object arg2, Object arg3, Object arg4) {
        return method(methodName, inferTypes(new List<Object>{arg1, arg2, arg3, arg4}), new List<Object>{arg1, arg2, arg3, arg4});
    }
    
    /**
     * @description Stub a method with arguments (list version)
     */
    public StubbingBuilder method(String methodName, List<Object> args) {
        return method(methodName, inferTypes(args), args);
    }
    
    /**
     * @description Internal method to create StubbingBuilder with method signature
     */
    private StubbingBuilder method(String methodName, List<Type> paramTypes, List<Object> matchers) {
        MethodId methodId = new MethodId(methodName, paramTypes);
        return new StubbingBuilder(mock, methodId, matchers);
    }
    
    /**
     * @description Infer types from arguments (for matchers, use Object type)
     */
    private List<Type> inferTypes(List<Object> args) {
        List<Type> types = new List<Type>();
        if (args != null) {
            for (Object arg : args) {
                if (arg instanceof IMatcher) {
                    // Matchers are generic - we'll validate at runtime
                    types.add(Object.class);
                } else if (arg == null) {
                    types.add(Object.class);
                } else {
                    types.add(arg.getClass());
                }
            }
        }
        return types;
    }
}

