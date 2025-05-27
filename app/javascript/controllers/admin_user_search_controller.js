import { Controller } from "@hotwired/stimulus";
import { setVisible } from "../utils/visibility";
import { createSearchDebounce } from "../utils/debounce";

export default class extends Controller {
  static targets = [
    "searchInput",
    "searchResults"
  ];
  static outlets = ["guardian-picker"];

  connect() {
    this.activeRequest = null;
    this.debouncedSearch = createSearchDebounce(() => this.executeSearch());
  }

  disconnect() {
    this.debouncedSearch?.cancel();
    this.activeRequest?.abort();
  }

  /* Search helpers ------------------------------------------------------ */
  performSearch(event) {
    event.preventDefault();
    this.debouncedSearch();
  }

  executeSearch() {
    const q = this.searchInputTarget.value.trim();
    if (!q) {
      this.clearResults();
      // If query is cleared, ensure guardian picker also knows (if it was a search-driven clear)
      // This might be better handled by a dedicated "clear" button that calls guardianPickerOutlet.clearSelection()
      return;
    }
    this.activeRequest?.abort();
    this.activeRequest = new AbortController();

    // Role value should be dynamic if this controller is reused, but for now, it's guardian
    const role = this.element.dataset.adminUserSearchRoleValue || "guardian";

    fetch(`/admin/users/search?q=${encodeURIComponent(q)}&role=${role}`, {
      headers: { Accept: "text/vnd.turbo-stream.html, text/html" },
      signal: this.activeRequest.signal
    })
      .then(r => {
        if (!r.ok) return Promise.reject(new Error(`HTTP error ${r.status}`));
        return r.text();
      })
      .then(html => {
        if (this.hasSearchResultsTarget) {
          this.searchResultsTarget.innerHTML = html;
          setVisible(this.searchResultsTarget, true);
        }
      })
      .catch(err => {
        if (err.name !== "AbortError") {
          console.error("Search error:", err);
          if (this.hasSearchResultsTarget) {
            this.searchResultsTarget.innerHTML = `<p class="text-red-500 p-2">Error: ${err.message}</p>`;
            setVisible(this.searchResultsTarget, true);
          }
        }
      });
  }

  clearSearchAndShowForm() { // This action is on the "Clear" button next to search input
    if (this.hasSearchInputTarget) this.searchInputTarget.value = "";
    this.clearResults();

    // This should primarily interact with the guardianPickerOutlet to reset its state
    if (this.hasGuardianPickerOutlet) {
      this.guardianPickerOutlet.clearSelection(); // This will make the searchPane visible
    }
    if(this.hasSearchInputTarget) this.searchInputTarget.focus();
  }

  clearResults() {
    if (this.hasSearchResultsTarget) {
      this.searchResultsTarget.innerHTML = "";
      setVisible(this.searchResultsTarget, false);
    }
  }

  /* Selection ----------------------------------------------------------- */
  selectUser(event) {
    event.preventDefault();
    const el = event.currentTarget;
    const userId = el.dataset.userId;
    const userName = el.dataset.userName;

    if (!userId || !userName) {
      console.error("User ID or Name missing from selected element's dataset.");
      return;
    }

    // Constructing a more detailed HTML for display, similar to the original controller
    // This could be made more robust or templated if needed.
    let displayHTML = `<span class="font-medium">${userName}</span>`;
    const email = el.dataset.userEmail;
    const phone = el.dataset.userPhone; // Assuming data-user-phone
    const address1 = el.dataset.userAddress1;
    const address2 = el.dataset.userAddress2;
    const city = el.dataset.userCity;
    const state = el.dataset.userState;
    const zip = el.dataset.userZip;
    const dependentsCount = el.dataset.userDependentsCount || '0';


    let contactInfo = [];
    if (email) contactInfo.push(`<span class="text-indigo-700">${email}</span>`);
    if (phone) contactInfo.push(`<span class="text-gray-600">Phone: ${phone}</span>`);
    if (contactInfo.length > 0) {
      displayHTML += `<div class="text-sm text-gray-600 mt-1">${contactInfo.join(' • ')}</div>`;
    }

    let formattedAddress = '';
    if (address1) {
      formattedAddress += address1;
      if (address2) formattedAddress += `, ${address2}`;
      if (city || state || zip) {
        formattedAddress += `, ${city || ''}, ${state || ''} ${zip || ''}`;
      }
    }

    if (formattedAddress) {
      displayHTML += `<div class="text-sm text-gray-600 mt-1">${formattedAddress}</div>`;
    } else {
      displayHTML += `<div class="text-sm text-gray-600 mt-1 italic">No address information available</div>`;
    }
    const dependentsText = parseInt(dependentsCount) === 1 ? "1 dependent" : `${dependentsCount} dependents`;
    displayHTML += `<div class="text-sm text-gray-600 mt-1">Currently has ${dependentsText}</div>`;


    if (this.hasGuardianPickerOutlet) {
      this.guardianPickerOutlet.selectGuardian(userId, displayHTML);
    } else {
      console.error("GuardianPickerOutlet not found.");
    }
    this.clearResults(); // Clear search results after selection
  }

