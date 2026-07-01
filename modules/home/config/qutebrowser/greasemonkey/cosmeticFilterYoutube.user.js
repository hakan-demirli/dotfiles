// @version      0.1
// @author       You

(function () {
  "use strict";

  function removeElementsWithText(texts) {
    var elementsToRemove = document.querySelectorAll(
      "#items > ytd-guide-entry-renderer",
    );

    Array.from(elementsToRemove).forEach(function (element) {
      texts.forEach(function (text) {
        if (element.innerText.includes(text)) {
          element.remove();
        }
      });
    });
  }

  function removeAdsAndRelated() {
    var adElements = document.querySelectorAll("#items > ytd-ad-slot-renderer");
    Array.from(adElements).forEach(function (adElement) {
      adElement.remove();
    });
    var relatedElement = document.querySelector("#related");
    if (relatedElement) {
      relatedElement.remove();
    }
    var relatedElement = document.querySelector("#voice-search-button");
    if (relatedElement) {
      relatedElement.remove();
    }
    var relatedElement = document.querySelector(
      "#sections > ytd-guide-section-renderer:nth-child(4)",
    );
    if (relatedElement) {
      relatedElement.remove();
    }
  }

  function handleMutations(mutationsList, observer) {
    removeElementsWithText(["Home", "Shorts"]);
    removeAdsAndRelated();
  }

  const observerConfig = { childList: true, subtree: true };

  const observer = new MutationObserver(handleMutations);

  observer.observe(document.body, observerConfig);

  removeElementsWithText(["Home", "Shorts"]);
  removeAdsAndRelated();
})();
