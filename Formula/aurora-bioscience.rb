class AuroraBioscience < Formula
  desc "Launcher for the Aurora Bioscience Dashboard by Codemaster-AR."
  homepage "https://github.com/Codemaster-AR/aurora"
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v6.0.0.tar.gz"
  sha256 "7ce004fb7dac28063264fd26d81e698fefa83e5313e2c6fa7cc9673444f12ec0"
  version "6.0.0"

  # Core dependencies
  depends_on "node"
  depends_on "python@3.12"

  # --- CRITICAL: LINUX SYSTEM LIBRARIES (The .so fix) ---
  # These ensure Electron actually has its "legs" on WSL and Linux.
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
    # 1. MASTER DOUBLE UNPACK
    nested_tarball = Dir.glob("**/*.tar.gz").first
    if nested_tarball
      ohai "Detected nested tarball: #{nested_tarball}. Performing secondary extraction..."
      system "tar", "-xzf", nested_tarball
    end

    # 2. SMART RECURSIVE FOLDER DETECTION
    # We hunt specifically for the deep 'genelab' path you identified.
    package_json = Dir.glob("**/genelab/package.json").first || Dir.glob("**/package.json").first
    
    if package_json.nil?
      system "ls", "-R"
      odie "Error: Could not find package.json anywhere in the source."
    end

    app_source_dir = File.dirname(package_json)

    # 3. INSTALL DEPENDENCIES & ELECTRON
    cd app_source_dir do
      ohai "Running npm install in: #{Dir.pwd}"
      system "npm", "install", "--omit=dev"
      # Force local Electron install so the launcher can find it in .bin
      system "npm", "install", "electron", "--save-dev"
    end

    # 4. STAGING TO LIBEXEC
    libexec.install Dir["*"]

    # 5. OS-SPECIFIC ATTRIBUTE CLEANING (macOS only)
    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}" rescue nil
    end

    # 6. UNIVERSAL MASTER LAUNCHER (Python-based)
    # We find where 'genelab' actually landed inside libexec.
    final_app_path = Dir.glob("#{libexec}/**/genelab").first || libexec

    (bin/"aurora-bioscience").write <<~EOS
      #!/usr/bin/env python3
      import os, subprocess, sys, platform

      def main():
          current_os = platform.system()
          is_wsl = False
          
          # Detect WSL to apply safety flags
          try:
              if os.path.exists('/proc/version'):
                  with open('/proc/version', 'r') as f:
                      if 'microsoft' in f.read().lower():
                          is_wsl = True
          except:
              pass

          # 1. UI FEEDBACK
          msg = "Aurora Bioscience is starting..."
          if current_os == "Darwin":
              # Fixed AppleScript escaping
              cmd = f'osascript -e "display dialog \\"{msg}\\" buttons {{\\"OK\\"}} default button 1"'
              os.system(cmd)
          else:
              print(f"INFO: {msg}")

          # 2. ENVIRONMENT SETUP
          app_dir = "#{final_app_path}"
          electron_bin = os.path.join(app_dir, "node_modules", ".bin", "electron")
          
          env = os.environ.copy()
          if current_os == "Linux":
              # Tell Electron where Homebrew installed the .so libraries
              hb_lib = "#{HOMEBREW_PREFIX}/lib"
              env["LD_LIBRARY_PATH"] = hb_lib + ":" + env.get("LD_LIBRARY_PATH", "")
              if is_wsl:
                  # Force software rendering to prevent Windows 11 kernel crashes
                  env["LIBGL_ALWAYS_SOFTWARE"] = "1"
                  env["ELECTRON_DISABLE_GPU"] = "1"

          # 3. EXECUTION
          try:
              if os.path.exists(electron_bin):
                  args = [electron_bin, "."]
                  if is_wsl:
                      # Essential WSLg stability flags
                      args.extend(["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage"])
                  subprocess.run(args, cwd=app_dir, env=env)
              else:
                  subprocess.run(["npm", "start"], cwd=app_dir, env=env)
          except Exception as e:
              print(f"Error launching Aurora Bioscience: {e}")
              sys.exit(1)

      if __name__ == "__main__":
          main()
    EOS

    # 7. MAKE EXECUTABLE
    chmod 0755, bin/"aurora-bioscience"
  end

  test do
    assert_predicate bin/"aurora-bioscience", :exist?
  end
end
