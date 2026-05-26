class AuroraBiospace < Formula
  desc "Launcher for the Aurora Bioscience Dashboard by Codemaster-AR."
  homepage "https://github.com/Codemaster-AR/aurora-biospace"
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v6.0.0.tar.gz"
  sha256 "50ec788be4f39e5fd2191ae529d80def168acbcd82257337897b7049c83fcf18"
  version "6.0.0"

  depends_on "node"
  depends_on "python@3.12"

  # --- CRITICAL: LINUX SYSTEM LIBRARIES ---
  on_linux do
    depends_on "libx11"
    depends_on "libxkbfile"
    depends_on "libsecret"
    depends_on "nss"
    depends_on "atk"
    depends_on "at-spi2-atk"
    depends_on "cups"
    depends_on "gtk+3"
    depends_on "libdrm"
    depends_on "mesa"
    depends_on "alsa-lib"
  end

  def install
    # 1. UNPACK BOTH LAYERS CLEANLY
    nested_tarball = Dir.glob("**/*.tar.gz").reject { |f| f.include?("Old/") }.first
    if nested_tarball
      ohai "Extracting primary production package branch layer..."
      system "tar", "-xzf", nested_tarball
    end

    # 2. LOCATE ASSET TREE BRANCHES
    package_json = Dir.glob("**/genelab/package.json").first || Dir.glob("**/package.json").first
    odie "Error: Could not locate workspace package data configuration." if package_json.nil?
    
    app_source_dir = File.dirname(package_json)

    # 3. CONFIGURE PRODUCTION DEPENDENCIES
    cd app_source_dir do
      system "npm", "install", "--omit=dev"
    end

    # 4. CAPTURE EXISTING REPO LAUNCHER BEFORE WRITING RE-MAPS
    native_launcher = Dir.glob("**/genelab-launcher.py").first
    odie "Error: Could not find genelab-launcher.py in the source archive." if native_launcher.nil?

    # FIXED: Re-write the file header to guarantee a perfect Python executable interpreter path mapping
    python_exe = Formula["python@3.12"].opt_bin/"python3"
    launcher_content = File.read(native_launcher)
    
    # Strip away any existing broken or blank shebang headers if they exist
    if launcher_content.start_with?("#!")
      launcher_content = launcher_content.lines[1..].join
    end
    
    # Save the launcher with a fresh, direct path header mapping
    File.write(native_launcher, "#!#{python_exe}\n" + launcher_content)
    system "chmod", "+x", native_launcher

    # 5. MOVE RUNTIME DIRECTORY TREE TO CLEAN ISOLATED LIBEXEC
    outer_workspace = File.dirname(native_launcher)
    cd outer_workspace do
      libexec.install Dir["*"]
    end

    # 6. CLEAR DESKTOP APP QUARANTINE FLAGS (macOS only)
    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}" rescue nil
    end

    # 7. MAP GLOBAL EXECUTABLE VIA HOMEBREW NATIVE TRACKING PATHS
    bin.write_exec_script (libexec/"genelab-launcher.py")
    mv bin/"genelab-launcher.py", bin/"aurora-biospace"
  end

  test do
    assert_predicate bin/"aurora-biospace", :exist?
  end
end
