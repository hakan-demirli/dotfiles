// ==UserScript==
// @name         Block Element on YouTube Homepage (MutationObserver)
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  Block the element body > ytd-app on YouTube homepage
// @author       You
// @match        *://www.youtube.com/
// @grant        none
// ==/UserScript==

(function () {
  "use strict";

  // Function to block the specified element
  function blockElement() {
    var elementToBlock = document.querySelector("body > ytd-app");

    if (elementToBlock) {
      elementToBlock.style.display = "none"; // Hide the element
    }
  }

  // Function to be called when mutations are observed
  function handleMutations(mutationsList, observer) {
    blockElement();
  }

  // Options for the observer (which mutations to observe)
  const observerConfig = { childList: true, subtree: true };

  // Create an observer instance linked to the callback function
  const observer = new MutationObserver(handleMutations);

  // Start observing the target node for configured mutations
  observer.observe(document.body, observerConfig);

  // Perform initial blocking on page load
  blockElement();
})();
