/**
 * @description Plan for how a stubbed method should behave (Return, Throw, or Answer)
 */
@isTest
public class StubPlan {
    public enum PlanType {
        RETURN,
        THROW,
        ANSWER
    }
    
    public PlanType type;
    public List<Object> queue;
    public Object last;
    public Function answerFn;
    private Integer queueIndex;
    
    public StubPlan(PlanType type) {
        this.type = type;
        this.queue = new List<Object>();
        this.queueIndex = 0;
    }
    
    public void addToQueue(Object value) {
        if (queue == null) {
            queue = new List<Object>();
        }
        queue.add(value);
        last = value;
    }
    
    public Object getNext() {
        if (queue == null || queue.isEmpty()) {
            return last;
        }
        if (queueIndex < queue.size()) {
            Object result = queue[queueIndex];
            queueIndex++;
            return result;
        }
        return last; // Rollover
    }
    
    public void reset() {
        queueIndex = 0;
    }
}

