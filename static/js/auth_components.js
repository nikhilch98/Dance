// Authentication Components JavaScript
// This file contains all authentication, login, profile, orders, and rewards related JavaScript functions

// Authentication variables
let currentUser = null;
let authToken = null;
let otpTimer = null;
let resendCountdown = 30;
let currentMobileNumber = '';

// Domain-specific storage keys
let baseUrl = '';
let authTokenKey = '';
let currentUserKey = '';

// Profile modal variables
let currentProfileTab = 'profile';
let ordersData = null;
let rewardsData = null;
let currentOrderFilter = 'all';
let currentTransactionFilter = 'all';
let ordersPage = 0;
let transactionsPage = 1;
let hasMoreOrders = true;
let hasMoreTransactions = true;

// Initialize domain-specific storage keys
function initializeStorageKeys() {
    baseUrl = window.location.origin; // e.g., "https://nachna.com" or "http://localhost:8002"
    const cleanBaseUrl = baseUrl.replace(/https?:\/\//, '').replace(/[:.]/g, '_');
    authTokenKey = `authToken_${cleanBaseUrl}`;
    currentUserKey = `currentUser_${cleanBaseUrl}`;

    console.log('Initialized storage keys for domain:', baseUrl);
    console.log('Auth token key:', authTokenKey);
    console.log('Current user key:', currentUserKey);

    // Migrate old tokens if they exist (backward compatibility)
    migrateOldTokens();
}

// Migrate old non-domain-specific tokens to domain-specific ones
function migrateOldTokens() {
    const oldTokenKey = 'authToken';
    const oldUserKey = 'currentUser';

    const oldToken = localStorage.getItem(oldTokenKey);
    const oldUser = localStorage.getItem(oldUserKey);

    if (oldToken && oldUser && !localStorage.getItem(authTokenKey)) {
        console.log('Migrating old tokens to domain-specific keys');
        localStorage.setItem(authTokenKey, oldToken);
        localStorage.setItem(currentUserKey, oldUser);

        // Optionally remove old keys
        localStorage.removeItem(oldTokenKey);
        localStorage.removeItem(oldUserKey);

        console.log('Token migration completed');
    }
}

// Auth DOM Elements - will be initialized after DOM loads
let authContainer, authButton, profileModal, loginModal, otpModal, bundleSuggestionModal;
let ordersModal, rewardsModal, qrModal, shareModal;
let mobileInput, otpMobileNumber, otpInputs, sendOtpBtn, verifyOtpBtn, resendOtpBtn;
let loginError, otpError, profileName, profileMobile, profileStatus, profileAvatarContainer;
let ordersRefreshBtn, rewardsRefreshBtn;

// Modal management functions
function showLoginModal() {
    closeAllModals();
    if (loginModal) {
        loginModal.style.display = 'flex';
        if (mobileInput) mobileInput.focus();
    }
}

function closeLoginModal() {
    if (loginModal) loginModal.style.display = 'none';
    if (mobileInput) mobileInput.value = '';
    if (loginError) loginError.style.display = 'none';
}

function showOTPModal() {
    closeAllModals();
    if (otpModal) {
        otpModal.style.display = 'flex';
        const otpInput = document.getElementById('otp-input');
        if (otpInput) otpInput.focus();
    }
}

function closeOTPModal() {
    if (otpModal) otpModal.style.display = 'none';
    const otpInput = document.getElementById('otp-input');
    if (otpInput) otpInput.value = '';
    if (otpError) otpError.style.display = 'none';
    clearInterval(otpTimer);
    resendCountdown = 30;
}

const showProfileModal = requireAuth(function() {
    closeAllModals();
    profileModal.style.display = 'flex';
    loadProfileData();
});

function closeProfileModal() {
    profileModal.style.display = 'none';
    currentProfileTab = 'profile';
}

const openOrdersModal = requireAuth(function() {
    console.log('openOrdersModal: Opening orders modal');
    closeProfileModal();
    ordersModal.style.display = 'flex';
    loadOrders();
});

function closeOrdersModal() {
    ordersModal.style.display = 'none';
    currentOrderFilter = 'all';
    ordersPage = 0;
    hasMoreOrders = true;
}

const openRewardsModal = requireAuth(function() {
    closeProfileModal();
    rewardsModal.style.display = 'flex';
    loadRewards();
});

function closeRewardsModal() {
    rewardsModal.style.display = 'none';
    currentTransactionFilter = 'all';
    transactionsPage = 1;
    hasMoreTransactions = true;
}

function openShareModal() {
    closeAllModals();
    if (shareModal) {
        shareModal.style.display = 'flex';
        populateShareUrl();
    }
}

function closeShareModal() {
    if (shareModal) shareModal.style.display = 'none';
}

function closeBundleSuggestionModal() {
    bundleSuggestionModal.style.display = 'none';
}

function openQRModal() {
    closeAllModals();
    if (qrModal) qrModal.style.display = 'flex';
}

function closeQRModal() {
    if (qrModal) qrModal.style.display = 'none';
}

function closeAllModals() {
    if (loginModal) loginModal.style.display = 'none';
    if (otpModal) otpModal.style.display = 'none';
    if (profileModal) profileModal.style.display = 'none';
    if (ordersModal) ordersModal.style.display = 'none';
    if (rewardsModal) rewardsModal.style.display = 'none';
    if (qrModal) qrModal.style.display = 'none';
    if (shareModal) shareModal.style.display = 'none';
    if (bundleSuggestionModal) bundleSuggestionModal.style.display = 'none';
}

// Authentication UI functions
function updateAuthUI() {
    const authText = authButton.querySelector('.auth-text');

    if (currentUser) {
        // Show profile avatar
        authButton.innerHTML = '';

        if (currentUser.profile_picture_url) {
            const avatar = document.createElement('img');
            avatar.className = 'profile-avatar';
            avatar.alt = currentUser.name || 'Profile';

            // Use centralized image loading function
            loadImage({
                element: avatar,
                type: 'user',
                entityId: currentUser.user_id,
                altText: currentUser.name || 'Profile',
                onSuccess: function(img) {
                    authButton.appendChild(img);
                },
                onError: function(img) {
                    showProfileFallback();
                }
            });
        } else {
            showProfileFallback();
        }

        // Add click handler for profile dropdown
        authButton.onclick = function() {
            handleAuth();
        };

    } else {
        // Show login button
        authButton.innerHTML = `
            <span class="auth-text">Login</span>
            <svg class="auth-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
            </svg>
        `;

        // Add click handler for login
        authButton.onclick = function() {
            handleAuth();
        };
    }
}

function showProfileFallback() {
    const fallback = document.createElement('div');
    fallback.className = 'profile-fallback';
    fallback.textContent = getInitials(currentUser.name || currentUser.mobile_number);
    authButton.appendChild(fallback);
}

// Authentication initialization
function initializeAuth() {
    console.log('Initializing auth...');

    // Initialize domain-specific storage keys first
    initializeStorageKeys();

    console.log('Auth components initialized successfully');

    // Check for existing session
    const savedToken = localStorage.getItem(authTokenKey);
    const savedUser = localStorage.getItem(currentUserKey);

    console.log('Saved token exists:', !!savedToken, 'Saved user exists:', !!savedUser);

    if (savedToken && savedUser) {
        try {
            authToken = savedToken;
            currentUser = JSON.parse(savedUser);
            window.authToken = authToken;
            window.currentUser = currentUser;
            console.log('Restored session for user:', currentUser.name || currentUser.mobile_number);

            // Validate token before showing as logged in
            validateTokenAndUpdateUI();
        } catch (error) {
            console.error('Error restoring auth session:', error);
            logout();
        }
    } else {
        console.log('No saved session found');
        updateAuthUI();
    }

    // Set up event listeners
    setupAuthEventListeners();

    // Set up auth button click handler programmatically (more reliable than inline onclick)
    setupAuthButtonHandler();
}

// Set up auth button click handler programmatically
function setupAuthButtonHandler() {
    const authButton = document.getElementById('auth-button');
    if (authButton) {
        console.log('Setting up auth button click handler');
        authButton.addEventListener('click', function(e) {
            e.preventDefault();
            console.log('Auth button clicked programmatically');
            handleAuth();
        });
        authButton.style.cursor = 'pointer';
    } else {
        console.error('Auth button not found!');
    }
}

// Validate token and update UI accordingly
async function validateTokenAndUpdateUI() {
    if (!authToken) {
        updateAuthUI();
        return;
    }

    try {
        // Try to make a simple API call to validate the token using profile endpoint
        const response = await fetch('/api/auth/profile', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json',
            }
        });

        if (response.ok) {
            console.log('Token is valid, user is logged in');
            // Update currentUser with fresh profile data
            const profileData = await response.json();
            currentUser = profileData;
            window.currentUser = currentUser;
            localStorage.setItem(currentUserKey, JSON.stringify(currentUser));
            updateAuthUI();
        } else if (response.status === 401) {
            console.log('Token is invalid or expired, logging out');
            logout();
        } else {
            console.log('Profile endpoint returned error, but token might still be valid');
            updateAuthUI();
        }
    } catch (error) {
        console.error('Error validating token:', error);
        // If we can't validate due to network issues, assume token is still valid
        console.log('Could not validate token due to network error, assuming still valid');
        updateAuthUI();
    }
}

