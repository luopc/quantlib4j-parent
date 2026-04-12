package com.luopc.platform.quantlib;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * QuantLib4J 原生库加载器.
 * 提供跨平台的JNI原生库自动加载功能.
 *
 * <p>支持的平台:</p>
 * <ul>
 *   <li>Linux x86_64 (glibc 2.17+)</li>
 *   <li>Windows x86_64</li>
 *   <li>macOS x86_64 / ARM64</li>
 * </ul>
 *
 * <p>使用示例:</p>
 * <pre>{@code
 * // 在应用启动时调用一次
 * QuantLibLoader.load();
 *
 * // 或者使用便捷方法, 加载并验证
 * QuantLibLoader.loadOrThrow();
 * }</pre>
 */
public class QuantLibLoader {

    private static final Logger log = LoggerFactory.getLogger(QuantLibLoader.class);

    // 记录是否已加载, 防止重复加载
    private static final AtomicBoolean loaded = new AtomicBoolean(false);

    // 临时目录前缀
    private static final String TEMP_DIR_PREFIX = "quantlib4j-";

    // 原生库文件名
    private static final String NATIVE_LIBRARY_NAME = NativeLibraryResolver.getNativeLibraryName();

    private QuantLibLoader() {
        // 工具类不允许实例化
    }

    /**
     * 加载QuantLib4J原生库.
     *
     * <p>此方法会按以下顺序尝试加载原生库:</p>
     * <ol>
     *   <li>检查系统库路径 (如 LD_LIBRARY_PATH)</li>
     *   <li>检查Classpath中的native资源</li>
     *   <li>提取到临时目录并加载</li>
     * </ol>
     *
     * <p>此方法是幂等的: 多次调用不会有额外效果.</p>
     *
     * @return true 如果加载成功, false 如果库已加载或加载成功
     */
    public static boolean load() {
        if (loaded.get()) {
            log.debug("QuantLib4J native library already loaded");
            return true;
        }

        synchronized (QuantLibLoader.class) {
            // 双重检查锁定
            if (loaded.get()) {
                return true;
            }

            String platform = NativeLibraryResolver.getPlatformClassifier();
            log.info("Loading QuantLib4J native library for platform: {}", platform);

            // 尝试按顺序加载
            if (tryLoadFromSystemPath()) {
                loaded.set(true);
                return true;
            }

            if (tryLoadFromClasspath()) {
                loaded.set(true);
                return true;
            }

            log.error("Failed to load QuantLib4J native library");
            return false;
        }
    }

    /**
     * 加载原生库, 失败时抛出异常.
     *
     * @throws UnsatisfiedLinkError 如果无法加载原生库
     */
    public static void loadOrThrow() {
        if (!load()) {
            String platform = NativeLibraryResolver.getPlatformClassifier();
            throw new UnsatisfiedLinkError(buildErrorMessage(platform));
        }
    }

    /**
     * 检查原生库是否已加载.
     *
     * @return true 如果已加载
     */
    public static boolean isLoaded() {
        return loaded.get();
    }

    /**
     * 尝试从系统路径加载原生库.
     *
     * @return true 如果加载成功
     */
    private static boolean tryLoadFromSystemPath() {
        try {
            log.debug("Attempting to load {} from system library path", NATIVE_LIBRARY_NAME);
            System.loadLibrary(NATIVE_LIBRARY_NAME);
            log.info("Successfully loaded {} from system library path", NATIVE_LIBRARY_NAME);
            return true;
        } catch (UnsatisfiedLinkError e) {
            log.debug("Library not found in system path: {}", e.getMessage());
            return false;
        }
    }

