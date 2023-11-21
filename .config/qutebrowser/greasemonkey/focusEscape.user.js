// ==UserScript==
// @name         Change Focus to Root on Esc Key
// @namespace    http://your.namespace.com
// @version      0.1
// @description  Change focus to the root of the page when pressing the "Esc" key
// @author       Your Name
// @match        *://*/*
// @grant        none
// ==/UserScript==
(function () {
  "use strict";

  // Function to change focus to the root of the page when the "Esc" key is pressed
  function changeFocus(event) {
    if (event.key === "Escape") {
      document.documentElement.focus();
      event.preventDefault(); // Prevent the default "Esc" key behavior (e.g., closing modals)
    }
  }

  // Add an event listener to the document to capture key presses
  document.addEventListener("keydown", changeFocus);
})();
