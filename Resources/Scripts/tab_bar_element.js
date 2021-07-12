export class SPITabBarElement extends HTMLElement {
  constructor() {
    super()
      
      function showPage(tabId) {
          const tabPageElements = document.querySelectorAll("[data-tab-page]");
          tabPageElements.forEach((tabPageElement) => {
              if(tabPageElement.dataset.tabPage == tabId) {
                  tabPageElement.classList.remove('hidden');
              } else {
                  tabPageElement.classList.add('hidden');
              }
          });
      }
      
      const tabLinkElements = this.querySelectorAll("[data-tab]");
      tabLinkElements.forEach((tabLinkElement) => {
          // Add click listener which will show the correct page when a user taps on a tab link
          tabLinkElement.addEventListener('click', (event) => {
              // Update Tab Links
              tabLinkElements.forEach((tabLinkElement) => {
                  tabLinkElement.classList.remove('active');
              });
              
              tabLinkElement.classList.add('active');
              
              // Update Tab Pages
              showPage(event.srcElement.dataset.tab);
          });
      });
      
      // Show only the page which has the active class, on load
      const activeTabLinkElement = this.querySelector("[data-tab].active");
      showPage(activeTabLinkElement.dataset.tab);
  }
}