function setupAuthEventListeners() {
    console.log('Setting up auth event listeners');

    // Set up modal close buttons
    setupModalCloseButtons();

    // Set up profile action buttons
    setupProfileActionButtons();

    // Set up orders controls
    setupOrdersControls();

    // Set up rewards controls
    setupRewardsControls();

    // Set up form submissions
    setupFormSubmissions();

    // Close modals when clicking outside
    setupModalOutsideClicks();

    // Set up OTP input handling
    setupOTPInputs();
}

function setupModalCloseButtons() {
    // Login modal close
    const loginCloseBtn = document.querySelector('#login-modal .auth-modal-close');
    if (loginCloseBtn) loginCloseBtn.onclick = closeLoginModal;

    // OTP modal close
    const otpCloseBtn = document.querySelector('#otp-modal .auth-modal-close');
    if (otpCloseBtn) otpCloseBtn.onclick = closeOTPModal;

    // Profile modal close
    const profileCloseBtn = document.querySelector('#profile-modal .profile-modal-close');
    if (profileCloseBtn) profileCloseBtn.onclick = closeProfileModal;

    // Orders modal close
    const ordersCloseBtn = document.querySelector('#orders-modal .profile-modal-close');
    if (ordersCloseBtn) ordersCloseBtn.onclick = closeOrdersModal;

    // Rewards modal close
    const rewardsCloseBtn = document.querySelector('#rewards-modal .profile-modal-close');
    if (rewardsCloseBtn) rewardsCloseBtn.onclick = closeRewardsModal;

    // QR modal close
    const qrCloseBtn = document.querySelector('#qr-modal .qr-modal-close');
    if (qrCloseBtn) qrCloseBtn.onclick = closeQRModal;

    // Share modal close
    const shareCloseBtn = document.querySelector('#share-modal .share-close');
    if (shareCloseBtn) shareCloseBtn.onclick = closeShareModal;
}