    /**
     * 尝试从Classpath资源加载原生库.
     *
     * @return true 如果加载成功
     */
    private static boolean tryLoadFromClasspath() {
        String platform = NativeLibraryResolver.getPlatformClassifier();
        String libraryFileName = NativeLibraryResolver.getNativeLibraryFileName();
        String resourcePath = "/native/" + platform + "/" + libraryFileName;

        log.debug("Looking for native library in classpath: {}", resourcePath);

        try (InputStream is = QuantLibLoader.class.getResourceAsStream(resourcePath)) {
            if (is == null) {
                log.debug("Native library not found in classpath at {}", resourcePath);
                return false;
            }

            // 创建临时目录并提取库文件
            Path tempDir = createTempDirectory();
            Path extractedLibrary = tempDir.resolve(libraryFileName);

            log.info("Extracting native library to: {}", extractedLibrary);
            Files.copy(is, extractedLibrary, StandardCopyOption.REPLACE_EXISTING);

            // 确保文件可执行 (Unix系统)
            setExecutable(extractedLibrary);

            // 加载提取的库
            System.load(extractedLibrary.toAbsolutePath().toString());
            log.info("Successfully loaded native library from classpath");

            // 注册清理钩子 (可选)
            registerCleanupHook(tempDir);

            return true;

        } catch (IOException e) {
            log.error("Failed to extract native library from classpath: {}", e.getMessage());
            return false;
        } catch (UnsatisfiedLinkError e) {
            log.error("Failed to load extracted native library: {}", e.getMessage());
            return false;
        }
    }

    /**
     * 创建临时目录用于存放原生库.
     *
     * @return 临时目录路径
     * @throws IOException 如果创建失败
     */
    private static Path createTempDirectory() throws IOException {
        Path tempDir = Files.createTempDirectory(TEMP_DIR_PREFIX);
        // 设置目录删除钩子, JVM退出时清理
        tempDir.toFile().deleteOnExit();
        return tempDir;
    }

    /**
     * 设置文件为可执行 (Unix系统).
     *
     * @param path 文件路径
     */
    private static void setExecutable(Path path) {
        File file = path.toFile();
        boolean success = file.setExecutable(true, false);
        if (success) {
            log.debug("Set executable permission on: {}", path);
        } else {
            log.warn("Failed to set executable permission on: {}", path);
        }
    }

    /**
     * 注册JVM退出时的清理钩子.
     *
     * @param tempDir 临时目录
     */
    private static void registerCleanupHook(Path tempDir) {
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            try {
                // 删除临时目录中的所有文件
                Files.walk(tempDir)
                        .sorted((a, b) -> -a.compareTo(b)) // 逆序, 先删文件再删目录
                        .forEach(path -> {
                            try {
                                Files.deleteIfExists(path);
                            } catch (IOException e) {
                                log.debug("Failed to delete temp file: {}", path);
                            }
                        });
                log.debug("Cleaned up temp directory: {}", tempDir);
            } catch (IOException e) {
                log.debug("Failed to cleanup temp directory: {}", tempDir);
            }
        }, "QuantLib4J-Cleanup"));
    }

    /**
     * 构建错误消息.
     *
     * @param platform 检测到的平台
     * @return 详细的错误消息
     */
    private static String buildErrorMessage(String platform) {
        StringBuilder sb = new StringBuilder();
        sb.append("Failed to load QuantLib4J native library for platform: ").append(platform).append("\n\n");
        sb.append("Troubleshooting steps:\n");
        sb.append("1. Ensure you have the correct native library for your platform\n");
        sb.append("2. Add the library path to LD_LIBRARY_PATH (Linux) or PATH (Windows)\n");
        sb.append("3. Or include the native library JAR dependency for your platform:\n");
        sb.append("   - com.luopc.platform.quantlib:quantlib4j-native-linux\n");
        sb.append("   - com.luopc.platform.quantlib:quantlib4j-native-windows\n");
        sb.append("   - com.luopc.platform.quantlib:quantlib4j-native-macos\n");
        sb.append("\nFor manual loading, use: System.load(\"/path/to/libQuantLib4J.so\")");
        return sb.toString();
    }

    /**
     * 获取当前平台的分类器.
     * 便捷方法.
     *
     * @return 平台分类器
     */
    public static String getPlatform() {
        return NativeLibraryResolver.getPlatformClassifier();
    }

    /**
     * 获取原生库名称.
     * 便捷方法.
     *
     * @return 原生库名称
     */
    public static String getLibraryName() {
        return NATIVE_LIBRARY_NAME;
    }
}
