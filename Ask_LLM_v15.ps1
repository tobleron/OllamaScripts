$outputDir = "output"
$tmpMdDir = "tmp_md"
$promptInputFile = "prompt_input.txt"
$promptsDir = "$outputDir\_prompts"  # Directory for prompt files
$chatDir = "Chat"  # Directory for saving chat transcripts
$UserName = "Arto" #Write friendly user name

# Set up colors for display
$colorModelName = "Green"
$colorUserLabel = "White"
$scriptComment = "DarkYellow"

function Create-PromptInputFile
{
    $filePath = ".\prompt_input.txt"
    if (-not (Test-Path $filePath))
    {
        New-Item -Path $filePath -ItemType File
        Write-Output "File 'prompt_input.txt' created."
    } else
    {
        Write-Output "File 'prompt_input.txt' already exists."
    }
}

function Log-Message
{
    param (
        [string]$message,
        [string]$color = "White"
    )
    Write-Host $message -ForegroundColor $color
}

function Get-Timestamp
{
    return (Get-Date).ToString("dd_MM_yyyy_HH_mm_ss")
}

function Sanitize-FileName
{
    param ([string]$fileName)
    return $fileName -replace "[:\\/*?`"<>|]", "_"
}

function Get-ModelsFromOllama
{
    try
    {
        $response = Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -Method GET
        return ($response.Content | ConvertFrom-Json).models
    } catch
    {
        Log-Message "Failed to fetch models from Ollama. Error: $_" "Red"
        exit 1
    }
}

function ErrorHandler
{
    param ([string]$errorMessage)
    Log-Message $errorMessage "Red"
    exit 1
}

function Create-DirectoryIfNotExist
{
    param ([string]$path)
    if (-Not (Test-Path $path))
    {
        New-Item -ItemType Directory -Path $path -ErrorAction Stop | Out-Null
        Log-Message "Created directory: $path" "DarkYellow"
    }
}

function Send-RequestToOllama
{
    param (
        [string]$model,
        [string]$prompt
    )
    $body = @{
        model  = $model.Trim()
        prompt = $prompt.Trim()
        stream = $false
    } | ConvertTo-Json

    try
    {
        $response = Invoke-WebRequest -Method POST -Body $body -Uri "http://localhost:11434/api/generate" -ContentType "application/json"
        return ($response.Content | ConvertFrom-Json).response
    } catch
    {
        ErrorHandler "Failed to receive response for model: $model. Error: $_"
    }
}

function Save-MdFile
{
    param (
        [string]$content,
        [string]$directory,
        [string]$fileName
    )
    $filePath = Join-Path -Path $directory -ChildPath $fileName
    try
    {
        $content | Out-File -FilePath $filePath -Encoding utf8
        Log-Message "Successfully wrote file: $filePath" "DarkYellow"
    } catch
    {
        ErrorHandler "Failed to write file: $filePath. Error: $_"
    }
}

# Main Script Execution
$timestamp = Get-Timestamp
Create-DirectoryIfNotExist -path $outputDir
Create-DirectoryIfNotExist -path $tmpMdDir
Create-DirectoryIfNotExist -path $promptsDir
Create-DirectoryIfNotExist -path $chatDir
Create-PromptInputFile

# Fetch the models from Ollama
Log-Message "Fetching models from Ollama..." "Yellow"
$models = Get-ModelsFromOllama
if ($models.Count -eq 0)
{ ErrorHandler "No models found in Ollama." 
}


if ((Get-Item $promptInputFile).length -gt 0)
{
    Write-Host "`nExisting prompt detected in `prompt_input.txt`. Proceeding..." -ForegroundColor $scriptComment
} else
{
    #Ask the user to enter inquiry:
    Write-Host "`nEnter your query $UserName`:" -ForegroundColor DarkYellow
    $userQuestion = Read-Host
    if ($userQuestion -eq "")
    { ErrorHandler "Invalid input. Exiting..." 
    }
    Add-Content -Path $promptInputFile -Value "User`:`n$userQuestion"
}

# Display available models
Log-Message "`nAvailable models:" "White"
for ($i = 0; $i -lt $models.Count; $i++)
{
    Write-Host "[$($i+1)] $($models[$i].name)" -ForegroundColor DarkYellow
}

