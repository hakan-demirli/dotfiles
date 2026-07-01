// @version      0.1
// @author       You

(function () {
  "use strict";

  function blockElement() {
    var elementToBlock = document.querySelector("body > ytd-app");

    if (elementToBlock) {
      elementToBlock.style.display = "none";
    }
  }

  function handleMutations(mutationsList, observer) {
    blockElement();
  }

  const observerConfig = { childList: true, subtree: true };

  const observer = new MutationObserver(handleMutations);

  observer.observe(document.body, observerConfig);

  blockElement();
})();
