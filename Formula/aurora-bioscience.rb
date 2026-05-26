class AuroraBioscience < Formula
  desc "Launcher for the Aurora Bioscience Dashboard by Codemaster-AR."
  homepage "https://github.com/Codemaster-AR/aurora"
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v6.0.0.tar.gz"
  sha256 "50ec788be4f39e5fd2191ae529d80def168acbcd82257337897b7049c83fcf18"
  version "6.0.0"

  # Core dependencies - Homebrew will download these if the user lacks them
  depends_on "node"
  depends_on "python@3.12"

  # --- CRITICAL: LINUX SYSTEM LIBRARIES (The .so fix) ---
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
    package_json = Dir.glob("**/genelab/package.json").first || Dir.glob("**/package.json").first
    
    if package_json.nil?
      odie "Error: Could not find package.json anywhere in the source."
    end

    app_source_dir = File.dirname(package_json)

    # 3. INSTALL DEPENDENCIES & ELECTRON
    cd app_source_dir do
      ohai "Running npm install in: #{Dir.pwd}"
      system "npm", "install", "--omit=dev"
      system "npm", "install", "electron", "--save-dev"
    end

    # 4. STAGING TO LIBEXEC
    libexec.install Dir["*"]

    # 5. OS-SPECIFIC ATTRIBUTE CLEANING (macOS only)
    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}" rescue nil
    end

    # 6. UNIVERSAL MASTER LAUNCHER (Python-based)
    final_app_path = Dir.glob("#{libexec}/**/genelab").first || libexec

    # Determine Homebrew's specific Python path
    python_exe = Formula["python@3.12"].opt_bin/"python3"

    # Write the script text to a physical workspace file instead of direct bin piping
    launcher_file = buildpath/"aurora-bioscience"
    launcher_file.write <<~EOS
      #!/usr/bin/env python3
      import os
      import subprocess
      import sys
      import platform

      CURRENT_VERSION = "v6.0.0" 
      GITHUB_REPO = "codemaster-ar/aurora"

      # Auto-install rich and requests to the execution path if missing
      try:
          from rich.console import Console
          from rich.panel import Panel
          import requests
      except ImportError:
          # If modules are missing in homebrew's python space, install them dynamically
          subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "rich", "requests"])
          from rich.console import Console
          from rich.panel import Panel
          import requests

      console = Console()

      def check_for_updates():
          url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"
          try:
              response = requests.get(url, timeout=1.5)
              if response.status_code == 200:
                  latest_release = response.json()
                  latest_version = latest_release.get("tag_name", "").strip()
                  if latest_version and latest_version != CURRENT_VERSION:
                      console.print(Panel(
                          f"[bold yellow]⚠️  A new update is available![/bold yellow]\\n\\n"
                          f"Current Version: [red]{CURRENT_VERSION}[/red]\\n"
                          f"Latest Version:  [green]{latest_version}[/green]\\n\\n"
                          f"Download it here: [underline cyan]https://github.com/{GITHUB_REPO}/releases[/underline cyan]",
                          title="[bold yellow]Update Notice[/bold yellow]",
                          border_style="yellow"
                      ))
                      console.print()
          except:
              pass

      def display_header():
          aurora_art = r"""
    ___                                 
   /   |  __  ___________  __________ _ 
  / /| | / / / / ___/ __ \/ ___/ __ `/ 
 / ___ |/ /_/ / /  / /_/ / /  / /_/ /  
/_/  |_|\__,_/_/   \____/_/   \__,_/   
          """
          console.print(aurora_art, style="bold cyan")
          console.print("    ✨ [bold italic violet]AI-powered[/bold italic violet] [bold italic sea_green2]Bioscience Dashboard[/bold italic sea_green2] ✨")
          console.print("       [grey50]powered by NASA OSDR API - Only Google Auth accepted[/grey50]\\n")
          console.print(f"       [bold dim white]Local Version: {CURRENT_VERSION}[/bold dim white]\\n")
          console.print("[bold magenta]=[/bold magenta]" * 50)
          console.print()

      def main():
          display_header()
          check_for_updates()

          msg = "Created by Codemaster-AR: There could be an error. If there is, just press OK. Additionally, if you face any issues, please contact codemaster.ar@Gmail.com"
          current_os = platform.system()
          is_wsl = False
          
          try:
              if os.path.exists('/proc/version'):
                  with open('/proc/version', 'r') as f:
                      if 'microsoft' in f.read().lower():
                          is_wsl = True
          except:
              pass

          if current_os == "Darwin":
              cmd = f'osascript -e "display dialog \\"{msg}\\" buttons {{\\"OK\\"}} default button 1"'
              os.system(cmd)
          else:
              console.print(Panel(f"[yellow]{msg}[/yellow]", title="[bold blue]System Notice[/bold blue]", border_style="blue"))
              console.print()

          app_dir = "#{final_app_path}"
          electron_bin = os.path.join(app_dir, "node_modules", ".bin", "electron")
          
          env = os.environ.copy()
          if current_os == "Linux":
              hb_lib = "#{HOMEBREW_PREFIX}/lib"
              env["LD_LIBRARY_PATH"] = hb_lib + ":" + env.get("LD_LIBRARY_PATH", "")
              if is_wsl:
                  env["LIBGL_ALWAYS_SOFTWARE"] = "1"
                  env["ELECTRON_DISABLE_GPU"] = "1"

          try:
              if os.path.exists(electron_bin):
                  args = [electron_bin, "."]
                  if is_wsl:
                      args.extend(["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage"])
                  console.print(f"[bold green]🚀 Launching Genelab from:[/bold green] [underline]{app_dir}[/underline]\\n")
                  subprocess.run(args, cwd=app_dir, env=env)
              else:
                  console.print(f"[bold green]🚀 Launching Genelab via npm from:[/bold green] [underline]{app_dir}[/underline]\\n")
                  subprocess.run(["npm", "start"], cwd=app_dir, env=env)
          except Exception as e:
              console.print(f"[bold red]❌ Error launching Genelab:[/bold red] {e}")
              sys.exit(1)

      if __name__ == "__main__":
          main()
    EOS

    # 7. CHMOD AND DEPLOY SECURELY
    chmod 0755, launcher_file
    bin.install launcher_file

    # Explicitly enforce Homebrew environment shebang injection
    rewrite_shebang Language::Python.shebang_header(python_exe), bin/"aurora-bioscience"
  end

  test do
    assert_predicate bin/"aurora-bioscience", :exist?
  end
end
