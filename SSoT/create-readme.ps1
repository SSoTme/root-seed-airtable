param (
    [string]$filename
)

function Post-Prompt {
    param (
        [string]$filename
    )

    if ("$filename" -eq "$null") {
        $filename = "Airtable.json"
    }
    $scriptPath = Split-Path -Parent -Path $MyInvocation.PSCommandPath

    Write-Host "Creating README.md for file: $filename - $($MyInvocation.PSCommandPath) which has this script path: $scriptPath"

    # Construct the path to the input file relative to the script
    $filePath = Join-Path -Path $scriptPath -ChildPath $filename

    # Read the content of the file to include in the prompt
    $fileContent = Get-Content -Path $filePath

    $fileContent = "$($fileContent | ConvertFrom-Json | ConvertTo-Json -Compress)"
    Write-Host "CONTENTS: $fileContent"

    if ($fileContent -match "^```(.+)```$") {
        $fileContent = $Matches[1]
    }


    # Define the URI and body of the POST request
    $uri = "https://k6vipu7segkzalfaaras5nuanu0oigwp.lambda-url.us-east-2.on.aws/chatgpt"
    $body = @{
        key = '$openai-api-key$'
        parentMessageId = "8f92ddf0-798f-4f70-b7f5-0e8ab41088be"
        prompt = "Ignore entities list meta data: " + $fileContent + 
                    "Please write a 1500 word narrative WIKI style article." +
                    "Don't make stuff up like where to clone the project from.  You don't know that shit.: "
        systemMessage = "You are a business analyst."
        model = "gpt-4o-mini"
    } | ConvertTo-Json

    # Send the POST request
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"
        return $response.text
    }
    catch {
        Write-Host "Error posting to API: $_"
        return $null
    }
}

# Call the function and output the result to a README.md file
$readmeContent = Post-Prompt -filename $filename
if ($readmeContent) {
    $readmeContent | Out-File -FilePath "../README.md"
    Write-Host "README.md has been created successfully."
} else {
    Write-Host "Failed to create README.md."
}
