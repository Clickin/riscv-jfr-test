import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Pure JDK reproducer, no JNI and no third-party code.
 *
 * <p>Run with a single carrier thread:
 * -Djdk.virtualThreadScheduler.parallelism=1 -Djdk.virtualThreadScheduler.maxPoolSize=1
 *
 * <p>A virtual thread sleeps inside two nested synchronized blocks while an independent virtual
 * thread must make progress on the same carrier (JEP 491). Each round freezes and thaws
 * continuations many times.
 */
public class PureJavaVt {
    public static void main(String[] args) throws Exception {
        int rounds = args.length > 0 ? Integer.parseInt(args[0]) : 50;
        for (int n = 0; n < rounds; n++) {
            Object outer = new Object(), inner = new Object();
            AtomicBoolean stop = new AtomicBoolean();
            AtomicInteger entered = new AtomicInteger();
            AtomicBoolean done = new AtomicBoolean();
            Thread target =
                    Thread.ofVirtual()
                            .name("pure-vt-target")
                            .unstarted(
                                    () -> {
                                        synchronized (outer) {
                                            synchronized (inner) {
                                                try {
                                                    while (!stop.get()) {
                                                        entered.incrementAndGet();
                                                        Thread.sleep(2);
                                                    }
                                                } catch (InterruptedException e) {
                                                    throw new AssertionError(e);
                                                }
                                            }
                                        }
                                    });
            target.start();
            long deadline = System.nanoTime() + 20_000_000_000L;
            while (entered.get() == 0) {
                if (System.nanoTime() > deadline) throw new AssertionError("wait not entered");
                Thread.sleep(5);
            }
            Thread independent =
                    Thread.ofVirtual()
                            .name("pure-vt-independent")
                            .unstarted(
                                    () -> {
                                        try {
                                            for (int i = 0; i < 5; i++) Thread.sleep(20);
                                            if (!stop.get()) done.set(true);
                                        } catch (InterruptedException e) {
                                            throw new AssertionError(e);
                                        }
                                    });
            independent.start();
            independent.join(10_000);
            if (!done.get()) throw new AssertionError("independent progress missing");
            stop.set(true);
            target.join(10_000);
            if (target.isAlive()) throw new AssertionError("target did not stop");
            if (n % 20 == 0) System.out.println("PURE-PROGRESS=" + n);
        }
        System.out.println("PURE-PASS rounds=" + rounds);
    }
}
