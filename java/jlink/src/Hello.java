import java.util.logging.Logger;
import java.util.logging.Level;

public class Hello {
    private static final Logger logger = Logger.getLogger(Hello.class.getName());

    public static void main(String[] args) {
        logger.log(Level.INFO, "Starting Hello from a jlink-built minimal JRE");
        System.out.println("Hello from a custom JRE built with jlink!");
        System.out.printf("Java version: %s%n", System.getProperty("java.version"));
        System.out.printf("Java runtime: %s%n", System.getProperty("java.runtime.name"));
    }
}