function setupProfileActionButtons() {
    // Orders button
    const ordersBtn = document.querySelector('.profile-orders-btn');
    if (ordersBtn) ordersBtn.onclick = openOrdersModal;

    // Rewards button
    const rewardsBtn = document.querySelector('.profile-rewards-btn');
    if (rewardsBtn) rewardsBtn.onclick = openRewardsModal;

    // Edit profile button
    const editBtn = document.querySelector('.profile-edit-btn');
    if (editBtn) editBtn.onclick = navigateToEditProfile;

    // Logout button
    const logoutBtn = document.querySelector('.profile-logout-btn');
    if (logoutBtn) logoutBtn.onclick = logout;
}

function setupOrdersControls() {
    // Orders refresh button
    const ordersRefreshBtn = document.getElementById('orders-refresh-btn');
    if (ordersRefreshBtn) ordersRefreshBtn.onclick = refreshOrders;

    // Orders filter chips
    const filterChips = document.querySelectorAll('#orders-filter-chips .filter-chip');
    filterChips.forEach(chip => {
        chip.onclick = function() {
            const filter = this.getAttribute('data-filter');
            if (filter) applyOrderFilter(filter);
        };
    });
}

function setupRewardsControls() {
    // Rewards refresh button
    const rewardsRefreshBtn = document.getElementById('rewards-refresh-btn');
    if (rewardsRefreshBtn) rewardsRefreshBtn.onclick = refreshRewards;

    // Transaction tabs
    const transactionTabs = document.querySelectorAll('.transaction-tab');
    transactionTabs.forEach(tab => {
        tab.onclick = function() {
            const filter = this.getAttribute('data-filter') || this.textContent.toLowerCase();
            if (filter) switchTransactionTab(filter);
        };
    });

    // Load more button
    const loadMoreBtn = document.getElementById('load-more-btn');
    if (loadMoreBtn) {
        const loadMoreButton = loadMoreBtn.querySelector('button');
        if (loadMoreButton) loadMoreButton.onclick = loadMoreTransactions;
    }
}

function setupFormSubmissions() {
    // Login form
    const loginForm = document.getElementById('login-form');
    if (loginForm) loginForm.onsubmit = handleSendOTP;

    // OTP form
    const otpForm = document.getElementById('otp-form');
    if (otpForm) otpForm.onsubmit = handleVerifyOTP;
}

function setupModalOutsideClicks() {
    loginModal.addEventListener('click', function(e) {
        if (e.target === loginModal) {
            closeLoginModal();
        }
    });

    otpModal.addEventListener('click', function(e) {
        if (e.target === otpModal) {
            closeOTPModal();
        }
    });

    profileModal.addEventListener('click', function(e) {
        if (e.target === profileModal) {
            closeProfileModal();
        }
    });

    ordersModal.addEventListener('click', function(e) {
        if (e.target === ordersModal) {
            closeOrdersModal();
        }
    });

    rewardsModal.addEventListener('click', function(e) {
        if (e.target === rewardsModal) {
            closeRewardsModal();
        }
    });

    qrModal.addEventListener('click', function(e) {
        if (e.target === qrModal) {
            closeQRModal();
        }
    });

    shareModal.addEventListener('click', function(e) {
        if (e.target === shareModal) {
            closeShareModal();
        }
    });

    bundleSuggestionModal.addEventListener('click', function(e) {
        if (e.target === bundleSuggestionModal) {
            closeBundleSuggestionModal();
        }
    });

    // Close modals when clicking outside auth container (for profile modal)
    document.addEventListener('click', function(e) {
        if (!authContainer.contains(e.target)) {
            // Don't close if clicking on a modal
            const isModalClick = [
                loginModal, otpModal, profileModal, ordersModal,
                rewardsModal, qrModal, shareModal, bundleSuggestionModal
            ].some(modal => modal && modal.contains(e.target));

            if (!isModalClick) {
                closeAllModals();
            }
        }
    });
}

