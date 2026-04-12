package com.luopc.platform.quantlib;

/**
 * Native library resolver for QuantLib4J.
 * Provides platform detection and native library path resolution.
 */
public class NativeLibraryResolver {

    // 平台分类器名称
    public static final String PLATFORM_LINUX_X64 = "linux-x64";
    public static final String PLATFORM_WINDOWS_X64 = "windows-x64";
    public static final String PLATFORM_MACOS_X64 = "macos-x64";
    public static final String PLATFORM_MACOS_ARM64 = "macos-arm64";

    // JNI库名称前缀
    private static final String JNI_LIB_NAME = "QuantLib4J";

    private NativeLibraryResolver() {
        // 工具类不允许实例化
    }

    /**
     * 获取当前平台的分类器标识符.
     * 用于定位对应的原生库文件路径.
     *
     * @return 平台分类器, 如 "linux-x64", "windows-x64", "macos-x64", "macos-arm64"
     * @throws UnsupportedOperationException 如果平台不支持
     */
    public static String getPlatformClassifier() {
        String osName = System.getProperty("os.name", "").toLowerCase();
        String osArch = System.getProperty("os.arch", "").toLowerCase();

        if (osName.contains("linux")) {
            return PLATFORM_LINUX_X64;
        } else if (osName.contains("windows")) {
            return PLATFORM_WINDOWS_X64;
        } else if (osName.contains("mac") || osName.contains("darwin")) {
            // macOS: 检测是x86_64还是arm64
            if (osArch.contains("aarch64") || osArch.contains("arm64")) {
                return PLATFORM_MACOS_ARM64;
            }
            return PLATFORM_MACOS_X64;
        }

        throw new UnsupportedOperationException(
                "Unsupported platform: " + osName + " (" + osArch + ")");
    }

    /**
     * 获取原生库的名称 (不含文件扩展名和前缀).
     *
     * @return 原生库名称
     */
    public static String getNativeLibraryName() {
        return JNI_LIB_NAME;
    }

    /**
     * 获取完整的原生库文件名.
     * 根据平台返回完整的动态库文件名.
     *
     * @return 动态库文件名, 如 "libQuantLib4J.so" 或 "QuantLib4J.dll"
     */
    public static String getNativeLibraryFileName() {
        String classifier = getPlatformClassifier();
        String libName = getNativeLibraryName();

        return switch (classifier) {
            case PLATFORM_LINUX_X64, PLATFORM_MACOS_X64, PLATFORM_MACOS_ARM64 ->
                    "lib" + libName + ".so";
            case PLATFORM_WINDOWS_X64 -> libName + ".dll";
            default -> throw new UnsupportedOperationException("Unknown platform: " + classifier);
        };
    }

    /**
     * 检查系统库是否可用.
     * 通过尝试在系统路径中查找库文件来检测.
     *
     * @return true 如果系统库可用, false 否则
     */
    public static boolean isSystemLibraryAvailable() {
        String libName = getNativeLibraryName();
        try {
            // 尝试直接加载, 失败则返回false
            System.loadLibrary(libName);
            return true;
        } catch (UnsatisfiedLinkError e) {
            return false;
        }
    }

    /**
     * 获取Classpath中原生库资源的路径.
     *
     * @param resourceName 资源名称
     * @return 资源路径
     */
    public static String getClasspathResourcePath(String resourceName) {
        String platform = getPlatformClassifier();
        return "/native/" + platform + "/" + resourceName;
    }

    /**
     * 检查Classpath中是否包含指定的原生库资源.
     *
     * @param resourceName 资源名称
     * @return true 如果资源存在, false 否则
     */
    public static boolean hasClasspathResource(String resourceName) {
        String path = getClasspathResourcePath(resourceName);
        return NativeLibraryResolver.class.getResource(path) != null;
    }
}