  /* Create‑form toggle -------------------------------------------------- */
  // toggleCreateForm method removed as this functionality is now server-driven.
  
  /* Create Guardian ---------------------------------------------------- */
  createGuardian(event) {
    event.preventDefault();
    
    // Build FormData from the guardian form fields
    const formData = new FormData();
    
    // Add authentic token
    const token = document.querySelector('meta[name="csrf-token"]').content;
    formData.append('authenticity_token', token);
    
    // Add guardian attributes from form fields - remove the guardian_attributes prefix
    const formFields = document.querySelectorAll('input[name^="guardian_attributes"], select[name^="guardian_attributes"], textarea[name^="guardian_attributes"]');
    formFields.forEach(field => {
      // Extract the actual field name without the guardian_attributes prefix
      const nameWithoutPrefix = field.name.replace('guardian_attributes[', '').replace(']', '');
      let value = field.value;
      
      // Handle checkboxes and radio buttons
      if ((field.type === 'checkbox' || field.type === 'radio') && !field.checked) {
        return; // Skip unchecked boxes/radios
      }
      
      formData.append(nameWithoutPrefix, value);
    });
    
    // Show loading indicator
    const button = event.currentTarget;
    const originalText = button.innerHTML;
    button.innerHTML = '<span class="spinner inline-block w-4 h-4 border-2 border-current border-t-transparent text-white rounded-full animate-spin mr-2"></span> Saving...';
    button.disabled = true;
    
    // Make AJAX request to create guardian
    fetch('/admin/users', {
      method: 'POST',
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json'
      },
      body: formData
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error ${response.status}`);
      }
      return response.json();
    })
    .then(data => {
      if (data.success) {
        // Guardian created successfully
        if (this.hasGuardianPickerOutlet) {
          // Build display HTML for the selected guardian
          let displayHTML = `<span class="font-medium">${data.user.first_name} ${data.user.last_name}</span>`;
          
          let contactInfo = [];
          if (data.user.email) contactInfo.push(`<span class="text-indigo-700">${data.user.email}</span>`);
          if (data.user.phone) contactInfo.push(`<span class="text-gray-600">Phone: ${data.user.phone}</span>`);
          if (contactInfo.length > 0) {
            displayHTML += `<div class="text-sm text-gray-600 mt-1">${contactInfo.join(' • ')}</div>`;
          }
          
          let formattedAddress = '';
          if (data.user.physical_address_1) {
            formattedAddress += data.user.physical_address_1;
            if (data.user.physical_address_2) formattedAddress += `, ${data.user.physical_address_2}`;
            if (data.user.city || data.user.state || data.user.zip_code) {
              formattedAddress += `, ${data.user.city || ''}, ${data.user.state || ''} ${data.user.zip_code || ''}`;
            }
          }
          
          if (formattedAddress) {
            displayHTML += `<div class="text-sm text-gray-600 mt-1">${formattedAddress}</div>`;
          }
          
          displayHTML += `<div class="text-sm text-gray-600 mt-1">New guardian</div>`;
          
          // Select the newly created guardian
          this.guardianPickerOutlet.selectGuardian(data.user.id, displayHTML);
        }
        
        // Show success notification
        const notification = document.createElement('div');
        notification.className = 'fixed top-4 right-4 bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded z-50';
        notification.innerHTML = `<span class="font-bold">Success!</span> Guardian created successfully.`;
        document.body.appendChild(notification);
        
        // Remove notification after 3 seconds
        setTimeout(() => {
          notification.remove();
        }, 3000);
      } else {
        // Handle validation errors
        alert(`Failed to create guardian: ${data.errors.join(', ')}`);
      }
    })
    .catch(error => {
      alert(`Error creating guardian: ${error.message}`);
    })
    .finally(() => {
      // Restore button state
      button.innerHTML = originalText;
      button.disabled = false;
    });
  }
}
