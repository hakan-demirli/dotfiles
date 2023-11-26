// ==UserScript==
// @name         Remove Ads, Related Videos, and Elements with Text (MutationObserver)
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  Remove elements matching #items > ytd-ad-slot-renderer, #related, and specified text(s)
// @author       You
// @match        *://www.youtube.com/*
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

  // Function to remove ads and related videos
  function removeAdsAndRelated() {
    // Remove ads
    var adElements = document.querySelectorAll("#items > ytd-ad-slot-renderer");
    Array.from(adElements).forEach(function (adElement) {
      adElement.remove();
    });
    // Remove related videos
    var relatedElement = document.querySelector("#related");
    if (relatedElement) {
      relatedElement.remove();
    }
    // Remove search button
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

  // Function to be called when mutations are observed
  function handleMutations(mutationsList, observer) {
    removeElementsWithText(["Home", "Shorts"]); // Adjust the texts as needed
    removeAdsAndRelated();
  }

  // Options for the observer (which mutations to observe)
  const observerConfig = { childList: true, subtree: true };

  // Create an observer instance linked to the callback function
  const observer = new MutationObserver(handleMutations);

  // Start observing the target node for configured mutations
  observer.observe(document.body, observerConfig);

  // Perform initial removal on page load
  removeElementsWithText(["Home", "Shorts"]); // Adjust the texts as needed
  removeAdsAndRelated();
})();
