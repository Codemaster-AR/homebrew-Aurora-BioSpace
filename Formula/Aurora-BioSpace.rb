class AuroraBiospace < Formula
  desc "Launcher for the Aurora Bioscience Dashboard by Codemaster-AR."
  homepage "https://github.com/Codemaster-AR/aurora-biospace"
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v6.0.0.tar.gz"
  sha256 "50ec788be4f39e5fd2191ae529d80def168acbcd82257337897b7049c83fcf18"
  version "6.0.0"

  depends_on "node"
  depends_on "python@3.12"

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
    # 1. Expand production archive
    nested_tarball = Dir.glob("**/*.tar.gz").reject { |f| f.include?("Old/") }.first
    if nested_tarball
      system "tar", "-xzf", nested_tarball
    end

    # 2. Find package workspace branch
    package_json = Dir.glob("**/genelab/package.json").first || Dir.glob("**/package.json").first
    odie "Error: Could not find package.json anywhere in source." if package_json.nil?
    app_source_dir = File.dirname(package_json)

    # 3. Clean production workspace install
    cd app_source_dir do
      system "npm", "install", "--omit=dev"
    end

    # 4. Stage to libexec location
    cd app_source_dir do
      libexec.install Dir["*"]
    end

    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}" rescue nil
    end

    python_exe = Formula["python@3.12"].opt_bin/"python3"

    # 5. Write pure python script using standard string formatting 
    # Single quotes on the heredoc block delimiter prevent Ruby from mangling variables
    launcher_script = libexec/"aurora-launcher.py"
    launcher_script.write <<~'EOS'
      #!/usr/bin/env python3
      import os
      import subprocess
      import sys
      import platform

      CURRENT_VERSION = "v6.0.0" 
      GITHUB_REPO = "codemaster-ar/aurora"

      try:
          from rich.console import Console
          from rich.panel import Panel
          import requests
      except ImportError:
          subprocess.run([sys.executable, "-m", "pip", "install", "--user", "--quiet", "rich", "requests"])
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
                          f"[bold yellow]⚠️  A new update is available![/bold yellow]\n\n"
                          f"Current Version: [red]{CURRENT_VERSION}[/red]\n"
                          f"Latest Version:  [green]{latest_version}[ green]\n\n"
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
  / /| | / / / / ___/ __ \\/ ___/ __ `/ 
 / ___ |/ /_/ / /  / /_/ / /  / /_/ /  
/_/  |_|\__,_/_/   \____/_/   \__,_/   
          """
          console.print(aurora_art, style="bold cyan")
          console.print("    ✨ [bold italic violet]AI-powered[/bold italic violet] [bold italic sea_green2]Bioscience Dashboard[/bold italic sea_green2] ✨")
          console.print("       [grey50]powered by NASA OSDR API - Only Google Auth accepted[/grey50]\n")
          console.print(f"       [bold dim white]Local Version: {CURRENT_VERSION}[/bold dim white]\n")
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
              cmd = f'osascript -e "display dialog \"{msg}\" buttons {{\"OK\"}} default button 1"'
              os.system(cmd)
          else:
              console.print(Panel(f"[yellow]{msg}[/yellow]", title="[bold blue]System Notice[/bold blue]", border_style="blue"))
              console.print()

          # Let Python resolve its own execution folder path directly via parent tracking
          app_dir = os.path.dirname(os.path.abspath(__file__))
          
          env = os.environ.copy()
          if current_os == "Linux":
              env["LD_LIBRARY_PATH"] = os.path.dirname(app_dir) + "/lib:" + env.get("LD_LIBRARY_PATH", "")
              if is_wsl:
                  env["LIBGL_ALWAYS_SOFTWARE"] = "1"
                  env["ELECTRON_DISABLE_GPU"] = "1"

          try:
              args = ["npx", "electron", "."]
              if is_wsl:
                  args.extend(["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage"])
              console.print(f"[bold green]🚀 Launching Genelab from:[/bold green] [underline]{app_dir}[/underline]\n")
              subprocess.run(args, cwd=app_dir, env=env)
          except Exception as e:
              console.print(f"[bold red]❌ Error launching Genelab:[/bold red] {e}")
              sys.exit(1)

      if __name__ == "__main__":
          main()
    EOS

    # 6. Apply Python target interpreter rules directly
    inreplace launcher_script, "/usr/bin/env python3", python_exe.to_s
    
    # 7. Use Homebrew's native exec script writer to prevent symlink dropouts
    # This automatically registers the path correctly with the system shell profile
    bin.write_exec_script launcher_script => "aurora-biospace"
  end

  test do
    assert_predicate bin/"aurora-biospace", :exist?
  end
end
