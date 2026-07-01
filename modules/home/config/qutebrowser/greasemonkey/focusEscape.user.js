// @version      0.1
// @author       Your Name
(function () {
  "use strict";

  function changeFocus(event) {
    if (event.key === "Escape") {
      document.documentElement.focus();
      event.preventDefault();
    }
  }

  document.addEventListener("keydown", changeFocus);
})();
