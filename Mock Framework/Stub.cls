/**
 * @description Represents a stubbed method with matchers, plan, and metadata
 */
@isTest
public class Stub {
    public MethodId methodId;
    public List<Object> matchers; // Can be literals or IMatcher instances
    public StubPlan plan;
    public Long createdAt;
    
    public Stub(MethodId methodId, List<Object> matchers, StubPlan plan) {
        this.methodId = methodId;
        this.matchers = matchers != null ? matchers : new List<Object>();
        this.plan = plan;
        this.createdAt = System.now().getTime();
    }
}

