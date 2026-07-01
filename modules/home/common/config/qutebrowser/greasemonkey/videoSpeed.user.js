// @version     1.1.0.0
// @author      https://sky-bro.github.io      https://sapioit.com
// @license     GPL-2.0-only; http://www.gnu.org/licenses/gpl-2.0.txt

(function () {
  "use strict";
  function setPlaybackRate(player, rate) {
    if (rate < 0.1) rate = 0.1;
    else if (rate > 40) rate = 40;
    player.playbackRate = rate;
    console.log("playing in %sx", rate.toFixed(1));
  }

  window.addEventListener("keypress", function (event) {
    var player = document.querySelector("video");
    var curRate = Number(player.playbackRate);
    if (event.key == "s") {
      console.log("s pressed");
      setPlaybackRate(player, curRate - 0.25);
    } else if (event.key == "d") {
      console.log("d pressed");
      setPlaybackRate(player, curRate + 0.25);
    } else if (event.key == "r") {
      console.log("r pressed");
      setPlaybackRate(player, 1);
    }
  });
})();