function setupOTPInputs() {
    otpInputs.forEach((input, index) => {
        input.addEventListener('input', function(e) {
            // Allow only numbers
            this.value = this.value.replace(/[^0-9]/g, '');

            // Auto-focus next input
            if (this.value.length === 1 && index < otpInputs.length - 1) {
                otpInputs[index + 1].focus();
            }

            // Auto-submit when all digits entered
            const allFilled = Array.from(otpInputs).every(inp => inp.value.length === 1);
            if (allFilled) {
                handleVerifyOTP(event);
            }
        });

        input.addEventListener('keydown', function(e) {
            if (e.key === 'Backspace' && this.value.length === 0 && index > 0) {
                otpInputs[index - 1].focus();
            }
        });
    });
}

// Authentication API functions
async function handleSendOTP(event) {
    event.preventDefault();

    const mobileNumber = mobileInput.value.trim();
    if (!mobileNumber || mobileNumber.length !== 10) {
        showAuthError(loginError, 'Please enter a valid 10-digit mobile number');
        return;
    }

    currentMobileNumber = mobileNumber;

    // Show loading
    sendOtpBtn.disabled = true;
    sendOtpBtn.querySelector('.btn-text').textContent = 'Sending...';
    sendOtpBtn.querySelector('.btn-loader').style.display = 'block';

    try {
        const response = await fetch('/api/auth/send-otp', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                mobile_number: mobileNumber
            })
        });

        const data = await response.json();

        if (response.ok) {
            // Success - show OTP modal
            otpMobileNumber.textContent = mobileNumber;
            showOTPModal();
            startResendTimer();
        } else {
            showAuthError(loginError, data.detail || 'Failed to send OTP. Please try again.');
        }
    } catch (error) {
        console.error('Send OTP error:', error);
        showAuthError(loginError, error.message || 'Failed to send OTP. Please try again.');
    } finally {
        // Hide loading
        sendOtpBtn.disabled = false;
        sendOtpBtn.querySelector('.btn-text').textContent = 'Send OTP';
        sendOtpBtn.querySelector('.btn-loader').style.display = 'none';
    }
}

async function handleVerifyOTP(event) {
    if (event) event.preventDefault();

    const otp = Array.from(otpInputs).map(input => input.value).join('');
    if (otp.length !== 6) {
        showAuthError(otpError, 'Please enter the complete 6-digit code');
        return;
    }

    // Show loading
    verifyOtpBtn.disabled = true;
    verifyOtpBtn.querySelector('.btn-text').textContent = 'Verifying...';
    verifyOtpBtn.querySelector('.btn-loader').style.display = 'block';

    try {
        const response = await fetch('/api/auth/verify-otp', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                mobile_number: currentMobileNumber,
                otp: otp
            })
        });

        const data = await response.json();

        if (response.ok) {
            // Success - store auth data and update UI
            authToken = data.access_token;
            currentUser = data.user;
            window.authToken = authToken;
            window.currentUser = currentUser;

            localStorage.setItem(authTokenKey, authToken);
            localStorage.setItem(currentUserKey, JSON.stringify(currentUser));

            updateAuthUI();
            closeOTPModal();
            closeLoginModal();

            // Load user data if needed
            loadUserData();

        } else {
            showAuthError(otpError, data.detail || 'Invalid OTP. Please try again.');
        }
    } catch (error) {
        console.error('Verify OTP error:', error);
        showAuthError(otpError, error.message || 'Failed to verify OTP. Please try again.');
    } finally {
        // Hide loading
        verifyOtpBtn.disabled = false;
        verifyOtpBtn.querySelector('.btn-text').textContent = 'Verify & Continue';
        verifyOtpBtn.querySelector('.btn-loader').style.display = 'none';
    }
}

function resendOTP() {
    // Clear any existing timer
    clearInterval(otpTimer);

    // Reset OTP inputs
    otpInputs.forEach(input => input.value = '');
    otpError.style.display = 'none';

    // Send OTP again
    const fakeEvent = { preventDefault: () => {} };
    handleSendOTP(fakeEvent);
}

function startResendTimer() {
    resendCountdown = 30;
    resendOtpBtn.disabled = true;

    resendOtpBtn.querySelector('.resend-text').style.display = 'none';
    resendOtpBtn.querySelector('.countdown-text').style.display = 'inline';
    resendOtpBtn.querySelector('.countdown-text').textContent = `Resend in ${resendCountdown}s`;

    otpTimer = setInterval(() => {
        resendCountdown--;
        resendOtpBtn.querySelector('.countdown-text').textContent = `Resend in ${resendCountdown}s`;

        if (resendCountdown <= 0) {
            clearInterval(otpTimer);
            resendOtpBtn.disabled = false;
            resendOtpBtn.querySelector('.resend-text').style.display = 'inline';
            resendOtpBtn.querySelector('.countdown-text').style.display = 'none';
        }
    }, 1000);
}

function logout() {
    currentUser = null;
    authToken = null;
    window.currentUser = null;
    window.authToken = null;
    localStorage.removeItem(authTokenKey);
    localStorage.removeItem(currentUserKey);
    updateAuthUI();
    closeAllModals();
}

function handleAuth() {
    console.log('handleAuth called');
    console.log('currentUser:', currentUser);
    console.log('authToken:', authToken ? 'present' : 'null');

    if (currentUser && authToken) {
        console.log('Showing profile modal');
        showProfileModal();
    } else {
        console.log('Showing login modal');
        showLoginModal();
    }
}