# Get user input for model selection
$userInput = Read-Host "`nChoose Model (Example: n for chat-mode and n,n for multiple responses)"
$selectedIndices = $userInput -split "," | ForEach-Object { 
    try
    {
        [int]($_.Trim()) - 1
    } catch
    {
        ErrorHandler "Invalid input format. Please enter valid indices (e.g., 1,2,3)."
        return
    }
}

# Validate and extract model names based on selected indices
$selectedModels = @()
foreach ($index in $selectedIndices)
{
    if ($index -ge 0 -and $index -lt $models.Count)
    {
        $selectedModels += $models[$index].name
    } else
    {
        ErrorHandler "Invalid model selection index: $($index + 1). Please select indices from the list."
        return
    }
}


# Check if only one model was selected
if ($selectedModels.Count -eq 1)
{
    # Extract the single model name
    $model = $selectedModels[0]
    
    # Chat mode starts here
    $chatActive = $true
    $promptFile = "prompt_input.txt"
    Write-Host "Enter @exit in prompt to exit script and save chat!`n" -ForegroundColor $scriptComment
    
    while ($chatActive)
    {
        # Read initial prompt or conversation history
        $prompt = Get-Content $promptFile -Raw

        # Send prompt to Ollama and get response
        $response = Send-RequestToOllama -model $model -prompt $prompt
        
        # Display the model's name in green and response in yellow
        Write-Host "`n$model`:`n" -ForegroundColor $colorModelName
        $response | Show-Markdown
        #$response | Write-Host -ForegroundColor $colorModelResponse
       
        # Append response to the prompt file to maintain conversation history
        Add-Content -Path $promptFile -Value "`n**$model**`:`n$response"

        # Ask the user if they want to continue or exit
        Write-Host "$UserName`:`n" -ForegroundColor $colorUserLabel
        $userContinue = Read-Host -Prompt "`n"
        
        if ($userContinue -eq "@exit")
        {
            # Save the chat history as a markdown file with timestamp
            $timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
            $chatHistory = Get-Content $promptFile -Raw
            $chatFile = "Chat\Chat_$timestamp.md"
            $chatHistory | Out-File $chatFile
            Write-Host "Chat saved to $chatFile"
            $chatActive = $false
        } else
        {
            # Append new chat input
            Add-Content -Path $promptFile -Value "**$UserName**`:`n$userContinue"        
        }
    }
} else
{
    # Handle the scenario for multiple model selections as previously implemented
    foreach ($model in $selectedModels)
    {
        $sanitizedModel = Sanitize-FileName -fileName $model
        $prompt = Get-Content $promptInputFile -Raw

        #Start timer
        $startTime = Get-Date

        #Start processing.. 
        $responseText = Send-RequestToOllama -model $model -prompt $prompt         
        
        #Calculate elapsed time
        $endTime = Get-Date
        $elapsedTime = $endTime - $startTime
        
        # Format elapsed time as minutes and seconds
        $formattedTime = "{0:hh\:mm\:ss}" -f $elapsedTime

        # Append elapsed time to the response
        $responseTextWithTime = "$responseText`n`n Time taken to respond: $formattedTime"

        # Save responses and prompts
        Save-MdFile "# $model`n`n$responseTextWithTime" $tmpMdDir "${sanitizedModel}_$timestamp.md"
        Save-MdFile $prompt $promptsDir "Prompt_$timestamp.md"

        # Display response
        $responseText
    }

    # Concatenate all response markdown files into a single results file
    $resultsFile = "$outputDir\Results_$timestamp.md"
    Get-ChildItem -Path $tmpMdDir -Filter "*_$timestamp.md" | Get-Content | Add-Content -Path $resultsFile
    Log-Message "Successfully concatenated markdown files into: $resultsFile" "DarkYellow"
}

# Clean up temporary markdown files older than 3 days

Log-Message "Cleaning up temporary markdown files in: $tmpMdDir..." "DarkYellow"
Get-ChildItem -Path $tmpMdDir -Filter "*.md" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } | Remove-Item -Force
Log-Message "Temporary markdown files older than 3 days cleaned up." "DarkYellow"
Clear-Content $promptInputFile
Log-Message "prompt_input.txt has been cleared" "DarkYellow"
