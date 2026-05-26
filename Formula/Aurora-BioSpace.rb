class AuroraBiospace < Formula
  desc "Launcher for the Aurora Bioscience Dashboard by Codemaster-AR"
  homepage "https://github.com/Codemaster-AR/aurora-biospace"
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v6.0.0.tar.gz"
  sha256 "50ec788be4f39e5fd2191ae529d80def168acbcd82257337897b7049c83fcf18"
  license "MIT"

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
    nested = Dir.glob("**/*.tar.gz").first
    system "tar", "-xzf", nested if nested

    package_json = Dir.glob("**/package.json").first
    odie "package.json not found" unless package_json

    app_dir = File.dirname(package_json)

    cd app_dir do
      system "npm", "install", "--omit=dev"
      libexec.install Dir["*"]
    end

    (bin/"aurora-biospace").write <<~EOS
      #!/bin/bash
      export PATH="#{Formula["node"].opt_bin}:$PATH"
      cd "#{libexec}"
      exec npx electron .
    EOS

    chmod 0755, bin/"aurora-biospace"

    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", libexec
    end
  end

  test do
    assert_predicate bin/"aurora-biospace", :exist?
    assert_predicate bin/"aurora-biospace", :executable?
  end
end
