import * as d3 from "https://cdn.skypack.dev/d3";

export class BaseChart {
  constructor(containerId) {
    this.containerId = containerId;
    this.container = d3.select(containerId);
    this.resizeListenerAdded = false;
    this.tooltip = d3
      .select("body")
      .append("div")
      .attr("class", "tooltip")
      .style("position", "absolute")
      .style("background-color", "white")
      .style("border", "1px solid #ccc")
      .style("padding", "5px")
      .style("display", "none")
      .style("pointer-events", "none");
  }

  clearContainer() {
    this.container.selectAll("*").remove();
  }

  getDimensions() {
    const containerWidth = parseInt(this.container.style("width"));
    const containerHeight = parseInt(this.container.style("height"));
    const margin = { top: 20, right: 30, bottom: 80, left: 50 };
    const width = containerWidth - margin.left - margin.right;
    const height = containerHeight - margin.top - margin.bottom;
    return { width, height, margin };
  }

  addResizeListener(redrawFunction) {
    if (!this.resizeListenerAdded) {
      this.resizeListenerAdded = true;
      let resizeTimeout;
      window.addEventListener("resize", () => {
        clearTimeout(resizeTimeout);
        resizeTimeout = setTimeout(redrawFunction, 300);
      });
    }
  }

  showTooltip(event, htmlContent) {
    this.tooltip
      .style("display", "block")
      .html(htmlContent)
      .style("left", `${event.pageX + 10}px`)
      .style("top", `${event.pageY - 20}px`);
  }

  moveTooltip(event) {
    this.tooltip
      .style("left", `${event.pageX + 10}px`)
      .style("top", `${event.pageY - 20}px`);
  }

  hideTooltip() {
    this.tooltip.style("display", "none");
  }
}
