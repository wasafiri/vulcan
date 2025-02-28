// Debug helper for reports functionality
document.addEventListener('DOMContentLoaded', () => {
  console.log('Debug helper loaded');
  
  // Check if Chart.js is available
  if (typeof Chart !== 'undefined') {
    console.log('Chart.js is available:', Chart.version);
  } else {
    console.error('Chart.js is not available!');
  }
  
  // Log all click events on the page
  document.addEventListener('click', (event) => {
    console.log('Click event:', event.target);
    
    // Check if the click was on a reports button
    if (event.target.closest('[data-reports-toggle-target="button"]') || 
        event.target.closest('[data-action*="reports-toggle#toggle"]')) {
      console.log('Reports button clicked:', event.target);
      
      // Check if the panel exists
      const panel = document.querySelector('[data-reports-toggle-target="panel"]');
      console.log('Reports panel found:', !!panel);
      
      // Check if the controller is connected
      const controller = document.querySelector('[data-controller*="reports-toggle"]');
      console.log('Reports controller found:', !!controller);
      
      // After a short delay, check for chart controllers
      setTimeout(() => {
        const chartControllers = document.querySelectorAll('[data-controller="reports-chart"]');
        console.log('Chart controllers after click:', chartControllers.length);
        
        // Check if any canvas elements were created
        const canvases = document.querySelectorAll('canvas');
        console.log('Canvas elements found:', canvases.length);
      }, 1000);
    }
  });
  
  // Log all Stimulus controllers on the page
  const controllers = document.querySelectorAll('[data-controller]');
  console.log('Stimulus controllers found:', controllers.length);
  controllers.forEach(el => {
    console.log('Controller:', el.dataset.controller, 'on element:', el);
  });
  
  // Log all reports-toggle targets
  const buttons = document.querySelectorAll('[data-reports-toggle-target="button"]');
  console.log('Reports toggle buttons found:', buttons.length);
  buttons.forEach(button => {
    console.log('Button:', button);
  });
  
  const panels = document.querySelectorAll('[data-reports-toggle-target="panel"]');
  console.log('Reports toggle panels found:', panels.length);
  panels.forEach(panel => {
    console.log('Panel:', panel);
  });
  
  // Log all reports-chart controllers
  const chartControllers = document.querySelectorAll('[data-controller="reports-chart"]');
  console.log('Reports chart controllers found:', chartControllers.length);
  chartControllers.forEach(controller => {
    console.log('Chart controller:', controller);
    console.log('Chart data:', {
      currentData: controller.dataset.reportsChartCurrentDataValue,
      previousData: controller.dataset.reportsChartPreviousDataValue,
      type: controller.dataset.reportsChartTypeValue
    });
  });
  
  // Check for any JavaScript errors
  window.addEventListener('error', (event) => {
    console.error('JavaScript error:', event.error);
  });
});