// Profile functions
function loadProfileData() {
    if (!currentUser) return;

    profileName.textContent = currentUser.name || 'Loading...';
    profileMobile.textContent = currentUser.mobile_number || 'Loading...';

    // Load profile picture using /api/image/user/{user_id}
    loadImage({
        element: profileAvatarContainer,
        type: 'user',
        entityId: currentUser.user_id,
        altText: currentUser.name || 'Profile',
        containerClass: 'profile-avatar-large',
        fallbackClass: 'profile-fallback-large',
        onSuccess: function(container) {
            container.className = 'profile-avatar-large';
            const img = container.querySelector('img');
            if (img) img.className = 'profile-avatar-large';
        },
        onError: function(container) {
            showProfileModalFallback();
        }
    });

    // Set profile status
    const statusBadge = profileStatus.querySelector('.status-badge');
    if (statusBadge) {
        statusBadge.textContent = currentUser.profile_complete ? 'Complete' : 'Incomplete';
        statusBadge.className = `status-badge ${currentUser.profile_complete ? 'complete' : 'incomplete'}`;
    }
}

function showProfileModalFallback() {
    profileAvatarContainer.innerHTML = '';
    const fallback = document.createElement('div');
    fallback.className = 'profile-fallback-large';
    fallback.textContent = getInitials(currentUser.name || currentUser.mobile_number);
    profileAvatarContainer.appendChild(fallback);
}

function navigateToEditProfile() {
    // This would typically navigate to a profile edit page
    // For now, we'll just close the modal
    closeProfileModal();
    // You can implement navigation logic here
    console.log('Navigate to edit profile');
}

// Authentication guard function
function requireAuth(callback) {
    return async function(...args) {
        if (!currentUser || !authToken) {
            // User is not logged in, show login modal
            console.log('Authentication required, showing login modal');
            openLoginModal();
            return;
        }

        // User appears logged in, but let's validate the token first
        try {
            const response = await fetch('/api/auth/profile', {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json',
                }
            });

            if (response.ok) {
                // Token is valid, proceed with the callback
                console.log('Token validated, proceeding with authenticated action');
                return callback.apply(this, args);
            } else if (response.status === 401) {
                // Token is expired/invalid, show login modal
                console.log('Token expired, showing login modal');
                logout();
                openLoginModal();
                return;
            } else {
                // Other error, but let's assume token is still valid
                console.log('Profile check failed but proceeding anyway');
                return callback.apply(this, args);
            }
        } catch (error) {
            console.error('Error validating token for auth-required action:', error);
            // On network error, assume token is still valid
            console.log('Network error during validation, proceeding with action');
            return callback.apply(this, args);
        }
    };
}

// Debug function to check authentication status
function debugAuthStatus() {
    console.log('=== AUTH DEBUG INFO ===');
    console.log('Current domain:', baseUrl);
    console.log('Auth token key:', authTokenKey);
    console.log('Current user key:', currentUserKey);
    console.log('Has auth token:', !!authToken);
    console.log('Has current user:', !!currentUser);
    console.log('Stored token exists:', !!localStorage.getItem(authTokenKey));
    console.log('Stored user exists:', !!localStorage.getItem(currentUserKey));

    // List all localStorage keys related to auth
    const allKeys = Object.keys(localStorage);
    const authKeys = allKeys.filter(key => key.includes('auth') || key.includes('currentUser'));
    console.log('All auth-related keys:', authKeys);

    console.log('=======================');
}

// Make functions globally available for onclick handlers
window.handleAuth = handleAuth;
window.showLoginModal = showLoginModal;
window.closeLoginModal = closeLoginModal;
window.closeOTPModal = closeOTPModal;
window.closeProfileModal = closeProfileModal;
window.closeOrdersModal = closeOrdersModal;
window.closeRewardsModal = closeRewardsModal;
window.closeShareModal = closeShareModal;
window.closeQRModal = closeQRModal;
window.openShareModal = openShareModal;
window.handleSendOTP = handleSendOTP;
window.handleVerifyOTP = handleVerifyOTP;
window.resendOTP = resendOTP;
window.logout = logout;

// Make modal variables globally available
window.shareModal = shareModal;
window.ordersModal = ordersModal;
window.rewardsModal = rewardsModal;
window.qrModal = qrModal;

// Make authentication state globally available
window.authToken = authToken;
window.currentUser = currentUser;

// Make profile and order functions globally available
window.openOrdersModal = openOrdersModal;
window.openRewardsModal = openRewardsModal;
window.refreshOrders = refreshOrders;
window.refreshRewards = refreshRewards;
window.loadOrders = loadOrders;
window.loadRewards = loadRewards;
window.navigateToEditProfile = navigateToEditProfile;
window.applyOrderFilter = applyOrderFilter;
window.switchTransactionTab = switchTransactionTab;
window.loadMoreTransactions = loadMoreTransactions;

// Make debug function globally available for console testing
window.debugAuthStatus = debugAuthStatus;

// Utility functions
function showAuthError(element, message) {
    element.textContent = message;
    element.style.display = 'block';
}

