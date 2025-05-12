document.addEventListener('DOMContentLoaded', () => {
    const analyzeForm = document.getElementById('analyzeForm');
    const modelSelect = document.getElementById('modelSelect');
    const linkInput = document.getElementById('linkInput');
    const analyzeButton = document.getElementById('analyzeButton');
    const loadingIndicator = document.getElementById('loadingIndicator');
    const errorMessage = document.getElementById('errorMessage');
    const jsonOutput = document.getElementById('jsonOutput');

    analyzeForm.addEventListener('submit', async (event) => {
        event.preventDefault(); // Prevent default form submission

        const selectedModel = modelSelect.value;
        const eventLink = linkInput.value;

        if (!eventLink) {
            errorMessage.textContent = 'Please enter a valid URL.';
            errorMessage.style.display = 'block';
            return;
        }

        // --- UI Updates: Start Loading ---
        analyzeButton.disabled = true;
        loadingIndicator.style.display = 'block';
        errorMessage.style.display = 'none';
        jsonOutput.textContent = 'Analyzing...';
        // ---

        try {
            const response = await fetch('/ai/analyze', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json', // Expect JSON response
                },
                body: JSON.stringify({
                    link: eventLink,
                    ai_model: selectedModel
                })
            });

            if (!response.ok) {
                // Try to get error details from response body
                let errorData;
                try {
                     errorData = await response.json();
                } catch(e) {
                    // If response is not JSON or empty
                     errorData = { detail: `HTTP error! Status: ${response.status}` };
                }
                throw new Error(errorData.detail || `HTTP error! Status: ${response.status}`);
            }

            const resultData = await response.json();

            // Pretty print the JSON result
            jsonOutput.textContent = JSON.stringify(resultData, null, 2);
            errorMessage.style.display = 'none'; // Hide error message on success

        } catch (error) {
            console.error('Analysis Error:', error);
            errorMessage.textContent = `Analysis failed: ${error.message}`;
            errorMessage.style.display = 'block';
            jsonOutput.textContent = 'Analysis failed.'; // Clear previous results on error
        } finally {
            // --- UI Updates: End Loading ---
            analyzeButton.disabled = false;
            loadingIndicator.style.display = 'none';
            // ---
        }
    });
}); 