$YourOpenAIApiKey = "$env:OPENAI_API_KEY"

function Post-Prompt {
    param (
        [string]$filename
    )

    if ("$filename" -eq "$null") {
        $filename = "SSoT/Airtable.json"
    }
    Write-Host "Creating README.md for file: $filename - $($MyInvocation.PSCommandPath) which has this script path: $scriptPath"

    $scriptPath = Split-Path -Parent -Path $MyInvocation.PSCommandPath
    $filePath = Join-Path -Path $scriptPath -ChildPath $filename
    $jsonContent = Get-Content -Path $filePath -Raw | ConvertFrom-Json
    $simplifiedJsonContent = Simplify-Attachments -Node $jsonContent
    $fileContent = $simplifiedJsonContent | ConvertTo-Json -Depth 100 -Compress

    # Construct the path to the input file relative to the script
    $filePath = Join-Path -Path $scriptPath -ChildPath $filename

    $jsonContent = Get-Content -Path $filePath -Raw | ConvertFrom-Json
    #Write-Host "CONTENTS short: $jsonContent"

    $fileContent = $jsonContent | ConvertTo-Json -Depth 100 -Compress
    #Write-Host "CONTENTS: $fileContent"

    $uri = "https://k6vipu7segkzalfaaras5nuanu0oigwp.lambda-url.us-east-2.on.aws/chatgpt"
    $body = @{
        key = $YourOpenAIApiKey
        parentMessageId = ""
        systemMessage = "Ignore entities list meta data: " + $fileContent + 
                 "Please write a 1500 word narrative article (like a wiki page).  Don't truncate urls." +
                 "Avoid bullet lists.  Don't make stuff up like where to clone the project from.  You don't know that shit.: "
        prompt = "answer the question."
        model = "gpt-4o"
        maxResponseTokens = 1500
    } | ConvertTo-Json

    # $body | Set-Content "payload.json"

    try {
        Write-Host "Generating response`n`n"
        $responseText = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"
        Write-Host "Generated Text: $($responseText.text)"

        $readmePath = Join-Path -Path $scriptPath -ChildPath "README.md"
        if (!$responseText.text.Contains("#")) {
            $responseText.text = "#" + $responseText.text
        }

        $headerIndex = $responseText.text.IndexOf('#')
        
        $readmeContent = $responseText.text.Insert($headerIndex, "`n<div style='width: 15em; float: right;'>`n`n![Inferred Project Logo](logo.png)`n`n</div>`n`n")
        
        Write-Host "`n`nWRITING README.md TO DISK."
        $readmeContent | Set-Content -Path $readmePath
        Write-Host "README.md has been updated successfully with the image."
        
        $imagePrompt = Generate-DallePrompt -text $responseText.text
        write-host "`n`n`nIMAGE PROMPT: $imagePrompt" 
        try {
            $imageUrl = Generate-Image -imagePrompt $imagePrompt
            Write-Host "Image URL: $imageUrl"    
        } catch { } // ignore errors

        
        return $responseText.text
    }
    catch {
        Write-Host "Error posting to API or generating image: $_"
        return $null
    }
}

function Simplify-Attachments {
    param (
        [object]$Node
    )

    if ($Node -is [System.Collections.IDictionary]) {
        if ($Node.ContainsKey('url') -and $Node.ContainsKey('width') -and $Node.ContainsKey('height') -and $Node.ContainsKey('thumbnails')) {
            return $Node['url']  # Return the URL string if node is an attachment
        } else {
            foreach ($key in $Node.Keys) {
                $Node[$key] = Simplify-Attachments -Node $Node[$key]  # Recurse into each property
            }
        }
    } elseif ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string]) {
        $i = 0
        foreach ($element in $Node) {
            $Node[$i++] = Simplify-Attachments -Node $element  # Recurse into each element
        }
    }
    return $Node
}


function Generate-Image {
    param (
        [string]$imagePrompt
    )

    if ($imagePrompt -eq $null) {
        $imagePrompt = "the words - missing project summary prompt"
    }

    write-host "Generating image for prompt: $imagePrompt"

    $uri = "https://api.openai.com/v1/images/generations"
    $body = @{
        model = "dall-e-3"
        prompt = "$imagePrompt"
        n = 1
        size = "1024x1024"
        quality = "standard"
    } | ConvertTo-Json


    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $YourOpenAIApiKey"
    }

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -Headers $headers
        write-host "RESPONSE TO GET IMAGE URL:  " ($response | ConvertTo-Json) '`n`n`'
        $imageUrl = $response.data[0].url

        # Download the image and save it locally
        $imagePath = "logo.png"
        Invoke-WebRequest -Uri $imageUrl -OutFile "../$imagePath"
        Write-Host "Image saved to $imagePath"

        return $imagePath
    }
    catch {
        Write-Host "Error generating or saving image: $_"
        return $null
    }
}

function Generate-DallePrompt {
    param (
        [string]$text
    )
    $uri = "https://k6vipu7segkzalfaaras5nuanu0oigwp.lambda-url.us-east-2.on.aws/chatgpt"
    $body = @{
        key = $YourOpenAIApiKey
        parentMessageId = ""
        prompt = "Create a concise and descriptive caption for an image based on the following content: `n$text"
        systemMessage = "You are a business analyst."
        model = "gpt-4o"
        maxResponseTokens = 1500
    } | ConvertTo-Json

    # $body | Set-Content "image-payload.json"

    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $YourOpenAIApiKey"
    }

    try {
        write-host "REQUESTING PROMPT TO GET IMAGE:  " $body | ConvertTo-Json
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -Headers $headers
        write-host "RESPONSE TO GET IMAGE URL:  " $response.text | ConvertTo-Json
        return $response.text
    }
    catch {
        Write-Host "Error generating DALL-E prompt: $_"
        $null
    }
}


# Call the function and output the result to a README.md file
$readmeContent = Post-Prompt -filename $filename
