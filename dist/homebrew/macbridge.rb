# MacBridge Studio — Homebrew formula template.
#
# Lives in a tap repo (e.g. Maverick-lab-maintaner/homebrew-tap as
# Formula/macbridge.rb) so customers install with:
#
#   brew tap maverick-lab-maintaner/tap
#   brew install macbridge
#
# On each release: update `version`, the two `url`s, and both sha256 values
# from the release's checksums.txt.
class Macbridge < Formula
  desc "Continuously verified Flutter/iOS development workspace (MacBridge Studio)"
  homepage "https://github.com/Maverick-lab-maintaner/macbridge-bootstrap"
  version "0.1.0" # x-release-please-version

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/Maverick-lab-maintaner/macbridge-bootstrap/releases/download/v#{version}/macbridge-v#{version}-darwin-arm64"
      sha256 "REPLACE_WITH_ARM64_SHA256"
    else
      url "https://github.com/Maverick-lab-maintaner/macbridge-bootstrap/releases/download/v#{version}/macbridge-v#{version}-darwin-amd64"
      sha256 "REPLACE_WITH_AMD64_SHA256"
    end
  end

  def install
    binary = Dir["macbridge-*"].first
    bin.install binary => "macbridge"
  end

  def caveats
    <<~EOS
      Provision this Mac into a verified iOS workspace:
        macbridge install --tier vanilla

      Check health anytime:
        macbridge status
        macbridge doctor

      Studio Pro (signing diagnosis, workspace, golden image, updates):
        macbridge activate MB-XXXX-XXXX-XXXX-XXXX
    EOS
  end

  test do
    assert_match "macbridge version", shell_output("#{bin}/macbridge --version")
  end
end
