public class ApexDebugLogger extends Logger {
    public ApexDebugLogger() {

    }
    public override void debug(LoggingLevel logLevel, Object msg) {
        System.debug(logLevel, msg);
    }
}