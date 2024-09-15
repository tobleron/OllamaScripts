### Script Overview
The script interacts with a local server for the Ollama AI, allowing users to send prompts to different AI models, receive responses, and save conversations in a structured format. It manages prompt input, model selection, interaction with the AI models, and storage of chat logs and results.

### Key Features and Functions

1. **Initialization and Setup:**
   - The script initializes necessary directories (`output`, `tmp_md`, `_prompts`, `Chat`) for storing prompts, responses, and chat logs.
   - It creates a prompt input file (`prompt_input.txt`) if it doesn't already exist.

2. **Model Management:**
   - The function `Get-ModelsFromOllama` fetches available AI models from the Ollama server via an API call. It handles errors gracefully if the fetch fails.

3. **User Interaction:**
   - Prompts the user to either use an existing prompt or enter a new one.
   - Displays available models for selection and allows the user to choose one or more models for generating responses.

4. **AI Response Handling:**
   - Sends user prompts to the selected AI model(s) using the `Send-RequestToOllama` function, which makes a POST request to the Ollama API.
   - Handles responses and errors during communication with the models.

5. **Chat Mode:**
   - If a single model is selected, the script enters a chat mode where users can continuously send prompts to the model. The conversation history is maintained, and the user can exit by typing `@exit`.
   - Saves the chat history as a Markdown file with a timestamped filename.

6. **Multiple Model Responses:**
   - If multiple models are selected, it runs the prompt through each model and saves their responses as separate Markdown files.
   - Combines all responses into a single results file for easy review.

7. **File Management and Cleanup:**
   - The script sanitizes filenames to avoid issues with special characters.
   - It cleans up old temporary Markdown files older than three days to manage storage efficiently.

8. **Logging and Error Handling:**
   - The script uses color-coded messages for user-friendly logging.
   - It includes robust error handling to catch and report issues clearly.

### Why It Is Useful
- **Ease of Use:** Simplifies the process of interacting with multiple AI models locally by handling the setup, prompt management, and API interactions automatically.
- **Automation:** Automates the generation of AI responses and organizes outputs into structured files, making it easy to keep track of AI interactions.
- **Customization:** Allows users to choose specific models and manage inputs dynamically, catering to various use cases.
- **Resource Management:** Includes features for cleaning up old files, which helps manage resources efficiently without manual intervention.

These scripts (`Ask_LLM_v15.ps1` and its Bash counterpart) provide a convenient way for users to experiment with AI models from Ollama, log their interactions, and manage these logs systematically in a local environment, making them ideal for development and testing purposes in AI research or application development.
