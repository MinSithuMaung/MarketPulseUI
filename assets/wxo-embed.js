/**
 * Single embed loader per page.
 * Expects `window.WXO_PAGE_CONFIG` to be defined before this script is loaded.
 */
(function(){
  const cfg = window.WXO_PAGE_CONFIG;
  if(!cfg){
    console.error("WXO_PAGE_CONFIG is missing.");
    return;
  }

  const mountEl = document.getElementById(cfg.chatMountId || "chatMount");
  if(!mountEl){
    console.error("Chat mount element not found.");
    return;
  }

  window.wxOConfiguration = {
    orchestrationID: cfg.orchestrationID,
    hostURL: cfg.hostURL,
    rootElementID: "root",
    deploymentPlatform: cfg.deploymentPlatform || "ibmcloud",
    crn: cfg.crn,
    chatOptions: {
      agentId: cfg.agentId,
      agentEnvironmentId: cfg.agentEnvironmentId
    },
    defaultLocale: cfg.defaultLocale || "en",
    header: {
      showResetButton: cfg.showResetButton ?? true,
      showAiDisclaimer: cfg.showAiDisclaimer ?? true
    },
    style: cfg.style || {},
    layout: {
      form: "custom",
      showOrchestrateHeader: cfg.showOrchestrateHeader ?? true,
      customElement: mountEl
    }
  };

  setTimeout(function () {
    const script = document.createElement("script");
    script.src = `${window.wxOConfiguration.hostURL}/wxochat/wxoLoader.js?embed=true`;
    script.addEventListener("load", function () {
      wxoLoader.init();
    });
    document.head.appendChild(script);
  }, 0);
})();
