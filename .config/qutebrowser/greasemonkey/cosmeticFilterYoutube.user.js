// ==UserScript==
// @name         Remove Elements with Text (MutationObserver)
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  Remove elements within #items if they contain specified text(s)
// @author       You
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function () {
  "use strict";

  // Function to remove elements within #items if they contain specified text
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

  let blist = ["Home", "Shorts"];

  // Function to be called when mutations are observed
  function handleMutations(mutationsList, observer) {
    removeElementsWithText(blist); // Adjust the texts as needed
  }

  // Options for the observer (which mutations to observe)
  const observerConfig = { childList: true, subtree: true };

  // Create an observer instance linked to the callback function
  const observer = new MutationObserver(handleMutations);

  // Start observing the target node for configured mutations
  observer.observe(document.body, observerConfig);

  // Perform initial removal on page load
  removeElementsWithText(blist); // Adjust the texts as needed
})();
