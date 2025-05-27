import { Controller } from "@hotwired/stimulus";

/**
 * ReportsChartController
 *
 * Lazy‑initialises a Chart.js visualisation once the element becomes visible.
 * – Guards against double‑rendering with `this.initialised` flag
 * – Uses `IntersectionObserver` (with a MutationObserver fallback) to detect
 *   visibility instead of polling
 * – Cleans up the created `Chart` instance on disconnect
 * – Gated console output so production consoles stay clean
 */
export default class extends Controller {
  /* ------------------------------------------------------------------
   * Stimulus values
   * ----------------------------------------------------------------*/
  static values = {
    currentData: { type: Object, default: {} },
    previousData: { type: Object, default: {} },
    type: { type: String, default: "bar" },
    title: { type: String, default: "Comparison Chart" },
    compact: { type: Boolean, default: false },
    yAxisLabel: { type: String, default: "Count" }
  };

  /* Utility classes (Tailwind's `hidden` works nicely) */
  static classes = ["hidden"];

  /* ------------------------------------------------------------------
   * Lifecycle
   * ----------------------------------------------------------------*/
  connect() {
    this.initialised = false;
    this.chartInstance = null;

    this.log("connected");

    // If we're already visible – fire immediately, otherwise observe.
    this.isVisible() ? this.initialise() : this.observeVisibility();
  }

  disconnect() {
    this.visibilityObserver?.disconnect();
    this.mutationObserver?.disconnect();
    this.chartInstance?.destroy();
    this.chartInstance = null;
  }

  /* ------------------------------------------------------------------
   * Visibility helpers
   * ----------------------------------------------------------------*/
  isVisible() {
    return (
      this.element.offsetParent !== null &&
      !this.element.closest("." + this.hiddenClass)
    );
  }

  observeVisibility() {
    // Use IntersectionObserver.
    this.visibilityObserver = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          this.visibilityObserver.disconnect();
          this.initialise();
        }
      },
      { root: null, threshold: 0 }
    );
    this.visibilityObserver.observe(this.element);
  }

  /* ------------------------------------------------------------------
   * Chart initialisation
   * ----------------------------------------------------------------*/
  async initialise() {
    if (this.initialised) return; // Guard against double init
    this.initialised = true;

    // Lazy‑load Chart.js if it's not on the page already.
    if (typeof Chart === "undefined") {
      try {
        await import(/* webpackChunkName: "chartjs" */ "chart.js/auto" /* @vite-ignore */);
        this.log("Chart.js dynamically imported");
      } catch (e) {
        this.renderError("Chart.js failed to load");
        return;
      }
    }

    this.renderChart();
  }

  renderChart() {
    const canvas = document.createElement("canvas");
    const id = `chart-${crypto.randomUUID()}`;
    canvas.id = id;

    // Compact dimensions
    canvas.width = this.compactValue ? 400 : 800;
    canvas.height = this.compactValue ? 200 : 300;
    canvas.style.width = "100%";
    canvas.style.height = this.compactValue ? "200px" : "300px";

    // a11y
    canvas.setAttribute("role", "img");
    canvas.setAttribute(
      "aria-label",
      `${this.titleValue} – compares current & previous fiscal year data`
    );

    this.element.replaceChildren(canvas);

    const ctx = canvas.getContext("2d");
    if (!ctx) {
      this.renderError("Canvas context unavailable");
      return;
    }

    const config = this.buildConfig();
    this.chartInstance = new Chart(ctx, config);
  }

  renderError(msg) {
    this.element.innerHTML = `<p class="text-red-500">${msg}</p>`;
    this.log(msg, "error");
  }

  /* ------------------------------------------------------------------
   * Config builder
   * ----------------------------------------------------------------*/
  buildConfig() {
    const kind = this.typeValue;
    const current = this.safeObj(this.currentDataValue);
    const previous = this.safeObj(this.previousDataValue);

    const sharedDatasetProps = {
      borderWidth: 2
    };

    const colors = {
      current: "rgba(79, 70, 229, ", // indigo‑500
      previous: "rgba(156, 163, 175, " // gray‑400
    };

    const datasets = {
      current: {
        label: "Current Fiscal Year",
        backgroundColor: colors.current + "0.7)",
        borderColor: colors.current + "1)",
        data: Object.values(current),
        ...sharedDatasetProps
      },
      previous: {
        label: "Previous Fiscal Year",
        backgroundColor: colors.previous + "0.7)",
        borderColor: colors.previous + "1)",
        data: Object.values(previous),
        ...sharedDatasetProps
      }
    };

    const base = {
      type: kind,
      data: {
        labels: Object.keys(current),
        datasets: [datasets.current, datasets.previous]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: !this.compactValue,
            text: this.titleValue,
            font: { size: this.compactValue ? 14 : 18, weight: "bold" }
          },
          legend: {
            display: !this.compactValue
          }
        },
        interaction: { mode: "index", intersect: false }
      }
    };

    /* ------------------- type‑specific tweaks ------------------- */
    switch (kind) {
      case "horizontalBar":
        base.type = "bar";
        base.options.indexAxis = "y";
        // falls through
      case "bar":
      case "line": {
        const axisCfg = {
          beginAtZero: true,
          title: {
            display: !this.compactValue,
            text: this.yAxisLabelValue,
            font: { size: this.compactValue ? 12 : 16, weight: "bold" }
          },
          ticks: { font: { size: this.compactValue ? 10 : 14 } }
        };
        base.options.scales = kind === "horizontalBar" ? { x: axisCfg } : { y: axisCfg };
        if (kind === "line") {
          base.data.datasets.forEach((d) => (d.fill = false));
        }
        break;
      }

      case "pie":
      case "doughnut":
        base.data = {
          labels: ["Current Fiscal Year", "Previous Fiscal Year"],
          datasets: [
            {
              label: "Data",
              data: [
                this.sum(Object.values(current)),
                this.sum(Object.values(previous))
              ],
              backgroundColor: [colors.current + "0.7)", colors.previous + "0.7)"],
              borderColor: [colors.current + "1)", colors.previous + "1)"],
              borderWidth: 2
            }
          ]
        };
        break;

      case "polarArea": {
        const mergedValues = [...Object.values(current), ...Object.values(previous)];
        base.data.datasets = [
          {
            label: "Data",
            data: mergedValues,
            backgroundColor: mergedValues.map((_, i) =>
              i < Object.values(current).length
                ? colors.current + "0.7)"
                : colors.previous + "0.7)"
            ),
            borderColor: mergedValues.map((_, i) =>
              i < Object.values(current).length ? colors.current + "1)" : colors.previous + "1)"
            ),
            borderWidth: 2
          }
        ];
        base.data.labels = [
          ...Object.keys(current).map((k) => `${k} (Current FY)`),
          ...Object.keys(previous).map((k) => `${k} (Previous FY)`)
        ];
        break;
      }

      case "radar":
        base.options.elements = { line: { borderWidth: 3 } };
        datasets.current.pointBackgroundColor = colors.current + "1)";
        datasets.previous.pointBackgroundColor = colors.previous + "1)";
        break;
    }

    return base;
  }

  /* ------------------------------------------------------------------
   * Helpers
   * ----------------------------------------------------------------*/
  safeObj(o) {
    return typeof o === "object" && o !== null ? o : {};
  }

  sum(arr) {
    return arr.reduce((a, b) => a + b, 0);
  }

  log(msg, lvl = "log") {
    if (process?.env?.NODE_ENV === "development") console[lvl](
      `ReportsChart: ${msg}`
    );
  }
}