function getInitials(name) {
    if (!name) return '?';
    return name.split(' ').map(word => word[0]).join('').toUpperCase().slice(0, 2);
}

// Orders functions
async function loadOrders() {
    if (!authToken) {
        console.log('No auth token for loadOrders');
        return;
    }

    const ordersLoading = document.getElementById('orders-loading');
    const ordersError = document.getElementById('orders-error');
    const ordersEmpty = document.getElementById('orders-empty');
    const ordersList = document.getElementById('orders-list');

    ordersLoading.style.display = 'block';
    ordersError.style.display = 'none';
    ordersEmpty.style.display = 'none';
    ordersList.innerHTML = '';

    try {
        console.log('loadOrders: Fetching orders from /api/orders/user');
        const response = await fetch('/api/orders/user', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json',
            },
        });
        console.log('loadOrders: API response status:', response.status);

        if (response.ok) {
            const data = await response.json();
            ordersData = data.orders || [];
            displayOrders(ordersData);
        } else {
            throw new Error('Failed to load orders');
        }
    } catch (error) {
        console.error('Load orders error:', error);
        ordersLoading.style.display = 'none';
        ordersError.style.display = 'block';
    }
}

function displayOrders(orders) {
    const ordersLoading = document.getElementById('orders-loading');
    const ordersEmpty = document.getElementById('orders-empty');
    const ordersList = document.getElementById('orders-list');

    ordersLoading.style.display = 'none';

    if (!orders || orders.length === 0) {
        ordersEmpty.style.display = 'block';
        return;
    }

    ordersEmpty.style.display = 'none';

    const filteredOrders = orders.filter(order => {
        switch (currentOrderFilter) {
            case 'pending':
                return ['pending', 'created'].includes(order.status?.toLowerCase());
            case 'completed':
                return order.status?.toLowerCase() === 'completed';
            case 'failed':
                return ['failed', 'cancelled'].includes(order.status?.toLowerCase());
            default:
                return true;
        }
    });

    ordersList.innerHTML = '';

    filteredOrders.forEach(order => {
        const orderCard = createOrderCard(order);
        ordersList.appendChild(orderCard);
    });
}

function createOrderCard(order) {
    const card = document.createElement('div');
    card.className = 'order-card';

    const statusClass = order.status?.toLowerCase() || 'unknown';
    const statusText = order.status ? order.status.charAt(0).toUpperCase() + order.status.slice(1) : 'Unknown';

    card.innerHTML = `
        <div class="order-header">
            <div class="order-title">${order.workshop_title || 'Workshop'}</div>
            <div class="order-status status-${statusClass}">${statusText}</div>
        </div>
        <div class="order-details">
            <div class="order-info">
                <div class="order-date">${formatDate(order.created_at)}</div>
                <div class="order-amount">₹${order.amount || 0}</div>
            </div>
            <div class="order-actions">
                ${order.status?.toLowerCase() === 'completed' && order.qr_codes && order.qr_codes.length > 0 ?
                    `<button class="order-action-btn qr-btn" onclick="viewQRCode('${order._id}', '${order.workshop_title}', '${order.artists?.join(', ') || ''}')">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="2" y="2" width="20" height="20" rx="2" ry="2"/>
                            <rect x="6" y="6" width="12" height="12"/>
                            <rect x="8" y="8" width="8" height="8"/>
                        </svg>
                        View QR
                    </button>` : ''
                }
                ${order.payment_link_url ?
                    `<button class="order-action-btn pay-btn" onclick="payOrder('${order._id}', '${order.payment_link_url}')">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <circle cx="9" cy="12" r="1"/>
                            <circle cx="15" cy="12" r="1"/>
                            <path d="M12 2l3 3-3 3-3-3 3-3z"/>
                            <path d="M12 22l3-3-3-3-3 3 3 3z"/>
                        </svg>
                        Pay Now
                    </button>` : ''
                }
            </div>
        </div>
    `;

    return card;
}

function applyOrderFilter(filter) {
    currentOrderFilter = filter;

    // Update filter button states
    const filterButtons = document.querySelectorAll('.filter-chip');
    filterButtons.forEach(btn => {
        btn.classList.remove('active');
        if (btn.onclick.toString().includes(filter)) {
            btn.classList.add('active');
        }
    });

    if (ordersData) {
        displayOrders(ordersData);
    }
}

function refreshOrders() {
    console.log('refreshOrders: Starting refresh');
    ordersRefreshBtn.disabled = true;
    ordersRefreshBtn.querySelector('svg').style.transform = 'rotate(360deg)';
    ordersRefreshBtn.querySelector('svg').style.transition = 'transform 0.5s';

    loadOrders().finally(() => {
        console.log('refreshOrders: Load completed');
        setTimeout(() => {
            ordersRefreshBtn.disabled = false;
            ordersRefreshBtn.querySelector('svg').style.transform = 'rotate(0deg)';
        }, 500);
    });
}

