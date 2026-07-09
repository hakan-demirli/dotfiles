// u/version  1
function removeAds() {
    const allLiElements = document.getElementsByTagName('li');

    for (let i = 0; i < allLiElements.length; i++) {
        const li = allLiElements[i];

        const sponsoredIndicators = li.getElementsByClassName('css-16lshh0');

        if (sponsoredIndicators.length > 0) {
            li.parentNode.removeChild(li);
        }
    }
}

setInterval(removeAds, 1000);
