/**
 * @description Records a method invocation for verification
 */
@isTest
public class Invocation {
    public Object mock;
    public String methodName;
    public List<Object> args;
    public Long timestamp;
    
    public Invocation(Object mock, String methodName, List<Object> args) {
        this.mock = mock;
        this.methodName = methodName;
        this.args = args != null ? args : new List<Object>();
        this.timestamp = System.now().getTime();
    }
}