// Rewards functions
async function loadRewards() {
    if (!authToken) {
        console.log('No auth token for loadRewards');
        return;
    }

    const rewardsLoading = document.getElementById('rewards-loading');
    const rewardsError = document.getElementById('rewards-error');
    const rewardsBalance = document.getElementById('rewards-balance');

    rewardsLoading.style.display = 'block';
    rewardsError.style.display = 'none';
    rewardsBalance.style.display = 'none';

    try {
        const response = await fetch('/api/rewards/balance', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json',
            },
        });

        if (response.ok) {
            const data = await response.json();
            rewardsData = data;
            displayRewards(data);
        } else {
            throw new Error('Failed to load rewards');
        }
    } catch (error) {
        console.error('Load rewards error:', error);
        rewardsLoading.style.display = 'none';
        rewardsError.style.display = 'block';
    }
}

function displayRewards(data) {
    const rewardsLoading = document.getElementById('rewards-loading');
    const rewardsBalance = document.getElementById('rewards-balance');

    rewardsLoading.style.display = 'none';
    rewardsBalance.style.display = 'block';

    // Update balance display
    document.getElementById('available-balance').textContent = `₹${data.available_balance || 0}`;
    document.getElementById('earned-amount').textContent = `₹${data.total_earned || 0}`;
    document.getElementById('redeemed-amount').textContent = `₹${data.total_redeemed || 0}`;

    // Load transactions
    loadTransactions();
}

