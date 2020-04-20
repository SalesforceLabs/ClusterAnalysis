public abstract class Logger {
    public void debug(Object msg) {
        this.debug(LoggingLevel.DEBUG, msg);
    }

    public abstract void debug(LoggingLevel logLevel, Object msg);

    public void error(Object msg){
        this.debug(LoggingLevel.ERROR, msg);
    }
    
    public void error(Object msg, Exception e) {
        this.error(msg);
        this.error('Exception type caught: ' + e.getTypeName());   
        this.error('Message: ' + e.getMessage());   
        this.error('Cause: ' + e.getCause());    // returns null
        this.error('Line number: ' + e.getLineNumber());   
        this.error('Stack trace: ' + e.getStackTraceString());
    }
}
