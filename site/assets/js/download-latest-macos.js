document.addEventListener("DOMContentLoaded", () => {
  const fallbackUrl = "https://github.com/parrotnavy/anti-adhd/releases";
  const latestReleaseApiUrl =
    "https://api.github.com/repos/parrotnavy/anti-adhd/releases/latest";
  const assetNameRegex = /^AntiADHD-(\d+\.\d+\.\d+)\.dmg$/;
  const pageLanguage = document.documentElement.lang?.toLowerCase() || "";
  const fallbackSubLabel =
    pageLanguage === "ko" ? "릴리스 페이지에서 다운로드" : "GitHub Releases fallback";

  const links = document.querySelectorAll('[data-download-os="macos"]');

  if (links.length === 0) {
    return;
  }

  const applyFallback = () => {
    links.forEach((link) => {
      if (link instanceof HTMLAnchorElement) {
        link.href = link.getAttribute("href") || fallbackUrl;
        link.rel = "noopener";
      }

      const subLabel = link.querySelector(".btn-sub");
      if (subLabel) {
        subLabel.textContent = fallbackSubLabel;
      }
    });
  };

  const resolveLatestMacDmg = async () => {
    const controller = new AbortController();
    const timeoutId = window.setTimeout(() => controller.abort(), 4500);

    try {
      const response = await fetch(latestReleaseApiUrl, {
        method: "GET",
        headers: {
          Accept: "application/vnd.github+json",
        },
        cache: "no-store",
        signal: controller.signal,
      });

      if (!response.ok) {
        throw new Error(`GitHub API status ${response.status}`);
      }

      const release = await response.json();
      const assets = Array.isArray(release?.assets) ? release.assets : [];

      const matchingAsset = assets.find((asset) => {
        if (!asset || typeof asset.name !== "string") {
          return false;
        }

        return assetNameRegex.test(asset.name);
      });

      if (!matchingAsset) {
        throw new Error("No matching DMG asset in latest release");
      }

      const match = String(matchingAsset.name).match(assetNameRegex);
      const version = match ? match[1] : null;
      const url = matchingAsset.browser_download_url;

      if (typeof url !== "string" || url.length === 0) {
        throw new Error("Missing browser_download_url for DMG asset");
      }

      return { url, version };
    } finally {
      window.clearTimeout(timeoutId);
    }
  };

  applyFallback();

  resolveLatestMacDmg()
    .then(({ url, version }) => {
      links.forEach((link) => {
        if (link instanceof HTMLAnchorElement) {
          link.href = url;
          link.rel = "noopener";
        }

        const subLabel = link.querySelector(".btn-sub");
        if (subLabel && version) {
          subLabel.textContent = `v${version}`;
        }
      });
    })
    .catch(() => {
      applyFallback();
    });
});
