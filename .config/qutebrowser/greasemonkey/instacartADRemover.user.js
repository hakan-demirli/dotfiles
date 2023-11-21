// ==UserScript==
// u/name     Instacart Ad Remover
// u/description Removes all sponsored products from Instacart, so you can make quicker and better buying decisions :) created using GPT-4
// u/version  1
// u/grant    none
// u/match    *://*.instacart.com/*
// ==/UserScript==
function removeAds() {
    const allLiElements = document.getElementsByTagName('li');

    for (let i = 0; i < allLiElements.length; i++) {
        const li = allLiElements[i];

        // Find the 'sponsored' indicators
        const sponsoredIndicators = li.getElementsByClassName('css-16lshh0');

        // If this 'li' element contains a 'sponsored' indicator, remove the 'li' element
        if (sponsoredIndicators.length > 0) {
            li.parentNode.removeChild(li);
        }
    }
}

// Run the 'removeAds' function every second
setInterval(removeAds, 1000);