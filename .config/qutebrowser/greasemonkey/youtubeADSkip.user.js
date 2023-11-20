// ==UserScript==
// @name         Auto Skip YouTube Ads
// @version      1.1.0
// @description  Speed up and skip YouTube ads automatically
// @author       jso8910
// @match        *://*.youtube.com/*
// @exclude      *://*.youtube.com/subscribe_embed?*
// ==/UserScript==
setInterval(() => {
  const btn = document.querySelector(
    ".videoAdUiSkipButton,.ytp-ad-skip-button",
  );
  if (btn) {
    btn.click();
  }
  const ad = [...document.querySelectorAll(".ad-showing")][0];
  if (ad) {
    const video = document.querySelector("video");
    video.muted = true;
    video.hidden = true;

    // This is not necessarily available right at the start
    if (video.duration != NaN) {
      video.currentTime = video.duration;
    }

    // 16 seems to be the highest rate that works, mostly this isn't needed
    video.playbackRate = 16;
  }
}, 50);

// // ==UserScript==
// // @name         Youtube Ad Skip
// // @version      0.0.4
// // @description  auto skip Youtube ads
// // @author       Adcott
// // @match        *://*.youtube.com/*
// // ==/UserScript==

// document.addEventListener(
//   "load",
//   () => {
//     try {
//       document.querySelector(".ad-showing video").currentTime = 99999;
//     } catch {}
//     try {
//       document.querySelector(".ytp-ad-skip-button").click();
//     } catch {}
//   },
//   true,
// );

// // ==UserScript==
// // @name         Auto Skip YouTube Ads
// // @version      1.0.0
// // @description  Speed up and skip YouTube ads automatically
// // @author       jso8910
// // @match        *://*.youtube.com/*
// // @exclude      *://*.youtube.com/subscribe_embed?*
// // ==/UserScript==
// setInterval(() => {
//   const btn = document.querySelector(
//     ".videoAdUiSkipButton,.ytp-ad-skip-button",
//   );
//   if (btn) {
//     btn.click();
//   }
//   const ad = [...document.querySelectorAll(".ad-showing")][0];
//   if (ad) {
//     // document.querySelector('video').playbackRate = 10;
//     const vid = document.querySelector("video");
//     vid.currentTime = vid.duration;
//   }
// }, 50);
