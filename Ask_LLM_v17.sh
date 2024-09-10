#!/bin/bash

# Set up variables
output_dir="output"
tmp_md_dir="tmp_md"
prompt_input_file="prompt_input.txt"
prompts_dir="$output_dir/_prompts"
chat_dir="Chat"
user_name="Arto"

# Set up colors for display
color_model_list="33" # DarkYellow
color_model_name="32" # Green
color_model_response="36" # Cyan
color_user_label="37" # White
script_comment="35" # Magenta 

# Create prompt input file if it doesn't exist
create_prompt_input_file() {
    if [ ! -f "$prompt_input_file" ]; then
        touch "$prompt_input_file"
        echo "File 'prompt_input.txt' created."
    else
        echo "File 'prompt_input.txt' already exists."
    fi
}

# Log message with color
log_message() {
    local message=$1
    local color=$2
    echo -e "\033[${color}m$message\033[0m"
}

# Get timestamp
get_timestamp() {
    date +"%d_%m_%Y_%H_%M_%S"
}

# Sanitize file name
sanitize_file_name() {
    local file_name=$1
    echo "${file_name//[:\\/*?\"<>|]/_}"
}

# Get models from Ollama
get_models_from_ollama() {
    response=$(curl -s -X GET "http://localhost:11434/api/tags")
    models=$(echo "$response" | jq -r '.models[] | .name')
    echo "$models"
}

# Error handler
error_handler() {
    local error_message=$1
    log_message "$error_message" "31" # Red
    exit 1
}

# Create directory if it doesn't exist
create_directory_if_not_exist() {
    local path=$1
    if [ ! -d "$path" ]; then
        mkdir -p "$path"
        log_message "Created directory: $path" "$script_comment"
    fi
}

# Send request to Ollama
send_request_to_ollama() {
    local model=$1
    local prompt=$2
    body=$(jq -n --arg model "$model" --arg prompt "$prompt" '{model: $model, prompt: $prompt, stream: false}')
    response=$(curl -X POST -H "Content-Type: application/json" -d "$body" "http://localhost:11434/api/generate")
    echo "$response" | jq -r '.response'
}

# Save markdown file
save_md_file() {
    local content=$1
    local directory=$2
    local file_name=$3
    file_path="$directory/$file_name"
    echo -e "$content" > "$file_path"
    log_message "Successfully wrote file: $file_path" "$script_comment"
}

# Main script execution
timestamp=$(get_timestamp)
create_directory_if_not_exist "$output_dir"
create_directory_if_not_exist "$tmp_md_dir"
create_directory_if_not_exist "$prompts_dir"
create_directory_if_not_exist "$chat_dir"
create_prompt_input_file

# Fetch models from Ollama
log_message "Fetching models from Ollama..." "$color_model_list"
models=$(get_models_from_ollama)
if [ -z "$models" ]; then
    error_handler "No models found in Ollama."
fi

if [ -s "$prompt_input_file" ]; then
    echo -e "\nExisting prompt detected in \`prompt_input.txt\`. Proceeding...\n" >&2
else
    # Ask the user to enter inquiry:
    echo -e "\nEnter your query $user_name: " >&2
    read -r user_question
    if [ -z "$user_question" ]; then
        error_handler "Invalid input. Exiting..."
    fi
    echo "User:\n$user_question" >> "$prompt_input_file"
fi

# Convert models into an array
models_array=($models)  # Split the string into an array

# Display available models
log_message "\nAvailable models:" "$color_model_list"
i=0
for model in "${models_array[@]}"; do
    echo "[$((i+1))] $model" >&2
    ((i++))
done

# Get user input for model selection
echo -e "\nChoose Model (Example: n for chat-mode and n,n for multiple responses): " >&2
read -r user_input
selected_indices=($(echo "$user_input" | tr ',' '\n'))

# Initialize an array for selected models
selected_models=()

# Validate indices and extract corresponding models
for index in "${selected_indices[@]}"; do
    if [[ $index -ge 1 && $index -le ${#models_array[@]} ]]; then
        selected_models+=("${models_array[$((index-1))]}")
    else
        error_handler "Invalid model selection index: $index. Please select indices from the list."
        exit 1
    fi
done


# Check if only one model was selected
if [ ${#selected_models[@]} -eq 1 ]; then
    # Extract the single model name
    model="${selected_models[0]}"
    
    # Chat mode starts here
    chat_active=true
    prompt_file="prompt_input.txt"
    echo -e "Enter @exit in prompt to exit script and save chat!\n" >&2
    
    while $chat_active; do
        # Read initial prompt or conversation history
        prompt=$(cat "$prompt_file")
        
        # Send prompt to Ollama and get response
        response=$(send_request_to_ollama "$model" "$prompt")
        
        # Display the model's name in green and response in yellow
        echo -e "\n\033[${color_model_name}m$model\033[0m:\n" >&2
        echo -e "\033[${color_model_response}m$response\033[0m\n" >&2
        
        # Append response to the prompt file to maintain conversation history
        echo -e "**$model**:\n$response" >> "$prompt_file"
        
        # Ask the user if they want to continue or exit
        echo -e "$user_name:\n" >&2
        read -r user_continue
        
        if [ "$user_continue" = "@exit" ]; then
            # Save the chat history as a markdown file with timestamp
            timestamp=$(date +"%Y%m%d_%H%M%S")
            chat_history=$(cat "$prompt_file")
            chat_file="Chat/Chat_$timestamp.md"
            echo -e "$chat_history" > "$chat_file"
            echo "Chat saved to $chat_file"
            chat_active=false
        else
            # Append new chat input
            echo -e "**$user_name**:\n$user_continue" >> "$prompt_file"
        fi
    done
else
    # Handle the scenario for multiple model selections as previously implemented
    for model in "${selected_models[@]}"; do
        sanitized_model=$(sanitize_file_name "$model")
        prompt=$(cat "$prompt_input_file")
        response_text=$(send_request_to_ollama "$model" "$prompt")
        
        # Save responses and prompts
        save_md_file "# $model\n\n$response_text" "$tmp_md_dir" "${sanitized_model}_$timestamp.md"
        save_md_file "$prompt" "$prompts_dir" "Prompt_$timestamp.md"
        
        # Display response
        echo -e "$response_text\n" >&2

    done
    
    # Concatenate all response markdown files into a single results file
    results_file="$output_dir/Results_$timestamp.md"
    cat "$tmp_md_dir"/*_"$timestamp.md" > "$results_file"
    log_message "Successfully concatenated markdown files into: $results_file" "$script_comment"
fi

# Clean up temporary markdown files older than 3 days
log_message "Cleaning up temporary markdown files in: $tmp_md_dir..." "$script_comment"
find "$tmp_md_dir" -name "*.md" -mtime +3 -delete
log_message "Temporary markdown files older than 3 days cleaned up." "$script_comment"
> "$prompt_input_file"
log_message "prompt_input.txt has been cleared" "$script_comment"

