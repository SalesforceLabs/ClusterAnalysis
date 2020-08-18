public class LogFactory {
    private static Logger logger = null;
    public static Logger getLogger() {
        if (logger == null)
            logger = new ApexDebugLogger(); //TODO: return this for now, implement custom object logger later if needed
        return logger; 
    }
}