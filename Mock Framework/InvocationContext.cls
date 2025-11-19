/**
 * @description Context passed to answer functions in thenAnswer()
 */
@isTest
public class InvocationContext {
    public String method;
    public List<Object> args;
    public Integer callIndex;
    
    public InvocationContext(String method, List<Object> args, Integer callIndex) {
        this.method = method;
        this.args = args != null ? args : new List<Object>();
        this.callIndex = callIndex;
    }
    
    /**
     * @description Get argument at index (0-based)
     */
    public Object arg(Integer index) {
        if (args != null && index >= 0 && index < args.size()) {
            return args[index];
        }
        return null;
    }
}

