// ==UserScript==
// @name Adds scrolling JS that can be used within QB to do smarter scrolling
// @qute-js-world jseval
// @run-at document-start
// ==/UserScript==
unsafeWindow.scrollHelper = (() => {
  const scrollableElemOverflowTypes = ["auto", "scroll"];

  const getFocusedWindow = (nextElem) => {
    if (nextElem === null) return null;
    if (nextElem === undefined)
      return getFocusedWindow(window.document.activeElement ?? null);
    return (
      getFocusedWindow(nextElem.contentDocument?.activeElement ?? null) ??
      nextElem.ownerDocument?.defaultView ??
      null
    );
  };

  const getScrollMaxY = ({ document: { documentElement } }) =>
    documentElement.scrollHeight - documentElement.clientHeight;

  const getWindowVisibleArea = ({ document: { documentElement } }) =>
    documentElement.clientHeight * documentElement.clientWidth;

  const findVertScrollableWindow = () => {
    const focusedWindow = getFocusedWindow() ?? window;
    if (getScrollMaxY(focusedWindow) > 0) return focusedWindow;
    if (getScrollMaxY(window) > 0) return window;

    return (
      Array.from(window.frames)
        .sort((x, y) => getWindowVisibleArea(y) - getWindowVisibleArea(x))
        .find((frame) => getScrollMaxY(frame) > 0) ?? window
    );
  };

  const getScrollTopMax = (elem) => elem.scrollHeight - elem.clientHeight;
  const isElementVertScrollable = (element) =>
    element.clientHeight !== 0 &&
    scrollableElemOverflowTypes.includes(getComputedStyle(element).overflowY);

  const findVertScrollableAncestor = (delta, nextElem) => {
    if (!(nextElem?.parentNode instanceof Element)) return nextElem;

    if (isElementVertScrollable(nextElem)) {
      if (delta < 0 && nextElem.scrollTop > 0) return nextElem;
      if (delta > 0 && nextElem.scrollTop < getScrollTopMax(nextElem))
        return nextElem;
      if (delta === 0 && getScrollTopMax(nextElem) > 0) return nextElem;
    }

    return findVertScrollableAncestor(delta, nextElem.parentNode);
  };

  const getSelectionElem = () => {
    const selection = getFocusedWindow().getSelection();
    return selection.rangeCount !== 0
      ? selection.getRangeAt(0).startContainer
      : null;
  };

  const getParentIfNotElement = (maybeElement) =>
    maybeElement instanceof Element ? maybeElement : maybeElement?.parentNode;

  const findVertScrollable = (delta = 0) => {
    const selectionScrollableElem = findVertScrollableAncestor(
      delta,
      getParentIfNotElement(getSelectionElem()),
    );
    if (selectionScrollableElem instanceof Element)
      return selectionScrollableElem;

    const scrollableDoc = findVertScrollableWindow().document;
    const scrollableElem =
      scrollableDoc.body ||
      scrollableDoc.getElementsByTagName("body")[0] ||
      scrollableDoc.documentElement;
    return findVertScrollableAncestor(
      delta,
      getParentIfNotElement(scrollableElem),
    );
  };

  return {
    scrollTo: (position) => findVertScrollable().scrollTo({ top: position }),
    scrollToPercent: (percentPosition) => {
      const scrollElement = findVertScrollable();
      const paneHeight = scrollElement.scrollHeight;
      scrollElement.scrollTo({ top: (percentPosition / 100) * paneHeight });
    },
    scrollBy: (delta) =>
      findVertScrollable(delta).scrollBy({ top: delta, behavior: "smooth" }),
    scrollPage: (pages) => {
      const fakeDelta = pages < 0 ? -10 : 10;
      const scrollElement = findVertScrollable(fakeDelta);
      const pageHeight = scrollElement.clientHeight;
      scrollElement.scrollBy({ top: pageHeight * pages });
    },
  };
})();
