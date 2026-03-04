document.addEventListener("DOMContentLoaded", () => {
  const clarityReady = () => typeof window.clarity === "function";

  const trackEvent = (name) => {
    if (clarityReady()) {
      window.clarity("event", name);
    }
  };

  const setTag = (key, value) => {
    if (clarityReady()) {
      window.clarity("set", key, value);
    }
  };

  const setConsent = (adStorage, analyticsStorage) => {
    if (clarityReady()) {
      window.clarity("consentv2", {
        ad_Storage: adStorage,
        analytics_Storage: analyticsStorage
      });
    }
  };

  const body = document.body;
  if (body) {
    const page = body.getAttribute("data-clarity-page");
    const locale = body.getAttribute("data-clarity-locale");
    if (page) {
      setTag("page", page);
    }
    if (locale) {
      setTag("locale", locale);
    }
  }

  document.addEventListener("click", (event) => {
    const targetNode = event.target;
    if (!(targetNode instanceof Element)) {
      return;
    }

    const trackedNode = targetNode.closest("[data-clarity-event]");
    if (!trackedNode) {
      return;
    }

    const eventName = trackedNode.getAttribute("data-clarity-event");
    if (eventName) {
      trackEvent(eventName);
    }
  });

  window.setClarityConsent = setConsent;
});
