export class SPIPackageTabs {
    constructor() {
    document.addEventListener('turbo:load', () => {
      var tabs = document.getElementsByClassName("package_tabs");
      for (var i = 0; i < tabs.length; i++) {
        var links = tabs[i].getElementsByTagName('a');

        for (var j = 0; j < links.length; j++) {
            var link = links[j];

            if (!link.classList.contains("active")) {
                document.getElementById(link.hash.substring(1)).style.display = "none";
            }

            link.addEventListener('click', function(event) {
                event.preventDefault();

                // Declare all variables
                var i, tabcontent, tablinks;

                // Get all tabs and hide them
                tabcontent = document.getElementsByClassName("package_tab");
                for (i = 0; i < tabcontent.length; i++) {
                    tabcontent[i].style.display = "none";
                }

                // Get all tab links and remove the active class
                tablinks = document.getElementsByClassName("package_tab_link");
                for (i = 0; i < tablinks.length; i++) {
                    tablinks[i].className = tablinks[i].className.replace(" active", "");
                }

                // Show the current tab, and add an "active" class to the button that opened the tab
                document.getElementById(event.currentTarget.hash.substring(1)).style.display = "block";
                event.currentTarget.className += " active";
            });
        }
      }
    });
    }
  }
  