async function loadTransactions() {
    const transactionsList = document.getElementById('transactions-list');
    const loadMoreBtn = document.getElementById('load-more-btn');

    try {
        const response = await fetch(`/api/rewards/transactions?page=${transactionsPage}&limit=10&filter=${currentTransactionFilter}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json',
            },
        });

        if (response.ok) {
            const data = await response.json();
            const transactions = data.transactions || [];

            if (transactionsPage === 1) {
                transactionsList.innerHTML = '';
            }

            transactions.forEach(transaction => {
                const transactionCard = createTransactionCard(transaction);
                transactionsList.appendChild(transactionCard);
            });

            hasMoreTransactions = data.has_more || false;
            loadMoreBtn.style.display = hasMoreTransactions ? 'block' : 'none';
        }
    } catch (error) {
        console.error('Load transactions error:', error);
    }
}

function createTransactionCard(transaction) {
    const card = document.createElement('div');
    card.className = `transaction-card ${transaction.type}`;

    const amountClass = transaction.type === 'credit' ? 'positive' : 'negative';
    const amountPrefix = transaction.type === 'credit' ? '+' : '-';

    card.innerHTML = `
        <div class="transaction-info">
            <div class="transaction-description">${transaction.description || 'Transaction'}</div>
            <div class="transaction-date">${formatDate(transaction.created_at)}</div>
        </div>
        <div class="transaction-amount ${amountClass}">${amountPrefix}₹${transaction.amount || 0}</div>
    `;

    return card;
}

function switchTransactionTab(filter) {
    currentTransactionFilter = filter;
    transactionsPage = 1;
    hasMoreTransactions = true;

    // Update tab states
    const transactionTabs = document.querySelectorAll('.transaction-tab');
    transactionTabs.forEach(tab => {
        tab.classList.remove('active');
        if (tab.onclick.toString().includes(filter)) {
            tab.classList.add('active');
        }
    });

    loadTransactions();
}

function loadMoreTransactions() {
    transactionsPage++;
    loadTransactions();
}

function refreshRewards() {
    rewardsRefreshBtn.disabled = true;
    rewardsRefreshBtn.querySelector('svg').style.transform = 'rotate(360deg)';
    rewardsRefreshBtn.querySelector('svg').style.transition = 'transform 0.5s';

    loadRewards().finally(() => {
        setTimeout(() => {
            rewardsRefreshBtn.disabled = false;
            rewardsRefreshBtn.querySelector('svg').style.transform = 'rotate(0deg)';
        }, 500);
    });
}

// Share functions
function shareViaWhatsApp() {
    const url = encodeURIComponent(getCurrentPageUrl());
    const text = encodeURIComponent(`Check out this amazing dance studio: ${document.title}`);
    window.open(`https://wa.me/?text=${text}%20${url}`, '_blank');
}

function shareViaInstagram() {
    // Instagram doesn't support direct URL sharing, so we'll copy to clipboard
    copyShareUrl();
    alert('Link copied! You can now paste it in Instagram.');
}

function shareViaGeneric() {
    if (navigator.share) {
        navigator.share({
            title: document.title,
            text: 'Check out this amazing dance studio',
            url: getCurrentPageUrl()
        });
    } else {
        copyShareUrl();
        alert('Link copied to clipboard!');
    }
}

function copyShareUrl() {
    const shareUrlInput = document.getElementById('share-url');
    shareUrlInput.select();
    document.execCommand('copy');
}

function populateShareUrl() {
    const shareUrlInput = document.getElementById('share-url');
    shareUrlInput.value = getCurrentPageUrl();
}

function getCurrentPageUrl() {
    return window.location.href;
}

// Utility functions
function formatDate(dateString) {
    if (!dateString) return 'Unknown';
    const date = new Date(dateString);
    return date.toLocaleDateString('en-IN', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// QR Code functions
async function generateQRCode(orderId, workshopTitle, workshopArtists) {
    if (!authToken) {
        console.log('No auth token for generateQRCode');
        return;
    }

    const qrLoading = document.getElementById('qr-loading');
    const qrError = document.getElementById('qr-error');
    const qrContainer = document.getElementById('qr-code-container');

    qrLoading.style.display = 'block';
    qrError.style.display = 'none';
    qrContainer.style.display = 'none';

    try {
        const response = await fetch(`/api/orders/${orderId}/qr`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json',
            },
        });

        if (response.ok) {
            const data = await response.json();
            displayQRCode(data.qr_code_data, workshopTitle, workshopArtists);
        } else {
            throw new Error('Failed to generate QR code');
        }
    } catch (error) {
        console.error('Generate QR code error:', error);
        qrLoading.style.display = 'none';
        qrError.style.display = 'block';
    }
}

function displayQRCode(qrCodeData, workshopTitle, workshopArtists) {
    const qrLoading = document.getElementById('qr-loading');
    const qrContainer = document.getElementById('qr-code-container');
    const qrDisplay = document.getElementById('qr-code-display');
    const qrTitle = document.getElementById('qr-workshop-title');
    const qrDetails = document.getElementById('qr-workshop-details');

    qrLoading.style.display = 'none';
    qrContainer.style.display = 'block';

    qrDisplay.innerHTML = qrCodeData;
    qrTitle.textContent = workshopTitle || 'Workshop';
    qrDetails.textContent = workshopArtists || 'Dance Workshop';
}

const viewQRCode = requireAuth(async function(orderId, workshopTitle, workshopArtists, orderData = null) {
    openQRModal();

    // Update modal title and details
    document.getElementById('qr-workshop-title').textContent = workshopTitle || 'Loading...';
    document.getElementById('qr-workshop-details').textContent = workshopArtists || 'Loading...';

    await generateQRCode(orderId, workshopTitle, workshopArtists);
});

function downloadQRCode() {
    const qrCode = document.getElementById('qr-code-display');
    const svg = qrCode.querySelector('svg');
    if (svg) {
        const svgData = new XMLSerializer().serializeToString(svg);
        const svgBlob = new Blob([svgData], {type: 'image/svg+xml;charset=utf-8'});
        const svgUrl = URL.createObjectURL(svgBlob);

        const downloadLink = document.createElement('a');
        downloadLink.href = svgUrl;
        downloadLink.download = 'workshop-qr-code.svg';
        document.body.appendChild(downloadLink);
        downloadLink.click();
        document.body.removeChild(downloadLink);

        URL.revokeObjectURL(svgUrl);
    }
}

function shareQRCode() {
    const qrCode = document.getElementById('qr-code-display');
    const svg = qrCode.querySelector('svg');
    if (svg) {
        const svgData = new XMLSerializer().serializeToString(svg);
        const svgBlob = new Blob([svgData], {type: 'image/svg+xml;charset=utf-8'});

        if (navigator.share) {
            navigator.share({
                title: 'Workshop QR Code',
                text: 'My workshop QR code',
                files: [new File([svgBlob], 'workshop-qr-code.svg', {type: 'image/svg+xml'})]
            });
        } else {
            downloadQRCode();
        }
    }
}

// Bundle suggestion functions
function purchaseBundle() {
    // Implement bundle purchase logic
    console.log('Purchase bundle');
    closeBundleSuggestionModal();
}

function proceedIndividual() {
    // Implement individual purchase logic
    console.log('Proceed with individual purchase');
    closeBundleSuggestionModal();
}

// Payment functions
function payOrder(orderId, paymentLinkUrl) {
    window.open(paymentLinkUrl, '_blank');
}

// Initialize DOM elements
function initializeDOMElements() {
    authContainer = document.getElementById('auth-container');
    authButton = document.getElementById('auth-button');
    profileModal = document.getElementById('profile-modal');
    loginModal = document.getElementById('login-modal');
    otpModal = document.getElementById('otp-modal');
    bundleSuggestionModal = document.getElementById('bundle-suggestion-modal');
    ordersModal = document.getElementById('orders-modal');
    rewardsModal = document.getElementById('rewards-modal');
    qrModal = document.getElementById('qr-modal');
    shareModal = document.getElementById('share-modal');

    mobileInput = document.getElementById('mobile-number');
    otpMobileNumber = document.getElementById('otp-mobile-number');
    otpInputs = document.querySelectorAll('.otp-input');
    sendOtpBtn = document.getElementById('send-otp-btn');
    verifyOtpBtn = document.getElementById('verify-otp-btn');
    resendOtpBtn = document.getElementById('resend-otp-btn');
    loginError = document.getElementById('login-error');
    otpError = document.getElementById('otp-error');
    profileName = document.getElementById('profile-name');
    profileMobile = document.getElementById('profile-mobile');
    profileStatus = document.getElementById('profile-status');
    profileAvatarContainer = document.getElementById('profile-avatar-container');
    ordersRefreshBtn = document.getElementById('orders-refresh-btn');
    rewardsRefreshBtn = document.getElementById('rewards-refresh-btn');

    console.log('DOM elements initialized');
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    initializeDOMElements();
    initializeAuth();
});
